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
[[ ! -f /usr/dlc128/bin/_mprshut ]] && warn "Progress OpenEdge não encontrado em /usr/dlc128 — scripts de banco não funcionarão"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/dashboard"
SERVICE_USER="ti"
PORT=3000

# ── variável: usuário de serviço ─────────────────────────────────────────────
if ! id "$SERVICE_USER" &>/dev/null; then
    fail "Usuário '$SERVICE_USER' não existe. Crie-o antes de instalar."
fi

# =============================================================================
# 1. DEPENDÊNCIAS DO SISTEMA
# =============================================================================
info "Instalando dependências do sistema..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv sqlite3 curl net-tools iproute2
ok "Dependências do sistema instaladas"

# =============================================================================
# 2. DEPENDÊNCIAS PYTHON
# =============================================================================
info "Instalando dependências Python..."
pip3 install -q flask flask-cors werkzeug psutil 2>&1 | tail -3
ok "Dependências Python instaladas"

# =============================================================================
# 3. DIRETÓRIO DE INSTALAÇÃO
# =============================================================================
info "Criando diretório $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/static"
ok "Diretório criado"

# =============================================================================
# 4. CÓPIA DOS ARQUIVOS
# =============================================================================
info "Copiando arquivos do monitor..."

# Copiar apenas se o arquivo existir na origem
copy_if_exists() {
    local src="$SCRIPT_DIR/$1"
    local dst="$INSTALL_DIR/$1"
    if [[ -f "$src" ]]; then
        cp "$src" "$dst"
        ok "  $1"
    else
        warn "  $1 não encontrado em $SCRIPT_DIR — pulando"
    fi
}

# Aplicação principal
copy_if_exists app.py
copy_if_exists static/index.html
copy_if_exists static/login.html

# Scripts auxiliares (chamados pelo monitor via sudo)
for script in \
    list_users.sh list_users_8480.sh list_users_8580.sh \
    kick_user.sh kick_user_8480.sh kick_user_8580.sh \
    carga_8380.sh carga_8480.sh carga_8580.sh \
    derruba_8380.sh derruba_8480.sh derruba_8580.sh \
    db_io.sh db_io_8480.sh db_io_8580.sh \
    executa_bkp.sh executa_bkp_8480.sh executa_bkp_8580.sh \
    atualiza_8480.sh atualiza_8580.sh; do
    copy_if_exists "$script"
done

# =============================================================================
# 5. PERMISSÕES
# =============================================================================
info "Ajustando permissões..."

# app.py e static: leitura pelo usuário de serviço
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

# Scripts auxiliares precisam ser executáveis e pertencer a root
# (sudo os executa como root)
for script in "$INSTALL_DIR"/*.sh; do
    [[ -f "$script" ]] || continue
    chmod 755 "$script"
    chown root:root "$script"
done

# list_users.sh é executado pelo usuário de serviço diretamente em alguns contextos
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
    echo ""
    echo -e "  ${YELLOW}IMPORTANTE: nenhum usuário criado ainda.${NC}"
    echo    "  Acesse http://IP:$PORT/login e use o endpoint POST /api/register"
    echo    "  ou insira diretamente via: python3 /opt/dashboard/adduser.py"
    echo ""
else
    ok "Banco de dados já existe — mantendo dados atuais"
fi

# =============================================================================
# 7. SUDOERS
# =============================================================================
SUDOERS_FILE="/etc/sudoers.d/dashboard"
info "Configurando sudoers ($SUDOERS_FILE)..."

cat > "$SUDOERS_FILE" <<EOF
# Monitor Datasul Progress Dashboard
# Scripts executados pelo Flask como root (sem senha)
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

chmod 440 "$SUDOERS_FILE"
visudo -c -f "$SUDOERS_FILE" &>/dev/null && ok "sudoers OK" || fail "sudoers com erro de sintaxe"

# =============================================================================
# 8. SERVIÇO SYSTEMD
# =============================================================================
info "Instalando serviço systemd..."

cat > /etc/systemd/system/dashboard.service <<EOF
[Unit]
Description=Monitor Datasul Progress Dashboard
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dashboard
systemctl restart dashboard
sleep 3

if systemctl is-active --quiet dashboard; then
    ok "Serviço dashboard ativo"
else
    fail "Serviço não iniciou — verifique: journalctl -u dashboard -n 30"
fi

# =============================================================================
# 9. VERIFICAÇÃO FINAL
# =============================================================================
echo ""
echo -e "${BOLD}── Verificação ──────────────────────────────────────────${NC}"

# testar HTTP
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$PORT/login" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
    ok "HTTP respondendo na porta $PORT"
else
    warn "HTTP retornou $HTTP_CODE — aguarde alguns segundos e teste: curl http://localhost:$PORT/login"
fi

# mostrar IP para acesso externo
SERVER_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗"
echo    "║               INSTALAÇÃO CONCLUÍDA                  ║"
echo    "╠══════════════════════════════════════════════════════╣"
printf  "║  URL:     http://%-35s║\n" "${SERVER_IP}:${PORT}"
printf  "║  Serviço: systemctl status dashboard%-16s║\n" ""
printf  "║  Logs:    journalctl -u dashboard -f%-16s║\n" ""
echo -e "╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}Próximo passo: acesse o painel e crie o primeiro usuário admin.${NC}"
echo    "  Documentação: $INSTALL_DIR/README.md"
echo ""
