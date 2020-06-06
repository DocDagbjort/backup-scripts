#!/bin/bash
#
# Script for pushing LVM snapshots to an SSH host
# Author: Markus Koskinen - License: BSD
#
# Requires: configured ssh keys, gpg, lvmtools, time etc
#
# Remember to configure some rotating of the resulting
# backup files.

##############################################
# Configuration
##############################################

# LVM Volume group name and volume name, check with "lvdisplay"
VOLGROUP="name_of_volume_group"
VOLNAME="name_of_volume"
# This file contains the symmetric passphrase, any random string
# Leave blank to skip use of gpg
PASSFILE=

# LVM snapshot size in "-L" format. This should be greater
# than the amount of changes on the source volume during
# the backup upload process
SNAPSIZE="10G"

# Target host and user, with public/private keys configured
REMOTE="user@hostname.tld"
# A directory within the bucket
# Remember to create this in advance
REMOTEDIR="/home/user/wherever/"
# Arbitrary snapshot name, used for backup filename as well
# Just needs to be unique and descriptive
SNAPNAME="snap_${VOLNAME}"
# SSH port (usually 22)
SSH_PORT=22
#Leave blank to use the user's default SSH key, or whatever is in .ssh/config for the hostname
SSH_KEY=/root/.ssh/key_for_backups

#Leave blank to skip gzip
GZIP_LEVEL=5

##############################################
# Do not edit below this line
##############################################

# Create a snapshot (WARNING: currently set to 10G changes)
/usr/sbin/lvcreate -L${SNAPSIZE} -s -n "${SNAPNAME}" "/dev/${VOLGROUP}/${VOLNAME}"


if [ "$GZIP_LEVEL" == "" ]; then
  GZIP_CALL=""
else
  GZIP_CALL="/bin/nice -n 19 /bin/gzip -"${GZIP_LEVEL}" -|"
  SUFFIX=".gz"
fi

if [ "$PASSFILE" == "" ]; then
  GPG_CALL=""
else
  GPG_CALL="/bin/nice -n 19 /usr/bin/gpg -z 0 -c --batch --no-tty --passphrase-file "${PASSFILE}" |"
  SUFFIX=".gpg"${SUFFIX}""
fi

if [ "$SSH_KEY" == "" ]; then
  SSH_KEY_CALL="/usr/bin/ssh -p ${SSH_PORT} "${REMOTE}""
else
  SSH_KEY_CALL="/usr/bin/ssh -i "${SSH_KEY}" -p ${SSH_PORT} "${REMOTE}" "
fi

#For debugging
#echo ${GPG_CALL}
#echo ${GZIP_CALL}

FULL_CALL="/usr/bin/time /bin/dd if=\"/dev/${VOLGROUP}/${SNAPNAME}\" bs=128k |"
FULL_CALL=" "${FULL_CALL}" "${GZIP_CALL}" "
FULL_CALL=" "${FULL_CALL}" "${GPG_CALL}" "
FULL_CALL=" "${FULL_CALL}" "${SSH_KEY_CALL}" "
FULL_CALL=" "${FULL_CALL}" \"/bin/cat > ${REMOTEDIR}/${SNAPNAME}-$(date +%Y%m%d-%H%M.dd"${SUFFIX}")\" "

echo "Running: "
echo ""
echo ${FULL_CALL}

eval ${FULL_CALL}

# Drop the snapshot
echo ""
/usr/sbin/lvremove -f "/dev/${VOLGROUP}/${SNAPNAME}"
