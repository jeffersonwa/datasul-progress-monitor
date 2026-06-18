#!/bin/bash
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8380
echo "=== DERRUBA 8380: $(date) ==="
for banco in emsfnd dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes hcm emsinc; do
    [ ! -f "$DB_DIR/${banco}.db" ] && continue
    proshut "$DB_DIR/$banco" -by 2>/dev/null && echo "PARADO: $banco" || echo "AVISO: $banco nao estava ativo"
done
echo "=== FIM: $(date) ==="
