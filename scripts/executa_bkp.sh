#!/bin/bash
export DLC=/usr/dlc128
export PATH=$PATH:$DLC/bin

BKP_DIR=/mnt/backup-progress/Backup-Progress/PP/8380
LOCAL_BKP_DIR=/bancos/DATABASE-JA-8380/bkp_local
LOG_DIR=$BKP_DIR/logs
DATA=$(date +%Y-%m-%d)
LOG=$LOG_DIR/backup-$DATA.log

mkdir -p $LOG_DIR
mkdir -p $LOCAL_BKP_DIR

_log() { echo "$1" | tee -a $LOG; }

_log "=== INICIO BACKUP ONLINE: $(date) ==="

if ! mountpoint -q /mnt/backup-progress; then
    _log "ERRO: /mnt/backup-progress nao esta montado. Abortando."
    exit 1
fi

cd /bancos/DATABASE-JA-8380

for banco in dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes emsfnd emsinc hcm; do
    _log "--- backup: $banco ---"
    if probkup online $banco $LOCAL_BKP_DIR/${banco}.bkp -com >> $LOG 2>&1; then
        _log "OK: $banco"
    else
        _log "ERRO: $banco"
    fi
done

_log "Transferindo backups para o diretorio externo..."
if mv $LOCAL_BKP_DIR/*.bkp $BKP_DIR/ >> $LOG 2>&1; then
    _log "OK: Transferencia concluida com sucesso."
else
    _log "ERRO: Falha na transferencia dos backups."
fi

find $LOG_DIR -name 'backup-*.log' -mtime +30 -delete

_log "=== FIM BACKUP: $(date) ==="
