#!/bin/bash
# =============================================================================
# install.sh — Instalação completa do Monitor Datasul Progress Dashboard
# Servidor: Ubuntu 24.04 LTS | Progress OpenEdge 12.8
# Uso: sudo bash install.sh
# =============================================================================
set -euo pipefail

# ── cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${BLUE}[..] $*${NC}"; }
warn() { echo -e "${YELLOW}[AV] $*${NC}"; }
fail() { echo -e "${RED}[ERRO] $*${NC}"; exit 1; }

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════╗"
echo    "║   Monitor Datasul Progress Dashboard — Instalação   ║"
echo -e "╚══════════════════════════════════════════════════════╝${NC}\n"

# ── verificações iniciais ────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && fail "Execute como root: sudo bash install.sh"
[[ ! -f /usr/dlc128/bin/_mprshut ]] && warn "Progress OpenEdge não encontrado em /usr/dlc128"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/dashboard"
SERVICE_USER="ti"
PORT=3000

id "$SERVICE_USER" &>/dev/null || fail "Usuário '$SERVICE_USER' não existe. Crie-o antes de instalar."

# =============================================================================
# 1. DEPENDÊNCIAS DO SISTEMA
# =============================================================================
info "Instalando dependências do sistema..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip sqlite3 curl iproute2
ok "Dependências do sistema instaladas"

# =============================================================================
# 2. DEPENDÊNCIAS PYTHON
# =============================================================================
info "Instalando dependências Python..."
pip3 install -q flask flask-cors werkzeug psutil
ok "Flask, psutil e dependências instalados"

# =============================================================================
# 3. DIRETÓRIO DE INSTALAÇÃO
# =============================================================================
info "Criando $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/static"
ok "Diretório criado"

# =============================================================================
# 4. CÓPIA DOS ARQUIVOS
# =============================================================================
info "Copiando aplicação (app/)..."
cp "$REPO_DIR/app/app.py"              "$INSTALL_DIR/app.py"
cp "$REPO_DIR/app/static/index.html"   "$INSTALL_DIR/static/index.html"
cp "$REPO_DIR/app/static/login.html"   "$INSTALL_DIR/static/login.html"
ok "app.py e static/ copiados"

info "Copiando scripts auxiliares (scripts/)..."
for script in "$REPO_DIR/scripts/"*.sh; do
    [[ -f "$script" ]] || continue
    cp "$script" "$INSTALL_DIR/$(basename "$script")"
    ok "  $(basename "$script")"
done

# =============================================================================
# 5. PERMISSÕES
# =============================================================================
info "Ajustando permissões..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
for script in "$INSTALL_DIR"/*.sh; do
    chmod 755 "$script"
    chown root:root "$script"
done
# list_users.sh pode ser chamado pelo usuário de serviço diretamente
chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/list_users.sh" 2>/dev/null || true
ok "Permissões ajustadas"

# =============================================================================
# 6. BANCO DE DADOS SQLite (usuários do monitor)
# =============================================================================
DB_PATH="$INSTALL_DIR/users.db"
if [[ ! -f "$DB_PATH" ]]; then
    info "Criando banco de dados de usuários..."
    sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE IF NOT EXISTS usuarios (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    login     TEXT    NOT NULL UNIQUE,
    senha     TEXT    NOT NULL,
    nome      TEXT    NOT NULL DEFAULT '',
    perfil    TEXT    NOT NULL DEFAULT 'viewer'
                     CHECK(perfil IN ('admin','viewer')),
    ativo     INTEGER NOT NULL DEFAULT 1,
    criado_em TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);
SQL
    chown "$SERVICE_USER:$SERVICE_USER" "$DB_PATH"
    ok "Banco criado em $DB_PATH"
else
    ok "Banco de dados já existe — dados mantidos"
fi

# =============================================================================
# 7. SUDOERS
# =============================================================================
info "Configurando sudoers..."
cat > /etc/sudoers.d/dashboard <<EOF
# Monitor Datasul Progress Dashboard — gerado por install.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/list_users.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/list_users_8480.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/list_users_8580.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/kick_user.sh *
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/kick_user_8480.sh *
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/kick_user_8580.sh *
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/carga_8380.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/carga_8480.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/carga_8580.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/derruba_8380.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/derruba_8480.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/derruba_8580.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/db_io.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/db_io_8480.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/db_io_8580.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/executa_bkp.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/executa_bkp_8480.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/executa_bkp_8580.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/atualiza_8480.sh
$SERVICE_USER ALL=(root) NOPASSWD: $INSTALL_DIR/atualiza_8580.sh
EOF
chmod 440 /etc/sudoers.d/dashboard
visudo -c -f /etc/sudoers.d/dashboard &>/dev/null && ok "sudoers configurado" || fail "sudoers com erro de sintaxe"

# =============================================================================
# 8. SERVIÇO SYSTEMD
# =============================================================================
info "Instalando serviço systemd..."
cp "$REPO_DIR/systemd/dashboard.service" /etc/systemd/system/dashboard.service
systemctl daemon-reload
systemctl enable dashboard
systemctl restart dashboard
sleep 3
systemctl is-active --quiet dashboard && ok "Serviço dashboard ativo" \
    || fail "Serviço não iniciou — verifique: journalctl -u dashboard -n 30"

# =============================================================================
# 9. RESULTADO
# =============================================================================
SERVER_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$PORT/login" 2>/dev/null || echo "000")
[[ "$HTTP_CODE" == "200" ]] && ok "HTTP respondendo na porta $PORT" \
    || warn "HTTP retornou $HTTP_CODE — aguarde e teste: curl http://localhost:$PORT/login"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗"
echo    "║               INSTALAÇÃO CONCLUÍDA                  ║"
echo    "╠══════════════════════════════════════════════════════╣"
printf  "║  URL:     http://%-35s║\n" "${SERVER_IP}:${PORT}"
printf  "║  Serviço: systemctl status dashboard%-16s║\n" ""
printf  "║  Logs:    journalctl -u dashboard -f%-16s║\n" ""
echo -e "╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}Acesse o painel e crie o primeiro usuário admin.${NC}"
echo ""
