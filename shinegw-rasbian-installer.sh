#!/bin/bash

cleanup_on_exit() {
	umount -f ${BOOT_PARTITIOIN}
	umount -f ${ROOT_PARTITIOIN}
	#rm -rf /media/boot 2>/dev/null
	rm -rf /media/os 2>/dev/null
}

#*****************Installing the OS******************#

echo "***********************************************"
echo "*       Shine Seniors Rasbian Installer       *"
echo "***********************************************"
echo 
# Messages
ERR="[ERROR]"
NOTE="[NOTICE]"
WARN="[WARNING]"
USAGE="Usage: $0 <device> <path to Raspbian TarBall> <shine seniors folder> <target node ID (integer)>"

# Assign to sensible variable name for sanity
DEVICE="$1"
TARBALL_PATH="$2"
SHINE_FOLDER="$3"
TARGET_NODEID="$4"

# Config file settings
CONFIG_FILE='/media/os/root/shine/input.config'
ROOT_FOLDER_SD='/media/os/root/'
SHINE_FOLDER_SD='/media/os/root/shine/'
HOST_NAME='/media/os/etc/hostname'
NODE_ID_VAR_NAME='generic.node-id'
SSH_KEYFILE='/media/os/root/shine/shineseniors-reverse-ssh-key'

# Configuration
KEYSERVER_LOCATION="aws.shineseniors.org"
KEYSERVER_USERNAME="ubuntu"
SHINEGW_FILES_DIR="shinegw-files"

#Test for root
if [ $EUID -ne 0 ]; then
	echo "$ERR This script must be run as root."
	exit 1
fi

# Test for number of arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
	echo "$ERR $USAGE"
	echo -e "Use \$df -h to display <device> [eg: /dev/mmcblk0, /dev/scb]"
	exit 1
fi

# Generate partition names
if echo $DEVICE | grep -qs mmcblk; then
    BOOT_PARTITIOIN="${DEVICE}p1"
    ROOT_PARTITIOIN="${DEVICE}p2"
else
    BOOT_PARTITIOIN="${DEVICE}1"
    ROOT_PARTITIOIN="${DEVICE}2"
fi;

# Check if DEVICE is a block DEVICE
if [[ ! -b "${DEVICE}" ]]; then
    echo "${DEVICE} is not a block DEVICE"
    exit 1
fi;

# Exit bash script if any command fails
set -e

#*******************Formatting the SD****************#

# Unmount DEVICEs
if grep -qs "${BOOT_PARTITIOIN}" /proc/mounts; then
    umount ${BOOT_PARTITIOIN}
	echo "$[NOTE] $PARTITION_1 unmounted"
else 
	echo "$[WARNING] No SD card partition(s) found"
fi;
if grep -qs "${ROOT_PARTITIOIN}" /proc/mounts; then
    umount ${ROOT_PARTITIOIN}
fi;

# Check for the version
sfdisk --version | grep 2.26

if [ $? -eq 0 ]; then
	# Make the Raspbian partition table, sfdisk 2.26
	sfdisk --force ${DEVICE} <<HEREDOC
unit: sectors

8192   +60M c
131072 +    L
HEREDOC

else
	# Make the Raspbian partition table, older sfdisk versions
	sfdisk --force ${DEVICE} <<HEREDOC
unit: sectors 

partition1 : start=2048,   size=131072, Id=e, bootable
partition2 : start=133120, size=,       Id=83
partition3 : start=0,      size=0,      Id=0
partition4 : start=0,      size=0,      Id=0
HEREDOC

fi

# Make filesystems
mkfs.vfat ${BOOT_PARTITIOIN}
mkfs.ext4 -m 0 ${ROOT_PARTITIOIN}

# Label filesystems
dosfslabel ${BOOT_PARTITIOIN} BOOT_PRT
e2label ${ROOT_PARTITIOIN} RASPBIAN_PRT

