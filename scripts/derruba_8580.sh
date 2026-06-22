#!/bin/bash
# Script de derrubar bancos Progress 8580 — requer senha de confirmação
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8580

if [ -z "$1" ]; then
    echo "ERRO: senha obrigatória como argumento"
    echo "Uso: $(basename $0) <senha>"
    exit 1
fi

if [ "$1" != "derrubadb8580" ]; then
    echo "ERRO: senha incorreta"
    exit 1
fi

echo "=== DERRUBA 8580: $(date) ==="
for banco in emsfnd dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes hcm emsinc; do
    [ ! -f "$DB_DIR/${banco}.db" ] && continue
    proshut "$DB_DIR/$banco" -by 2>/dev/null && echo "PARADO: $banco" || echo "AVISO: $banco nao estava ativo"
done
echo "=== FIM: $(date) ==="
