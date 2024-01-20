#!/usr/bin/env bash
[ -n "${BASH_VERSION}" ] || exec bash $0
set +o posix

# This script downloads and updates the firmware of Western Digital SSDs on Ubuntu / Linux Mint.
# It is only capable of updating, if, and only if the current firmware version is
# directly supported. If not, you have to upgrade to one of these versions first.

# The script assumes the SSD is at /dev/nvme0. Adjust accordingly if your SSD is located elsewhere.
# Firmware updates can be risky.
# Always back up your data and understand the risks before proceeding.
# Use at your own risk

# Copyright (C) 2023 by Jules Kreuer - @not_a_feature
# With adaptations from @Klaas-


# This piece of software is published unter the GNU General Public License v3.0
# TLDR:
#
# | Permissions      | Conditions                   | Limitations |
# | ---------------- | ---------------------------- | ----------- |
# | ✓ Commercial use | Disclose source              | ✕ Liability |
# | ✓ Distribution   | License and copyright notice | ✕ Warranty  |
# | ✓ Modification   | Same license                 |             |
# | ✓ Patent use     | State changes                |             |
# | ✓ Private use    |                              |             |

########################################################################
# configuration

drive_class="nvme" # "nvme" for nvme0
drive_num="0"      # "0" for nvme0

wd_firmware_host="wddashboarddownloads.wdc.com"
devices_xml_path="/wdDashboard/config/devices/lista_devices.xml"

priv_exec="sudo" # "sudo", "pkexec", lxsudo, doas, etc

http_client="wget -qO" # "wget -qO" , "curl -so" , "aria2c -q -o"

tmp_dir="${XDG_RUNTIME_DIR:-/tmp}"

########################################################################

name="${drive_class}${drive_num}"
sys="/sys/class/$drive_class/$name"
dev="/dev/$name"
ifs=$IFS
sid="${0//\//_}"

echo "$0 - WD nvme drive firmware updater"
echo
echo "Updating firmware for $dev"
echo

mkdir -p $tmp_dir
cd $tmp_dir || {
	echo "Could not cd $tmp_dir !"
	exit 1
}

# all temp files
typeset -A tf=()
trap 'rm -f ${tf[@]}' 0

# required external utils
#echo "checking dependencies"
hc=${http_client%% *}
typeset -A hp=(
	[curl]=curl
	[wget]=wget
	[aria2c]=aria2
)
typeset -A pkg=(
	[${hc}]=${hp[${hc}]}
	[nvme]=nvme-cli
	[xmllint]=libxml2
)
type -p ${!pkg[*]} 2>&1 >/dev/null || {
	echo "Installing dependencies: ${pkg[*]}"
	$priv_exec apt install ${pkg[*]}
	echo
}
type -p ${!pkg[*]} 2>&1 >/dev/null || exit 1

# drive model number and firmware version
read drive_model < $sys/model
read firmware_rev < $sys/firmware_rev
echo "Model: $drive_model"
echo "Firmware: $firmware_rev"
echo

# device list and firmware URL
tf[all]="${sid}_all.xml"
rm -f "${tf[all]}"
$http_client "${tf[all]}" "https://${wd_firmware_host}${devices_xml_path}"

# using xmlstarlet or xmllint or any real xml parser would be more robust
#xmllint --xpath 'lista_devices/lista_device/url' $tmp_devices_xml

m="${drive_model// /_}"
typeset -A p=()
while read x ;do
	[[ $x =~ ^[[:space:]]*\<url\>.*/device_properties\.xml\</url\>[[:space:]]*$ ]] || continue
	[[ $x =~ /$m/ ]] || continue
	x="${x#*>}"
	x="${x%<*}"
	IFS=/ w=($x) IFS="$ifs"
	p+=([${w[3]}]="$x")
done < "${tf[all]}"

((${#p[@]})) || {
    echo "No matching firmware URL found for model $drive_model."
    exit 1
}

l=("" ${!p[@]})
i=${#p[@]}
v=${l[$i]}
u=${p[$v]}
[[ "$firmware_rev" == "$v" ]] && {
	echo "Already on latest firmware."
	exit 0
}

echo "Found the following firmware versions available for your drive:"
echo ${!p[@]}
echo
((i>1)) && {
	x="$PS3" PS3="Select version to install: "
	select v in ${!p[@]} ;do
		u= ;[[ "$v" ]] && u="${p[$v]}" && [[ "$u" ]] && break
	done
	PS3="$x"
}

# download the device properties XML and parse it
dxu="https://$wd_firmware_host/$u"
tf[one]="${sid}_one.xml"
rm -f "${tf[one]}"
$http_client "${tf[one]}" "$dxu"

fwf= deps=()
while read x ;do
	[[ $x =~ ^[[:space:]]*\<fwfile\>.*\</fwfile\>[[:space:]]*$ ]] && { x="${x#*>}" ;fwf="${x%<*}" ;continue ; }
	[[ $x =~ ^[[:space:]]*\<dependency.*\>.*\</dependency\>[[:space:]]*$ ]] && { x="${x#*>}" ;deps+=("${x%<*}") ; }
done < "${tf[one]}"

echo
echo "Firmware File: ${fwf}"
echo "Dependencies:"
echo "${deps[@]}"
echo

# check if current firmware is new enough to install the new one
[[ "${deps[@]}" =~ $firmware_rev ]] || {
    echo "Please up/downgrade to one of the dependency versions above first."
    exit 1
}

# download the firmware file
fwu="${dxu%/*}/${fwf}"
tf[fwf]="${sid}_${fwf}"
echo "Downloading $fwu ..."
rm -f "${tf[fwf]}"
$http_client "${tf[fwf]}" "${fwu}" || { echo "failed download" ;exit 1 ; }

# TODO verify download somehow

# load the firmware onto the drive
echo
a=n ;read -p"Load $fwf onto $dev (y/N)? " a
[[ $a == "y" ]] || { echo "Aborted" ;exit 1 ; }
$priv_exec nvme fw-download -f "${tf[fwf]}" $dev || exit 1

# activate the new firmware
echo
a=n ;read -p"Activate the new firmware (y/N)? " a
[[ $a == "y" ]] || { echo "Aborted" ;exit 1 ; }
$priv_exec nvme fw-commit -s 2 -a 3 $dev

echo
echo "Firmware update process completed. Please reboot."
echo
