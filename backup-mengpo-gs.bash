#!/bin/bash
#
# Script for pushing LVM snapshots to Google Storage
# Author: Markus Koskinen - License: BSD
#
# Requires: configured gsutil, gpg, lvmtools etc
#
# Remember to configure some rotating of the resulting
# backup files.

##############################################
# Configurations
##############################################

# Google Storage bucket name
BUCKET="gs-backup"
# LVM Volume group name and volume name, check with "lvdisplay"
VOLGROUP="vg_kvm01_ssd"
VOLNAME="mengpo"
# This file contains the symmetric passphrase, any random string
PASSFILE="/root/backup-scripts/mengpo.pwd"
# LVM snapshot size in "-L" format. This should be greater
# than the amount of changes on the source volume during
# the backup upload process
SNAPSIZE="3G"

# Cleanup. How many snapshots you want to keep. 0 is infinite.
SNAPSHOT_RETENTION_COUNT=4
# More cleanup. Only remove files with this suffix. Set "" to rotate all.
SNAPSHOT_ROTATION_SUFFIX="/*.dd.gz.gpg"

# A directory withing the bucket
REMOTEDIR="${VOLNAME}"
# Arbitrary snapshot name, used for backup filename as well
# Just needs to be unique and descriptive
SNAPNAME="snap_${VOLNAME}"
# gsutil path (do not use quotes if using tilde)
GSUTIL=~/gsutil/gsutil

##############################################
# Do not edit below this line
##############################################

# Cleanup starts here

function snapshot_cleanup {
  if [ $SNAPSHOT_RETENTION_COUNT -eq 0 ]
  then
    # If $SNAPSHOT_RETENTION_COUNT is set to 0, we don't "rotate"
    return
  fi

  SNAPSHOT_LIST=$($GSUTIL ls gs://${BUCKET}/${REMOTEDIR}${SNAPSHOT_ROTATION_SUFFIX}|sort|uniq|sort)
  SNAPSHOT_COUNT=$(echo "${SNAPSHOT_LIST}"|wc -l)

  while [ $SNAPSHOT_COUNT -gt $SNAPSHOT_RETENTION_COUNT ]
  do
    echo "Snapshot count = $SNAPSHOT_COUNT"
    REMOVEFILE=$(echo "${SNAPSHOT_LIST}"|head -n1)
    echo "File to remove = ${REMOVEFILE}"

    if ! $GSUTIL rm ${REMOVEFILE}; then
      echo "ERROR: Could not perform snapshot cleanup. Check your permissions."
      return
    fi

    SNAPSHOT_LIST=$($GSUTIL ls gs://${BUCKET}/${REMOTEDIR}|sort|uniq|sort)
    SNAPSHOT_COUNT=$(echo "${SNAPSHOT_LIST}"|wc -l)
  done
}

snapshot_cleanup

#
# Snapshot creation starts here
#

# Create a snapshot
/usr/sbin/lvcreate -L${SNAPSIZE} -s -n "${SNAPNAME}" "/dev/${VOLGROUP}/${VOLNAME}"

# DD the image through gzip and gsutil
# With GPG, gzip forked as --fast in other process.
/usr/bin/time /bin/dd if="/dev/${VOLGROUP}/${SNAPNAME}" bs=128k |\
   /bin/nice -n 19 /bin/gzip --fast -|\
   /bin/nice -n 19 /usr/bin/gpg -z 0 -c --batch --no-tty --passphrase-file "${PASSFILE}" |\
   ${GSUTIL} -q cp - gs://${BUCKET}/${REMOTEDIR}/${SNAPNAME}-$(date +%Y%m%d-%H%M.dd.gz.gpg)

# Drop the snapshot
/usr/sbin/lvremove -f "/dev/${VOLGROUP}/${SNAPNAME}"
