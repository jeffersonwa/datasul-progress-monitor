#!/bin/bash
# Uso: kick_user.sh <nome_usuario>
export DLC=/usr/dlc128
export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8380
USUARIO="$1"

if [ -z "$USUARIO" ]; then
    echo "ERRO: usuario nao informado"
    exit 1
fi

DESCONECTADOS=0
ERROS=0

for db in dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes emsfnd emsinc hcm; do
    [ ! -f $DB_DIR/${db}.db ] && continue
    _mprshut $DB_DIR/$db -C list 2>/dev/null | grep -i "$USUARIO" | while read line; do
        usr=$(echo "$line" | awk '{print $1}')
        [[ ! "$usr" =~ ^[0-9]+$ ]] && continue
        _mprshut $DB_DIR/$db -C disconnect $usr 2>&1
        if [ $? -eq 0 ]; then
            echo "OK:$db:$usr"
        else
            echo "ERRO:$db:$usr"
        fi
    done
done
