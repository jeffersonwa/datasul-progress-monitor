#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8480

declare -A PORTS
PORTS[dtviewer]=24650; PORTS[eai]=24621; PORTS[ems2adt]=24600
PORTS[ems2cad]=24601;  PORTS[ems2mov]=24602; PORTS[ems2mp]=24603
PORTS[ems5cad]=24606;  PORTS[ems5mov]=24607; PORTS[emsdes]=24635
PORTS[emsfnd]=24619;   PORTS[emsinc]=24009;  PORTS[hcm]=24608

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
