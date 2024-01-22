#!/usr/bin/env bash
[ -n "${BASH_VERSION}" ] || exec bash "$0" "$@"
set +o posix

# Downloads and updates the firmware of Western Digital NVME SSDs
#
# Firmware updates are always risky. Use at your own risk
#
# 2023 Brian K. White @bkw777
# original: Copyright (C) 2023 by Jules Kreuer - @not_a_feature
#           2023 @Klaas-
# license: GPL3

########################################################################
# configuration

default_device=/dev/nvme0

device_class="nvme"

wd_firmware_host="wddashboarddownloads.wdc.com"

devices_xml_path="/wdDashboard/config/devices/lista_devices.xml"

tmp_dir="${XDG_RUNTIME_DIR:-/tmp}"

: ${DEBUG:=false}

su_apps=(sudo pkexec doas) # lxsudo gksudo ...

http_clients=("wget -qO" "curl -so" "aria2c -q -o")

package_managers=("apt install" "dnf install" "zypper install" "pacman -S" "yum install" "apt-get install")

########################################################################

echo "$0 - WD nvme firmware updater"

abrt () { echo -e "$@" >&2 ;exit 1 ; }
ask () { local x=n ;read -p"$@" x ;[[ $x == "y" ]] ; }
usage () { abrt "\n  usage  : $0 [device]\n  example: $0 ${default_device}\n\n  [device] defaults to ${default_device} if not given\n\n${@}\n" ; }
ifs="${IFS}"

case "$1" in h|help|-h|--help|-\?) usage ;; esac

