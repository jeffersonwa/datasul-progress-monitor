#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8580
for pid in $(pgrep -f "_mprosrv.*DATABASE-JA-8580" 2>/dev/null); do
    cmd=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
    banco=$(echo "$cmd" | grep -oP '/bancos/DATABASE-JA-8580/\K\w+')
    [ -z "$banco" ] && continue
    read_bytes=$(grep '^read_bytes:' /proc/$pid/io 2>/dev/null | awk '{print $2}')
    write_bytes=$(grep '^write_bytes:' /proc/$pid/io 2>/dev/null | awk '{print $2}')
    echo "$banco|${read_bytes:-0}|${write_bytes:-0}"
done
