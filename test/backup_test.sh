#!/bin/bash
#
echo "before backup"
find target -type f -exec ls -l {} \;
echo "================================================================================"
BASEDIR=$(dirname $0)
. ${BASEDIR}/../backup.sh ${BASEDIR}/backup.cfg
echo "================================================================================"
echo "after backup"
find target -type f -exec ls -l {} \;
