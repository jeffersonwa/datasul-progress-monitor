#!/bin/bash
# ----------------------------------------------------------------------------
# Script de Instalação Completa - Painel de Monitoramento Progress & Datasul
# ----------------------------------------------------------------------------
# Este script deve ser executado como root (ou via sudo) no servidor Ubuntu.
# Ele cria as pastas, configura a venv do Python, instala dependências,
# implanta os scripts e configura o Sudoers e o Systemd.

set -e

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Iniciando Instalação do Painel de Monitoramento ===${NC}"

# 1. Verificar se é root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Erro: Este script deve ser executado como root ou utilizando sudo.${NC}"
  exit 1
fi

# Obter o diretório atual do código-fonte (raiz do repositório clonado)
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/opt/dashboard"

echo -e "${BLUE}1. Criando diretórios em ${TARGET_DIR}...${NC}"
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/static"

# 2. Instalar pacotes de sistema
echo -e "${BLUE}2. Instalando pacotes de sistema necessários (APT)...${NC}"
apt-get update -y
apt-get install -y python3 python3-pip python3-venv python3-dev build-essential iproute2

# 3. Copiar os arquivos da aplicação (a partir da pasta app/)
echo -e "${BLUE}3. Copiando arquivos da aplicação...${NC}"
if [ -d "$SRC_DIR/app" ]; then
  cp "$SRC_DIR/app/app.py" "$TARGET_DIR/app.py"
  cp -r "$SRC_DIR/app/static/"* "$TARGET_DIR/static/"
else
  # Fallback caso os arquivos estejam na raiz
  cp "$SRC_DIR/app.py" "$TARGET_DIR/app.py"
  cp -r "$SRC_DIR/static/"* "$TARGET_DIR/static/"
fi

# Copiar scripts bash do painel (a partir da pasta scripts/)
echo -e "${BLUE}4. Copiando scripts de gerenciamento e concedendo permissões...${NC}"
SCRIPTS_SRC_DIR="$SRC_DIR/scripts"
if [ ! -d "$SCRIPTS_SRC_DIR" ]; then
  SCRIPTS_SRC_DIR="$SRC_DIR"
fi

for script in atualiza_8480.sh atualiza_8580.sh carga_8380.sh carga_8480.sh carga_8580.sh db_io.sh db_io_8480.sh db_io_8580.sh derruba_8380.sh derruba_8480.sh derruba_8580.sh executa_bkp.sh executa_bkp_8480.sh executa_bkp_8580.sh kick_user.sh kick_user_8480.sh kick_user_8580.sh list_users.sh list_users_8480.sh list_users_8580.sh; do
  if [ -f "$SCRIPTS_SRC_DIR/$script" ]; then
    cp "$SCRIPTS_SRC_DIR/$script" "$TARGET_DIR/$script"
    chmod +x "$TARGET_DIR/$script"
  else
    echo -e "${RED}Aviso: Script $script não encontrado em $SCRIPTS_SRC_DIR!${NC}"
  fi
done

# Garantir que o usuário 'ti' existe
if ! id "ti" &>/dev/null; then
  echo -e "${BLUE}Usuário 'ti' não encontrado. Criando usuário 'ti'...${NC}"
  useradd -m -s /bin/bash ti
fi

# Dar permissão de propriedade dos arquivos ao usuário ti
chown -R ti:ti "$TARGET_DIR"

# 5. Criar ambiente virtual do Python e instalar pacotes
echo -e "${BLUE}5. Configurando ambiente virtual Python (Venv)...${NC}"
python3 -m venv "$TARGET_DIR/venv"
chown -R ti:ti "$TARGET_DIR/venv"

echo -e "${BLUE}6. Instalando dependências do Python...${NC}"
# Executar a instalação de dependências como usuário ti dentro da venv
sudo -u ti "$TARGET_DIR/venv/bin/pip" install --upgrade pip
sudo -u ti "$TARGET_DIR/venv/bin/pip" install Flask flask-cors psutil werkzeug

# 6. Configurar o Sudoers
echo -e "${BLUE}7. Configurando arquivo do Sudoers (/etc/sudoers.d/dashboard)...${NC}"
cat << 'EOF' > /etc/sudoers.d/dashboard
# Permitir que o usuario ti execute os scripts do painel como root sem senha
ti ALL=(ALL) NOPASSWD: /opt/dashboard/list_users.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/list_users_8480.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/list_users_8580.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/kick_user.sh *
ti ALL=(ALL) NOPASSWD: /opt/dashboard/kick_user_8480.sh *
ti ALL=(ALL) NOPASSWD: /opt/dashboard/kick_user_8580.sh *
ti ALL=(ALL) NOPASSWD: /opt/dashboard/db_io.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/db_io_8480.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/db_io_8580.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/carga_8380.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/carga_8480.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/carga_8580.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/derruba_8380.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/derruba_8480.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/derruba_8580.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/executa_bkp.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/executa_bkp_8480.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/executa_bkp_8580.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/atualiza_8480.sh
ti ALL=(ALL) NOPASSWD: /opt/dashboard/atualiza_8580.sh
EOF

chmod 0440 /etc/sudoers.d/dashboard

# 7. Configurar o Serviço Systemd
echo -e "${BLUE}8. Configurando o Serviço Systemd (dashboard.service)...${NC}"
if [ -d "$SRC_DIR/systemd" ] && [ -f "$SRC_DIR/systemd/dashboard.service" ]; then
  cp "$SRC_DIR/systemd/dashboard.service" /etc/systemd/system/dashboard.service
else
  cat << 'EOF' > /etc/systemd/system/dashboard.service
[Unit]
Description=Monitor Datasul Progress Dashboard
After=network.target

[Service]
Type=simple
User=ti
WorkingDirectory=/opt/dashboard
ExecStart=/opt/dashboard/venv/bin/python3 /opt/dashboard/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

# Recarregar daemon e habilitar/iniciar serviço
echo -e "${BLUE}9. Habilitando e iniciando o serviço...${NC}"
systemctl daemon-reload
systemctl enable dashboard.service
systemctl restart dashboard.service

echo -e "${GREEN}=== Instalação Concluída com Sucesso! ===${NC}"
echo -e "O painel de controle está sendo executado sob o serviço systemd: ${BLUE}dashboard.service${NC}"
echo -e "Você pode acessar o painel via navegador na porta: ${GREEN}http://<IP_DO_SERVIDOR>:3000${NC}"
echo -e "Credenciais padrões de acesso:"
echo -e " - Usuário: ${GREEN}admin${NC}"
echo -e " - Senha:   ${GREEN}admin123${NC}"
