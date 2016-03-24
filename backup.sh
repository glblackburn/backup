#!/bin/bash
#
# Usage: backup.sh <CONFIG_FILE>
#
# Example:
# time ./backup.sh testconfig.cfg
#
# verbose output control flag
VERBOSE=
# to enable verbose uncomment the line below
#VERBOSE=true
# verbose output can be enabled in backup config file passed on as a comman line argument.
#
# CONFIG_FILE should set the following variables.
# BACKUP_LOG_DIR
# LOG
# PERF_LOG
# LOG_CLEAN_SED
# BACKUP_TO_DIR
# BACKUP_LIST_FILE
#
# All log files will be appended to prevent loss of output.  If you need a new log file, clear or set a new log file name outside this script.
#
BASEDIR=$(dirname $0)
SCRIPT_NAME=${0##*/}

if [ "x$1" != "x" ] ; then
  CONFIG_FILE=$1
else
  echo "Config file not specified!"
  exit 1
fi

#
# weekNo is a util function to setup the ${week} variable to use in the config 
# file to provide the option to backup to different directories by the week 
# number of the month.
#
function weekNo {
   day=`date +%_d`
   month=`date +%m`
   year=`date +%Y`
   week=`cal $month $year | sed -n "3,$ p" | sed -n "/$day/{=;q;}"`
   return $week
}
weekNo

#validate CONFIG_FILE exists
if [[ -f ${CONFIG_FILE} ]]; then
    . ${CONFIG_FILE}
else
  echo "Config file not found! [${CONFIG_FILE}]"
  exit 2
fi
CONFIG_FILE_NAME=${CONFIG_FILE##*/}

function backup {
    DATE=`date`
    echo "${DATE} - backup call with [$1] [${BACKUP_TO_DIR}]"
##  rsync --recursive --verbose --progress --perms --times "$1" ${BACKUP_TO_DIR}
##  rsync --archive --delete --verbose --progress "$1" ${BACKUP_TO_DIR}
  rsync --archive --delete --verbose "$1" ${BACKUP_TO_DIR}
}

function validateBackupDir {
    if [[ ${BACKUP_TO_DIR} =~ .*@.*:.* ]]; then
	echo "Backup dir is remote.  take it on faith and proceed. [${BACKUP_TO_DIR}]"
    else
	if [[ -d $BACKUP_TO_DIR ]]; then
	    echo "Backup dir found. proceed. [${BACKUP_TO_DIR}]"
	else
	    echo "Backup dir not found! [${BACKUP_TO_DIR}]"
	    exit 4
	fi
    fi
}

LOCK_FILE=${BACKUP_LOG_DIR}/${SCRIPT_NAME}_${CONFIG_FILE_NAME}.lock
function validateThereCanBeOnlyOne {
    echo "LOCK_FILE=[${LOCK_FILE}]"
    if [[ -e $LOCK_FILE ]]; then
	echo "Lock file exists! [${LOCK_FILE}]"
	exit 5
    else
	echo "Create lock file."
        {
          echo "PID=[$$]"
echo "in validateThereCanBeOnlyOne"
          echo "LOG=[${LOG}]"
        } > ${LOCK_FILE}
    fi
}

function cleanUpThereCanBeOnlyOne {
    echo "LOCK_FILE=[${LOCK_FILE}]"
    if [[ -e $LOCK_FILE ]]; then
	echo "Remove lock file."
	rm ${LOCK_FILE}
    else
	echo "Lock file does not exist!"
    fi
}

function validateLogDir {
    if [[ -d $BACKUP_LOG_DIR ]]; then
	if [ $VERBOSE ] ; then
	    echo "Log dir exists.  proceed. [${BACKUP_LOG_DIR}]"
	fi
    else
	echo "Log dir not found! [${BACKUP_LOG_DIR}]"
	exit 3
    fi
}

#
# cleanEmptyLogFile will use the ${LOG_CLEAN_SED} file to compare the current log file to a base line using sed to zero out match the log file.
# the function is almost done.  Example file does match the log file.  The full match on the file is not deleted yet.
function cleanEmptyLogFile {

    if [ $VERBOSE ] ; then
	echo "LOG_CLEAN_SED=[${LOG_CLEAN_SED}]"
	echo "LOG=[${LOG}]"
    fi

    sed -f ${LOG_CLEAN_SED} ${LOG}
}

validateLogDir
if [ $VERBOSE ] ; then
    echo "after validateLogDir - before logging"
fi
echo "LOG=[${LOG}]"
{
    if [ $VERBOSE ] ; then
	echo "inside logging"
    fi
    START=`date`
    echo "${START} - start"

    echo "BACKUP_TO_DIR=[${BACKUP_TO_DIR}]"
    echo "PERF_LOG=[${PERF_LOG}]"
    echo "LOG=[${LOG}]"

    validateThereCanBeOnlyOne
    validateBackupDir

    if [[ -f ${BACKUP_LIST_FILE} ]]; then
	. ${BACKUP_LIST_FILE}
    else
	echo "Backup list file not found! [${BACKUP_LIST_FILE}]"
	exit 2
    fi

    END=`date`
    echo "${START} - start"
    echo "${END} - end"

    #do not calculate free space on remote
    if [[ ${BACKUP_TO_DIR} =~ .*@.*:.* ]]; then
	echo "Backup dir is remote.  do not calculate free space on remote. [${BACKUP_TO_DIR}]"
    else
	FREE_SPACE=`df -k ${BACKUP_TO_DIR} | tail -1 | sed "s/\s\+/,/g"`
    fi

    #the du takes too long.
    #USED_SPACE=`du -sk -I .Trashes ${BACKUP_TO_DIR} | sed "s/\s\+/,/g"`
    USED_SPACE="not done"

    cleanUpThereCanBeOnlyOne
} >> ${LOG} 2>&1

## do not need ${BACKUP_TO_DIR}.  ${FREE_SPACE} has that info too.
echo "${START},${END},${USED_SPACE},${FREE_SPACE}" >> ${PERF_LOG}

if [ $VERBOSE ] ; then
    echo "#### Dump logfile: ${LOG}"
    cat ${LOG}
fi

cleanEmptyLogFile