# Mount partitions
rm -rf /media/os
mkdir /media/os
mount ${ROOT_PARTITIOIN} /media/os
mkdir /media/os/boot
mount ${BOOT_PARTITIOIN} /media/os/boot

echo "Formatting FINISH"

#***********Extracting the Operating System*********#
  
# Coppying the tarball
echo "Extracting the Operating System files to $DEVICE. This may take few minutes"	
pv --bytes --progress --timer --eta $TARBALL_PATH | bsdtar -xpf - -C /media/os/

#************Making Custom Configurations************#

# Copy the shine seniors folder
echo "$NOTE Start coppying the Shine folder"
cp -avrf "$SHINE_FOLDER" "$ROOT_FOLDER_SD"
if [ $? -eq 0 ]; then
	echo "$NOTE Shine folder was coppied"
else
	echo "$ERR Shine folder couldn't be coppied. Script will now terminate"
	cleanup_on_exit
	exit 1
fi

# Check if the config file exists
if [ -e $CONFIG_FILE ]; then
	echo "$NOTE Found the config file, $CONFIG_FILE!"
else
	echo "$ERR Config file does not exist! Script will now terminate"
	cleanup_on_exit
	exit 1
fi

# Change the node ID value
sed -i "s/\($NODE_ID_VAR_NAME *\t\t\t\t *\).*/\1$TARGET_NODEID/" $CONFIG_FILE
echo "[NOTICE] $NODE_ID_VAR_NAME is set to $TARGET_NODEID."

#**********Changeing the File Permissions***********#
# shine folder Files
chmod 700 $SHINE_FOLDER_SD
if [ $? -eq 0 ]; then
	echo "$NOTE Permission changed for Shine Folder"
else
	echo "$ERR Permission changed for Shine Folder FAILED!!!"
	echo "$ERR Programmes will not run properly"
	echo "Exiting"
	exit 1
fi

# .sh Files
find $SHINE_FOLDER_SD -name "*.sh" -type f -exec chmod +x {} \;
if [ $? -eq 0 ]; then
	echo "$NOTE Permission changed for .sh file(s)"
else
	echo "$ERR Permission changed for .sh file(s) FAILED!!!"
	echo "$ERR Programmes will not run properly"
	echo "Exiting"
	exit 1
fi

# .elf files
find $SHINE_FOLDER_SD -name "*.elf" -type f -exec chmod +x {} \;
if [ $? -eq 0 ]; then
	echo "$NOTE Permission changed for .elf file(s)"
else
	echo "$ERR Permission changed for .elf file(s) FAILED!!!"
	echo "$ERR Programmes will not run properly"
	echo "Exiting"
	exit 1
fi

# .pl files
find $SHINE_FOLDER_SD -name "*.pl" -type f -exec chmod +x {} \;
if [ $? -eq 0 ]; then
	echo "$NOTE Permission changed for .pl file(s)"
else
	echo "$ERR Permission changed for .elf file(s) FAILED!!!"
	echo "$ERR Programmes will not run properly"
	echo "Exiting"
	exit 1
fi

# ssh-key file
chmod 600 $SSH_KEYFILE
if [ $? -eq 0 ]; then
	echo "$NOTE Permission changed for the ssh-key"
else
	echo "$ERR Permission changed for ssh-key FAILED!!!"
	echo "$ERR Programmes will not run properly"
	echo "Exiting"
	exit 1
fi

# Change the hostname of the RPi
if [ -e $HOST_NAME ]; then
	echo "$NOTE Found the hostname file. Changing hostname to $TARGET_NODEID"

	echo $TARGET_NODEID > "$HOST_NAME"
	if [ $? -eq 0 ]; then
		echo "$NOTE Hostname successfully changed"
	else
		echo "$ERR Changing hostname failed! The overlay will probably not work too"
	fi

else
	echo "$ERR Config file does not exist! Script will now terminate"
	cleanup_on_exit
	exit 1
fi

#Flush the cash and exit
sync

cleanup_on_exit

echo "JOB DONE! Remove the SD card from the slot"

exit 0
