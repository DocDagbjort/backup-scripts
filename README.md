# backup-scripts

### Some scripts for handling LVM snapshot backups

*These are shell scripts so things can easily go wrong, please
be careful.*

"mengpo" is an example VM name, with respective LVM partitions.

Requires lvmtools, gpg, gzip

The SSH and GS versions share stuff and could be put into
a single file, but I figured it could be clearer separately.

Feel free to change as you wish.

#### TODO ###

It would make sense to make a version of the files that can
be called with arguments, which would help updating the scripts.
You could then call the same file from cron with args, or make
source the file and make script files for each backup separately,
with only the args as values.

I'll probably do that next.

### ./backup-host-gs.bash

Pushes backups to Google Cloud storage.
Requires configured gsutil (https://cloud.google.com/storage/docs/gsutil_install)

Supports crude rotating of old backups. Set SNAPSHOT_RETENTION_COUNT variable
to the amount of backups you want to store.

SNAPSHOT_ROTATION_SUFFIX can be set as a crude filter to avoid touching other
files in the directory. Normally you should not store other files in the
directories.

A more sophisticated system for cleanup is suggested though. You should not let
the user that pushes the backups be able to remove them afterwards.

### ./backup-host-ssh.bash

Pushes backups to an SSH host. Remember to set up your private/public keys.

Depending on the filesystem layout on the backup server, you might consider
using LVM partitions, quotas, or sticky bits to take care of file permissions
and to have safeguards against filling the system by accident.

### Extracting / Recovering

Again "mengpo" and "gs-backup" are just example names

From file:

% gpg -d --passphrase-file mengpo.pwd snap_mengpo-20151022-0800.dd.gz.gpg|gunzip -> targetfile_or_device.dd

From stream:

% gsutil cp gs://gs-backup/mengpo/snap_mengpo-20151022-0800.dd.gz.gpg -|gpg -d --passphrase-file mengpo.pwd -|gunzip -> targetfile_or_device.dd