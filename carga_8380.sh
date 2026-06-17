#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8380
echo "=== CARGA 8380: $(date) ==="
proserve $DB_DIR/emsfnd   -B 25000 -L 200000 -Mm 4096 -N tcp -S 23619 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsfnd (23619)"   || echo "ERRO: emsfnd"
proserve $DB_DIR/dtviewer -B 1000  -L 2000   -Mm 4096 -N tcp -S 23650 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: dtviewer (23650)" || echo "ERRO: dtviewer"
proserve $DB_DIR/eai      -B 100   -L 1000   -Mm 4096 -N tcp -S 23621 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: eai (23621)"      || echo "ERRO: eai"
proserve $DB_DIR/ems2adt  -B 100   -L 2000   -Mm 4096 -N tcp -S 23600 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2adt (23600)"  || echo "ERRO: ems2adt"
proserve $DB_DIR/ems2cad  -B 50000 -L 200000 -Mm 4096 -N tcp -S 23601 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2cad (23601)"  || echo "ERRO: ems2cad"
proserve $DB_DIR/ems2mov  -B 50000 -L 300000 -Mm 4096 -N tcp -S 23602 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mov (23602)"  || echo "ERRO: ems2mov"
proserve $DB_DIR/ems2mp   -B 100   -L 100    -Mm 4096 -N tcp -S 23603 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mp (23603)"   || echo "ERRO: ems2mp"
proserve $DB_DIR/ems5cad  -B 50000 -L 200000 -Mm 4096 -N tcp -S 23606 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5cad (23606)"  || echo "ERRO: ems5cad"
proserve $DB_DIR/ems5mov  -B 50000 -L 300000 -Mm 4096 -N tcp -S 23607 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5mov (23607)"  || echo "ERRO: ems5mov"
proserve $DB_DIR/emsdes   -B 50000 -L 300000 -Mm 4096 -N tcp -S 23635 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsdes (23635)"   || echo "ERRO: emsdes"
proserve $DB_DIR/hcm      -B 40000 -L 600000 -Mm 4096 -N tcp -S 23608 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: hcm (23608)"      || echo "ERRO: hcm"
proserve $DB_DIR/emsinc   -B 100   -L 1000   -Mm 4096 -N tcp -S 23009 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsinc (23009)"   || echo "ERRO: emsinc"
echo "=== FIM: $(date) ==="
