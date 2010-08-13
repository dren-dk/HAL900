#!/bin/sh
# $Id$

if [ $# -ne 3 ]; then
    echo "Usage: $0 HOSTNAME IMAGE PARTITION"
    exit 1
fi

hostname=$1

if [ ! -f $2 ]; then
    echo "Image '$2' not found"
    exit 3
fi
diskimg=$2

if [ $3 -ne 1 -a $3 -ne 2 ]; then
    echo "Unsupported partition $3"
    exit 4
fi
partition=$3

cat "${diskimg}" | ssh root@"${hostname}" "zcat | sh /root/updatep${partition}"
