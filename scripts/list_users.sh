#!/bin/bash
export DLC=/usr/dlc128
export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8380

for db in dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes emsfnd emsinc hcm; do
    [ ! -f $DB_DIR/${db}.db ] && continue
    timeout 8 _mprshut $DB_DIR/$db -C list 2>/dev/null | while read line; do
        usr=$(echo "$line" | awk '{print $1}')
        [[ ! "$usr" =~ ^[0-9]+$ ]] && continue
        echo "$db|$line"
    done
done
