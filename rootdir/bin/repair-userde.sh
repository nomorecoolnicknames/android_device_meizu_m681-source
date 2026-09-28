#!/system/bin/sh

set -eu

if [ -L /data/user_de/0 ]; then
    rm -f /data/user_de/0
fi

if [ ! -d /data/user_de ]; then
    mkdir -p /data/user_de
fi

if [ ! -d /data/user_de/0 ]; then
    mkdir -p /data/user_de/0
fi
