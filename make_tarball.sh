#!/bin/bash

print_usage() {
    echo "Creates an OS tarball"
    echo "Usage: $0 [-f os-tarball] device"
}

OPTIND=1
while getopts ":f:" opt; do
  case $opt in
    f) os_tarball=$OPTARG
      ;;
    \?)
      echo "Error: invalid option: -$OPTARG"
      print_usage
      exit 1
      ;;
    :)
      echo "Error: option -$OPTARG requires an argument."
      print_usage
      exit 1
      ;;
  esac
done

shift $(( OPTIND - 1 ))
if [[ $# -ne 1 ]]; then
    print_usage;
    exit 1
fi;
device=$1

# Folder from which script was run
os_dir=$( dirname $0 )

# temp folder to work in
tmp_mnt=/tmp/$( basename $0 )

# Check for root privileges
if [[ $UID != 0 ]]; then
    echo "Error: this script must be run as root"
    exit 1;
fi

# Check if device is a block device
if [[ ! -b "${device}" ]]; then
    echo "${device} is not a block device"
    exit 1
fi;

# Set default os tarball name
if [[ -z "$os_tarball" ]]; then
    os_tarball="blobs/iot-$( date +%Y-%m-%d ).tar"
fi;

# Check if OS tarball exists
if [[ -f "$os_tarball" ]]; then
    echo "Error: $os_tarball exists"
    exit 1
fi;

# Get partition names
if echo $device | grep -qs "mmcblk"; then
    boot_partition="${device}p1"
    root_partition="${device}p2"
else
    boot_partition="${device}1"
    root_partition="${device}2"
fi;

echo "Device         : $device"
echo "Boot partition : $boot_partition"
echo "Root partition : $root_partition"
echo "OS tarball     : $os_tarball"

# Exit bash script if any command fails
set -e

# Unmount all partitions
for p in ${device}*; do
    grep -qs "^${p} " /proc/mounts && umount "$p"
done

# Mount partitions
mkdir -p $tmp_mnt/r
mount ${root_partition} $tmp_mnt/r
mount ${boot_partition} $tmp_mnt/r/boot/

# Create tarball
echo -n "Calculating size of $tmp_mnt/r..."
size=$( du --bytes --summarize $tmp_mnt/r/ 2>/dev/null | cut -f 1 )
echo $( numfmt --to=iec-i --suffix=B $size )

echo "Creating $os_tarball"
tar -cpf - --directory=$tmp_mnt/r --exclude=tmp/* . | (pv --size $size --bytes --progress --timer --eta > $os_tarball)

# Unmount partitions and sync
echo "Unmounting and flushing file system buffers..."
umount $tmp_mnt/r/boot $tmp_mnt/r
rmdir --ignore-fail-on-non-empty $tmp_mnt/r $tmp_mnt
sync

echo "It is finished."
