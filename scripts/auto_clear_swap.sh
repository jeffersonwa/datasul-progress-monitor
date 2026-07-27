#!/bin/bash
# Script para verificar e limpar automaticamente o SWAP se exceder um limite.
# Criado para rodar via cron (ex: de hora em hora).

THRESHOLD=80
LOG_FILE="/var/log/auto_clear_swap.log"

_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Obtem valores de memoria em MB
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')
RAM_AVAIL=$(free -m | awk '/^Mem:/{print $7}')

if [ -z "$SWAP_TOTAL" ] || [ "$SWAP_TOTAL" -eq 0 ]; then
    exit 0
fi

SWAP_PCT=$(( 100 * SWAP_USED / SWAP_TOTAL ))

if [ "$SWAP_PCT" -ge "$THRESHOLD" ]; then
    # Necessario ter o tamanho do swap usado + 20% de margem livre na RAM
    NEEDED=$(( SWAP_USED + (SWAP_USED * 20 / 100) ))
    
    if [ "$RAM_AVAIL" -gt "$NEEDED" ]; then
        _log "ALERTA: Swap em ${SWAP_PCT}% (${SWAP_USED}MB). RAM disponivel: ${RAM_AVAIL}MB. Iniciando limpeza segura..."
        
        # Limpa o swap
        swapoff -a && swapon -a
        
        if [ $? -eq 0 ]; then
            _log "SUCESSO: Swap limpo corretamente."
        else
            _log "ERRO: Falha ao limpar o swap."
        fi
    else
        _log "AVISO: Swap em ${SWAP_PCT}% mas sem RAM segura suficiente (Disp: ${RAM_AVAIL}MB, Nec: ${NEEDED}MB). Abortando limpeza para evitar OOM."
    fi
# else
#   _log "INFO: Swap saudavel em ${SWAP_PCT}% (abaixo de ${THRESHOLD}%)."
fi