# drive device node, model number, and firmware version
dev="${1:-${default_device}}"
[[ -c "${dev}" ]] || usage "\"${dev}\" does not exist or is not a character device"
$DEBUG && [[ -z "$1" ]] && echo "debug: nvme device not specified, using default \"${dev}\""
name=${dev##*/}
sys="/sys/class/${device_class}/${name}"
[[ -d "${sys}" ]] || usage "${sys} does not exist"
read drive_model < ${sys}/model || usage "Could not read ${sys}/model"
read firmware_rev < ${sys}/firmware_rev || usage "Could not read ${sys}/firmware_rev"

# work out of unique temp dir
# delete temp dir on exit
unset td ;typeset -r td="${tmp_dir}/${0//\//_}${$}/"
rm -rf "${td}" ;mkdir -p "${td}" || abrt "Could not mkdir -p \"${td}\" !"
cd "${td}" || abrt "Could not cd \"${td}\" !"
${DEBUG} && {
	trap 'echo "debug: temp files left in ${td}"' 0
} || {
	trap 'rm -rf "${td}"' 0
}

# find sudo or pkexec
su= ;for x in "${su_apps[@]}" ;do
	command -v $x >/dev/null 2>&1 && su=$x && break
done
[[ "${su}" ]] || abrt "Could not find sudo or pkexec!"
$DEBUG && echo "debug: using \"${su}\" for root tasks"

# define required external utils - needlessly fancy ;)
# [command]=package_name
typeset -A pkg=(
	[nvme]=nvme-cli
#	[xmllint]=libxml2
)
# find wget or curl or aria2c
hc= ;for x in "${http_clients[@]}" ;do
	command -v ${x%% *} >/dev/null 2>&1 && hc="$x" && break
done
# if none found, add the first one to be installed
[[ "${hc}" ]] || { hc="${http_clients[0]}" ;x=${hc%% *} ;pkg[$x]=$x ; }
$DEBUG && echo "debug: using \"${hc%% *}\" for http downloads"
# install anything that's missing
type -p ${!pkg[*]} >/dev/null 2>&1 || {
	echo "Installing dependencies: ${pkg[*]}"
	for x in "${package_managers[@]}" ;do
		command -v ${x%% *} >/dev/null 2>&1 || continue
		x="${su} $x ${pkg[*]}"
		ask "Ok to \"$x\" (y/N)? " && $x && break
	done
	echo
}
type -p ${!pkg[*]} >/dev/null 2>&1 || abrt "Please install these packages: ${pkg[*]}"

# fake detected drive for debugging
# 611100WD 611110WD 613000WD -> 613200WD
# 614300WD 614600WD 614900WD 615100WD 615300WD -> 615400WD
#drive_model="WDS200T1X0E-00AFY0"
#firmware_rev="611110WD"
#firmware_rev="614900WD"

echo "Device:   ${dev}"
echo "Model:    ${drive_model}"
echo "Firmware: ${firmware_rev}"
echo

# download the catalog xml for all devices
x="https://${wd_firmware_host}${devices_xml_path}"
all_xml="${devices_xml_path##*/}"
$DEBUG && echo "debug: get $x"
${hc} "${all_xml}" "$x"
[[ -s "${all_xml}" ]] || abrt "failed to download $x"
$DEBUG && echo

# extract device_properties.xml urls
# would be better: xmllint --xpath 'lista_devices/lista_device/url' file.xml
m="${drive_model// /_}"
unset p ;typeset -A p=()
while read x ;do
	[[ $x =~ ^[[:space:]]*\<url\>.*/device_properties\.xml\</url\>[[:space:]]*$ ]] || continue
	x="${x#*>}" ;x="${x%<*}"
	IFS=/ a=($x) IFS="$ifs"
	[[ "${a[2]}" == "$m" ]] || continue
	[[ ${a[3]} > ${firmware_rev} ]] && p+=([${a[3]}]="$x") || echo "Available ${a[3]} is not newer."
done < "${all_xml}"

# find the highest available version
v= ;for x in "${!p[@]}" ;do [[ $x > $v ]] && v="$x" ;done
[[ "$v" ]] || abrt "No updates available."

echo "Update(s) available:"
x="$PS3" PS3="Which version do you want to install (1-${#p[@]})? "
select v in "${!p[@]}" ;do break ;done ;PS3="$x"
[[ "$v" ]] && [[ "${p[$v]}" ]] || abrt "Aborted"
echo

# download the device properties xml
device_xml_url="https://${wd_firmware_host}/${p[$v]}"
one_xml="${device_xml_url##*/}"
$DEBUG && echo "debug: get ${device_xml_url}"
${hc} "${one_xml}" "${device_xml_url}"
[[ -s "${one_xml}" ]] || abrt "failed to download ${device_xml_url}"
$DEBUG && echo

# extract fwfile and dependency urls
fwf= deps=()
while read x ;do
	[[ $x =~ ^[[:space:]]*\<fwfile\>.*\</fwfile\>[[:space:]]*$ ]] && { x="${x#*>}" ;fwf="${x%<*}" ;continue ; }
	[[ $x =~ ^[[:space:]]*\<dependency.*\>.*\</dependency\>[[:space:]]*$ ]] && { x="${x#*>}" ;deps+=("${x%<*}") ; }
done < "${one_xml}"

# check if running firmware is new enough to install the ne firmware
[[ "${deps[@]}" =~ ${firmware_rev} ]] || abrt "\
  In order to install firmware version $v
  the drive must currently be running one of the following:
  ${deps[@]}

  ${dev} is currently running ${firmware_rev}
"

# download the firmware file
fwu="${device_xml_url%/*}/${fwf}"
$DEBUG && echo "debug: get ${fwu}"
${hc} "${fwf}" "${fwu}"
[[ -s "${fwf}" ]] || abrt "failed to download ${fwu}"
$DEBUG && echo

# TODO verify uncorrupted download somehow
# hopefully the firmware and updater itself includes a checksum of some sort

# load the firmware onto the drive
ask "Load ${fwf} onto ${dev} (y/N)? " || abrt "Aborted"
${su} nvme fw-download -f "${fwf}" "${dev}" || abrt "failed"
echo

# activate the new firmware
ask "Activate the new firmware (y/N)? " || abrt "Aborted"
${su} nvme fw-commit -s 2 -a 3 "${dev}" || abrt "failed"
echo

echo "Firmware update process completed. Please reboot."
echo
