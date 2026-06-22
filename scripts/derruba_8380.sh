#!/bin/bash
# Script de derrubar bancos Progress 8380 — requer senha de confirmação
export DLC=/usr/dlc128; export PATH=$DLC/bin:$PATH
DB_DIR=/bancos/DATABASE-JA-8380

# Senha de confirmação para derrubar bancos (hash scrypt)
# Senha: derrubadb8380
SENHA_HASH="scrypt:32768:8:1\$BANCO8380\$a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"

if [ -z "$1" ]; then
    echo "ERRO: senha obrigatória como argumento"
    echo "Uso: $(basename $0) <senha>"
    exit 1
fi

# Validação simples: comparar com a senha em texto plano (usar em produção com hash)
if [ "$1" != "derrubadb8380" ]; then
    echo "ERRO: senha incorreta"
    exit 1
fi

echo "=== DERRUBA 8380: $(date) ==="
for banco in emsfnd dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes hcm emsinc; do
    [ ! -f "$DB_DIR/${banco}.db" ] && continue
    proshut "$DB_DIR/$banco" -by 2>/dev/null && echo "PARADO: $banco" || echo "AVISO: $banco nao estava ativo"
done
echo "=== FIM: $(date) ==="
