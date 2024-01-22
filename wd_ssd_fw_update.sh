#!/usr/bin/env bash
[ -n "${BASH_VERSION}" ] || exec bash $0
set +o posix

# Downloads and updates the firmware of Western Digital NVME SSDs
#
# Firmware updates are always risky. Use at your own risk
#
# 2023 Brian K. White
# original: Copyright (C) 2023 by Jules Kreuer - @not_a_feature
# With adaptations from @Klaas-
# License: GPL3

########################################################################
# configuration

device_class="nvme"

wd_firmware_host="wddashboarddownloads.wdc.com"

devices_xml_path="/wdDashboard/config/devices/lista_devices.xml"

priv_exec="sudo" # "sudo", "pkexec", lxsudo, doas, etc

http_client="wget -qO" # "wget -qO" , "curl -so" , "aria2c -q -o"

tmp_dir="${XDG_RUNTIME_DIR:-/tmp}"

: ${DEBUG:=false}

########################################################################

echo "$0 - WD nvme drive firmware updater"

abrt () { echo -e "$@" >&2 ;exit 1 ; }
ask () { local x=n ;read -p"$@" x ;[[ $x == "y" ]] ; }
usage () { abrt "\n  usage  : $0 <device>\n  example: $0 /dev/nvme0\n\n${@}\n" ; }
ifs="${IFS}"

# drive device node, model number, and firmware version
dev="$1"
[[ -c "${dev}" ]] || usage "\"${dev}\" does not exist or is not a character device"
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

# required external utils
x=${http_client%% *}
typeset -A a=(
	[curl]=curl
	[wget]=wget
	[aria2c]=aria2
)
typeset -A pkg=(
	[$x]=${a[$x]}
	[nvme]=nvme-cli
#	[xmllint]=libxml2
)
unset a
type -p ${!pkg[*]} 2>&1 >/dev/null || {
	echo "Installing dependencies: ${pkg[*]}"
	${priv_exec} apt install ${pkg[*]}
	echo
}
type -p ${!pkg[*]} 2>&1 >/dev/null || abrt "Missing one or more: ${!pkg[*]}"

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
${http_client} "${all_xml}" "$x"
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
${http_client} "${one_xml}" "${device_xml_url}"
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
${http_client} "${fwf}" "${fwu}"
[[ -s "${fwf}" ]] || abrt "failed to download ${fwu}"
$DEBUG && echo

# TODO verify uncorrupted download somehow
# hopefully the firmware and updater itself includes a checksum of some sort

# load the firmware onto the drive
ask "Load ${fwf} onto ${dev} (y/N)? " || abrt "Aborted"
${priv_exec} nvme fw-download -f "${fwf}" "${dev}" || abrt "failed"
echo

# activate the new firmware
ask "Activate the new firmware (y/N)? " || abrt "Aborted"
${priv_exec} nvme fw-commit -s 2 -a 3 "${dev}" || abrt "failed"

echo
echo "Firmware update process completed. Please reboot."
echo
