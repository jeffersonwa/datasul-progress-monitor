#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8580

declare -A PORTS
PORTS[dtviewer]=25650; PORTS[eai]=25621; PORTS[ems2adt]=25600
PORTS[ems2cad]=25601;  PORTS[ems2mov]=25602; PORTS[ems2mp]=25603
PORTS[ems5cad]=25606;  PORTS[ems5mov]=25607; PORTS[emsdes]=25635
PORTS[emsfnd]=25619;   PORTS[emsinc]=25009;  PORTS[hcm]=25608

for db in dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes emsfnd emsinc hcm; do
    [ ! -f $DB_DIR/${db}.db ] && continue
    port=${PORTS[$db]}
    ss -tln 2>/dev/null | grep -q ":${port} " || continue
    timeout 5 _mprshut $DB_DIR/$db -C list 2>/dev/null | while read line; do
        usr=$(echo "$line" | awk '{print $1}')
        [[ ! "$usr" =~ ^[0-9]+$ ]] && continue
        echo "$db|$line"
    done
done
