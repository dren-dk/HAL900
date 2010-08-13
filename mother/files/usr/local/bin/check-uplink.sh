#!/bin/sh
# $Id$

LEDDEV=/dev/led/error
ALARMOFF=0
ALARMON=sBj

if [ -z "${1}" ]; then
    echo "Usage: ${0} HOSTNAME"
    exit 1
fi

if ping -c 1 ${1} > /dev/null; then
    echo ${ALARMOFF} > ${LEDDEV}
else
    echo ${ALARMON} > ${LEDDEV}
    exit 1
fi
