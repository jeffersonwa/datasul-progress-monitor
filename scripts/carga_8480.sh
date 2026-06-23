#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8480
echo "=== CARGA 8480: $(date) ==="
proserve $DB_DIR/emsfnd   -B 50000  -L 200000 -Mm 4096 -N tcp -S 24619 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsfnd (24619)"   || echo "ERRO: emsfnd"
proserve $DB_DIR/dtviewer -B 100    -L 2000   -Mm 4096 -N tcp -S 24650 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: dtviewer (24650)" || echo "ERRO: dtviewer"
proserve $DB_DIR/eai      -B 100    -L 1000   -Mm 4096 -N tcp -S 24621 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: eai (24621)"      || echo "ERRO: eai"
proserve $DB_DIR/ems2adt  -B 100    -L 2000   -Mm 4096 -N tcp -S 24600 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2adt (24600)"  || echo "ERRO: ems2adt"
proserve $DB_DIR/ems2cad  -B 100000 -L 200000 -Mm 4096 -N tcp -S 24601 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2cad (24601)"  || echo "ERRO: ems2cad"
proserve $DB_DIR/ems2mov  -B 100000 -L 300000 -Mm 4096 -N tcp -S 24602 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mov (24602)"  || echo "ERRO: ems2mov"
proserve $DB_DIR/ems2mp   -B 100    -L 100    -Mm 4096 -N tcp -S 24603 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems2mp (24603)"   || echo "ERRO: ems2mp"
proserve $DB_DIR/ems5cad  -B 100000 -L 200000 -Mm 4096 -N tcp -S 24606 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5cad (24606)"  || echo "ERRO: ems5cad"
proserve $DB_DIR/ems5mov  -B 100000 -L 300000 -Mm 4096 -N tcp -S 24607 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: ems5mov (24607)"  || echo "ERRO: ems5mov"
proserve $DB_DIR/emsdes   -B 100000 -L 300000 -Mm 4096 -N tcp -S 24635 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsdes (24635)"   || echo "ERRO: emsdes"
proserve $DB_DIR/hcm      -B 20000  -L 600000 -Mm 4096 -N tcp -S 24608 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: hcm (24608)"      || echo "ERRO: hcm"
proserve $DB_DIR/emsinc   -B 1000   -L 1000   -Mm 4096 -N tcp -S 24009 -n 106 -Ma 12 -Mn 10 -usernotifytime 0 -dbnotifytime 0 && echo "UP: emsinc (24009)"   || echo "ERRO: emsinc"
echo "=== FIM: $(date) ==="
