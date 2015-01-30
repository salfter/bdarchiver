#!/bin/bash

# NOTICE: the backup destination is hard-coded!  Replacing my email address
# (which also happens to be the username and hostname for the offsite VPS I
# use for backup) with the appropriate ssh credentials for your use would
# fix this.
#
# This is mainly a holdover from when I wasn't writing a copy of the
# database to every disc.  Now that I am, this script is somewhat less
# necessary.

source settings.sh

mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD -R $MYSQL_DB | bzip2 -9 >backup_index.sql.bz2
scp backup_index.sql.bz2 scott@alfter.us:
ssh scott@alfter.us bzcat backup_index.sql.bz2 \| mysql --password=$MYSQL_PASSWD $MYSQL_DB

tar cjf backup_index_scripts.tar.bz2 *.sh
scp backup_index_scripts.tar.bz2 scott@alfter.us:
