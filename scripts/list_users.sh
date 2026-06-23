#!/bin/bash
export DLC=/usr/dlc128
export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8380

declare -A PORTS
PORTS[dtviewer]=23650; PORTS[eai]=23621; PORTS[ems2adt]=23600
PORTS[ems2cad]=23601;  PORTS[ems2mov]=23602; PORTS[ems2mp]=23603
PORTS[ems5cad]=23606;  PORTS[ems5mov]=23607; PORTS[emsdes]=23635
PORTS[emsfnd]=23619;   PORTS[emsinc]=23009;  PORTS[hcm]=23608

for db in dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes emsfnd emsinc hcm; do
    [ ! -f $DB_DIR/${db}.db ] && continue
    port=${PORTS[$db]}
    ss -tlnp 2>/dev/null | grep -q ":${port} " || continue
    timeout 5 _mprshut $DB_DIR/$db -C list 2>/dev/null | while read line; do
        usr=$(echo "$line" | awk '{print $1}')
        [[ ! "$usr" =~ ^[0-9]+$ ]] && continue
        echo "$db|$line"
    done
done
