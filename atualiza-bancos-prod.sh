#!/bin/bash
#***************************************************************************
# Arquivo...............: atualiza-bancos-prod.sh
# Funcao................: Restaura bancos da 8380 (producao) no ambiente 8580
# Origem backup.........: //10.0.0.4/e$/Backup-Progress/pp/
# Montagem local........: /mnt/backup-progress/Backup-Progress/pp/
# Destino...............: /bancos/DATABASE-JA-8580/
# Uso...................: sudo sh atualiza-bancos-prod.sh
# ATENCAO: executa proshut nos bancos 8580 antes de restaurar!
#***************************************************************************

export DLC=/usr/dlc128
export PATH=$PATH:$DLC/bin

BKP=/mnt/backup-progress/Backup-Progress/pp
DB_DIR=/bancos/DATABASE-JA-8580

echo "=== ATUALIZA BANCOS HML 8580 COM BASE PROD: $(date) ==="

# 1 — verificar montagem do backup
if ! mountpoint -q /mnt/backup-progress; then
    echo "ERRO: /mnt/backup-progress nao esta montado. Abortando."
    exit 1
fi

# 2 — derrubar bancos do 8580
echo ""
echo "--- Derrubando bancos 8580 ---"
for banco in emsfnd dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes hcm emsinc; do
    [ ! -f "$DB_DIR/${banco}.db" ] && continue
    proshut "$DB_DIR/$banco" -by 2>/dev/null && echo "PARADO: $banco" || echo "AVISO: $banco ja estava parado"
done
sleep 3

# 3 — restaurar bancos do backup (origem = producao 8380)
echo ""
echo "--- Restaurando bancos do backup prod ---"
prorest $DB_DIR/emsfnd   $BKP/emsfnd.bkp   && echo "OK: emsfnd"   || echo "ERRO: emsfnd"
prorest $DB_DIR/dtviewer $BKP/dtviewer.bkp && echo "OK: dtviewer" || echo "ERRO: dtviewer"
prorest $DB_DIR/eai      $BKP/eai.bkp      && echo "OK: eai"      || echo "ERRO: eai"
prorest $DB_DIR/ems2adt  $BKP/ems2adt.bkp  && echo "OK: ems2adt"  || echo "ERRO: ems2adt"
prorest $DB_DIR/ems2cad  $BKP/ems2cad.bkp  && echo "OK: ems2cad"  || echo "ERRO: ems2cad"
prorest $DB_DIR/ems2mov  $BKP/ems2mov.bkp  && echo "OK: ems2mov"  || echo "ERRO: ems2mov"
prorest $DB_DIR/ems2mp   $BKP/ems2mp.bkp   && echo "OK: ems2mp"   || echo "ERRO: ems2mp"
prorest $DB_DIR/ems5cad  $BKP/ems5cad.bkp  && echo "OK: ems5cad"  || echo "ERRO: ems5cad"
prorest $DB_DIR/ems5mov  $BKP/ems5mov.bkp  && echo "OK: ems5mov"  || echo "ERRO: ems5mov"
prorest $DB_DIR/emsdes   $BKP/emsdes.bkp   && echo "OK: emsdes"   || echo "ERRO: emsdes"
prorest $DB_DIR/hcm      $BKP/hcm.bkp      && echo "OK: hcm"      || echo "ERRO: hcm"
prorest $DB_DIR/emsinc   $BKP/emsinc.bkp   && echo "OK: emsinc"   || echo "ERRO: emsinc"

# 4 — subir bancos 8580 com portas HML (25xxx) — NAO usar portas da 8380!
echo ""
echo "--- Subindo bancos 8580 (portas HML) ---"
proserve $DB_DIR/emsfnd   -B 25000 -L 200000 -Mm 4096 -N tcp -S 25619 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsfnd (25619)"   || echo "ERRO subindo: emsfnd"
proserve $DB_DIR/dtviewer -B 1000  -L 2000   -Mm 4096 -N tcp -S 25650 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: dtviewer (25650)" || echo "ERRO subindo: dtviewer"
proserve $DB_DIR/eai      -B 100   -L 1000   -Mm 4096 -N tcp -S 25621 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: eai (25621)"      || echo "ERRO subindo: eai"
proserve $DB_DIR/ems2adt  -B 100   -L 2000   -Mm 4096 -N tcp -S 25600 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2adt (25600)"  || echo "ERRO subindo: ems2adt"
proserve $DB_DIR/ems2cad  -B 50000 -L 200000 -Mm 4096 -N tcp -S 25601 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2cad (25601)"  || echo "ERRO subindo: ems2cad"
proserve $DB_DIR/ems2mov  -B 50000 -L 300000 -Mm 4096 -N tcp -S 25602 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mov (25602)"  || echo "ERRO subindo: ems2mov"
proserve $DB_DIR/ems2mp   -B 100   -L 100    -Mm 4096 -N tcp -S 25603 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mp (25603)"   || echo "ERRO subindo: ems2mp"
proserve $DB_DIR/ems5cad  -B 50000 -L 200000 -Mm 4096 -N tcp -S 25606 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5cad (25606)"  || echo "ERRO subindo: ems5cad"
proserve $DB_DIR/ems5mov  -B 50000 -L 300000 -Mm 4096 -N tcp -S 25607 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5mov (25607)"  || echo "ERRO subindo: ems5mov"
proserve $DB_DIR/emsdes   -B 50000 -L 300000 -Mm 4096 -N tcp -S 25635 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsdes (25635)"   || echo "ERRO subindo: emsdes"
proserve $DB_DIR/hcm      -B 40000 -L 600000 -Mm 4096 -N tcp -S 25608 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: hcm (25608)"      || echo "ERRO subindo: hcm"
proserve $DB_DIR/emsinc   -B 100   -L 1000   -Mm 4096 -N tcp -S 25009 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsinc (25009)"   || echo "ERRO subindo: emsinc"

echo ""
echo "=== FIM: $(date) ==="
