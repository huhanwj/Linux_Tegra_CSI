#!/bin/bash

# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
# Individual Contributor License Agreement (CLA):
# https://gist.github.com/alex3165/0d70734579a542ad34495d346b2df6a5

#Overlay for flashing, calling nvautoflash and/or initrd flash for external media

# USAGE:

# sudo ./nvsdkmanager_flash.sh --storage <storage media>
# sudo ./nvsdkmanager_flash.sh --custom <user specified custom command>
#
# If no argument given runs nvautoflash by default
# sudo ./nvsdkmanager_flash.sh

set -o pipefail;
set -o errtrace;
shopt -s extglob;
curdir=$(dirname "$0");
curdir=$(cd "${curdir}" && pwd);
initrd_path="tools/kernel_flash/l4t_initrd_flash.sh";
xml_config="tools/kernel_flash/flash_l4t_external.xml";

function help_func
{
	echo "Usage: ./nvsdkmanager [OPTIONS]"
	echo "   No option runs autoflash by default"
	echo "   -c | --custom - User defined custom command"
	echo "   -s | --storage - Uses enters specific storage media to flash"
	echo "   -h | --help - displays this message"
}

function concatenate_args
{
	string=""
	for arg in "$@" # Loop over arguments
	do
		if [[ "${string}" != "" ]]; then
			string+=" " # Delimeter
		fi
		string+="${arg}"
	done
	echo "${string}"
}

function flash_target_with_external_storage
{
	local storage=$1
	local target_board=""
	exec 5>&1
	# Check for error code and display nvautoflash error
	if OUTPUT=$(./nvautoflash.sh --print_boardid | tee >(cat - >&5)) ; then
		echo "Parsing boardid successful"
	else
		echo "*** ERROR: Parsing boardid failed"
		exit 1
	fi
	# parse out target_board for initrd flash
	target_board="$(echo "${OUTPUT}" | cut -d " " -f 1 | tail -1)"
	echo "Target board is ${target_board}"
	if [ "${storage}" = "sda1" ] || [ "${storage}" = "nvme0n1p1" ]; then
		echo "External storage specified ${storage}"
		if [[ "${target_board}" == *"jetson-xavier-nx-devkit"* ]]; then
			echo "Flashing Jetson Xavier NX"
			NO_ROOTFS=0 "${curdir}"/"${initrd_path}" --external-device "${storage}" -c "${xml_config}" --showlogs jetson-xavier-nx-devkit-qspi internal
		elif [[ "${target_board}" == *"jetson-agx-xavier"* ]]; then
			echo "Flashing Jetson Xavier"
			"${curdir}"/"${initrd_path}" --external-device "${storage}" -c "${xml_config}" "${target_board}" "${storage}"
		else
			echo "*** ERROR: Unsupported device"
		fi
	else
		echo "*** ERROR: Invalid storage device"
		echo "Please enter sda1 or nvme0n1p1"
		exit 1
	fi
}

# if the user is not root, there is not point in going forward
THISUSER=$(whoami)
if [ "x$THISUSER" != "xroot" ]; then
	echo "***ERROR: This script requires root privilege"
	exit 1
fi

if [[ $# -eq 0 ]]; then
	echo "Defaulting to autoflash"
	"${curdir}"/nvautoflash.sh
	exit 0
fi

while [ "$1" != "" ];
do
   case $1 in
	-c | --custom )
		shift
		# Concat args given by user to run custom cmd
		args="$(concatenate_args "$@")"
		echo "${args}"
		eval "${args}"
		exit 0
		;;
	-s | --storage )
		shift
		storage_arg=$1 # extract argument after flag
		echo "user entered ${storage_arg}"
		# calling helper function to handle initrd flash for storage media
		flash_target_with_external_storage "${storage_arg}"
		exit 0;
		;;
	-h | --help )
		help_func
		exit
	  ;;
	* )
		echo "*** ERROR Invalid flag"
		help_func
		exit
	   ;;
	esac
	shift
done
