# Raspbian Installer for Shine Seniors MedBox gateway

#### THIS SCRIPT SHOULD BE RUN AS ROOT												  
The shinegw-rasbian-installer.sh bash script is the second part of the SD replicating system for the SMU-TCS iCity Labs RPi Gateway. This script initially partition (sfdisk) and format  the SD card into a 60MB FAT partition and the rest of the SD into a linux Ext partition. Then it mounts the Ext partition to ‘/media/os’ and FAT partition to ‘/media/os/boot’ and extract the previously generated tarball made by the make_tarball.sh script. 	  
																				  
Please note that the older versions of sfdisk gets the partitioning table parameters in a different template than the newer versions. Both the versions are included in the script. Please feel free to change the version checking statement (# Check for the version) of the script as required. 				  
																				  
If the ssh key to the server was given as the last parameter, the script will download the ‘shineseniors-reverse-ssh-key’ file from the aws.shineseniors.org server and copy into the /root/shine folder. Given below are the key parameters used while copying files from the cloud server. 
```sh
 #Configuration																  
	KEYSERVER_LOCATION="name_of_the_key_server"									  
	KEYSERVER_USERNAME="user_account_name_of_the_provided_key"					  
	SHINEGW_FILES_DIR="location_of_the ‘shineseniors-reverse-ssh-key’ file"		  
```																		  
## Using shinegw-rasbian-installer script:										  
																				  
##### Install prerequisite software:	
```sh
$sudo apt-get -y install pv bsdtar 											  
```
##### Usage:
```sh
$0 <device> <path to Raspbian TarBall generated by make_tarball.sh script> <location to the shine seniors folder> <target node ID (integer)> [optional: key file to key-server]												  
```
Please note that the “device” should be the path to a block device. As an example
you should enter:
```sh
          $sudo ./shinegw-rasbian-installer_2.1.sh /dev/mmcblk0 <> <> <> ...     
  BUT NOT $sudo ./shinegw-rasbian-installer_2.1.sh /dev/mmcblk0p1 <> <> <> ...   
```																				  
																				  
 Version 2.3	
