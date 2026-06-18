#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8580
echo "=== CARGA 8580: $(date) ==="
proserve $DB_DIR/emsfnd   -B 25000 -L 200000 -Mm 4096 -N tcp -S 25619 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsfnd (25619)"   || echo "ERRO: emsfnd"
proserve $DB_DIR/dtviewer -B 1000  -L 2000   -Mm 4096 -N tcp -S 25650 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: dtviewer (25650)" || echo "ERRO: dtviewer"
proserve $DB_DIR/eai      -B 100   -L 1000   -Mm 4096 -N tcp -S 25621 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: eai (25621)"      || echo "ERRO: eai"
proserve $DB_DIR/ems2adt  -B 100   -L 2000   -Mm 4096 -N tcp -S 25600 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2adt (25600)"  || echo "ERRO: ems2adt"
proserve $DB_DIR/ems2cad  -B 50000 -L 200000 -Mm 4096 -N tcp -S 25601 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2cad (25601)"  || echo "ERRO: ems2cad"
proserve $DB_DIR/ems2mov  -B 50000 -L 300000 -Mm 4096 -N tcp -S 25602 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mov (25602)"  || echo "ERRO: ems2mov"
proserve $DB_DIR/ems2mp   -B 100   -L 100    -Mm 4096 -N tcp -S 25603 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mp (25603)"   || echo "ERRO: ems2mp"
proserve $DB_DIR/ems5cad  -B 50000 -L 200000 -Mm 4096 -N tcp -S 25606 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5cad (25606)"  || echo "ERRO: ems5cad"
proserve $DB_DIR/ems5mov  -B 50000 -L 300000 -Mm 4096 -N tcp -S 25607 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5mov (25607)"  || echo "ERRO: ems5mov"
proserve $DB_DIR/emsdes   -B 50000 -L 300000 -Mm 4096 -N tcp -S 25635 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsdes (25635)"   || echo "ERRO: emsdes"
proserve $DB_DIR/hcm      -B 40000 -L 600000 -Mm 4096 -N tcp -S 25608 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: hcm (25608)"      || echo "ERRO: hcm"
proserve $DB_DIR/emsinc   -B 100   -L 1000   -Mm 4096 -N tcp -S 25009 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsinc (25009)"   || echo "ERRO: emsinc"
echo "=== FIM: $(date) ==="
