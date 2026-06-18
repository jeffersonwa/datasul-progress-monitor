# Monitor Datasul Progress

Painel de monitoramento em tempo real para servidores Progress OpenEdge / Datasul TOTVS.

![Python](https://img.shields.io/badge/Python-3.8+-blue) ![Flask](https://img.shields.io/badge/Flask-3.x-green) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Visão geral

Dashboard web com autenticação que monitora **três ambientes Progress OpenEdge** (Produção, TST e HML) a partir de um único servidor Linux. Os dados são atualizados a cada 5 segundos sem necessidade de recarregar a página.

**Funcionalidades:**

- CPU, memória, swap e disco em tempo real
- Processos `proserve` ativos por ambiente (PID, CPU%, MEM%)
- Usuários conectados por banco — tipo REMC/ABL (cliente direto) e REMC/PASN (PASOE)
- Conexões TCP ativas por banco e por ambiente
- Gráficos históricos de CPU e RAM (últimos 30 pontos)
- Execução de backup online (`probkup`) por ambiente via interface web
- Kick de usuário conectado diretamente pela tela
- Controle de acesso com roles: `admin` e `viewer`
- Interface dark mode responsiva

---

## Arquitetura

```
Navegador (browser)
      │  HTTP :3000
      ▼
db-progress001 (192.168.7.9 — Ubuntu 24.04)
  /opt/dashboard/
  ├── app.py              ← Backend Flask (API REST + servir HTML)
  ├── users.db            ← Usuários e senhas (SQLite)
  ├── dashboard.service   ← Serviço systemd
  ├── static/
  │   └── index.html      ← Frontend (Chart.js, puro HTML/JS)
  └── scripts/
      ├── executa_bkp.sh       ← Backup Produção  (pp/logs)
      ├── executa_bkp_8480.sh  ← Backup TST       (pp/8480/logs)
      ├── executa_bkp_8580.sh  ← Backup HML       (pp/8580/logs)
      ├── carga_8380.sh        ← Sobe bancos Produção
      ├── carga_8480.sh        ← Sobe bancos TST
      ├── carga_8580.sh        ← Sobe bancos HML
      ├── derruba_8380.sh / derruba_8480.sh / derruba_8580.sh
      ├── list_users.sh / list_users_8480.sh / list_users_8580.sh
      ├── kick_user.sh / kick_user_8480.sh / kick_user_8580.sh
      └── db_io_8480.sh / db_io_8580.sh
```

**PASOE/Tomcat rodando em SRV-DTSAPP001 (192.168.7.10 — Windows)**

| Ambiente | Serviço Windows | Porta HTTP | AppServer | Bancos Progress |
|----------|-----------------|------------|-----------|-----------------|
| Produção | TOTVS12-8380 | 8380 | :9301/apsv | 23xxx |
| TST | TOTVS12-8480 | 8480 | :9401/apsv | 24xxx |
| HML | TOTVS12-8580 | 8580 | :9501/apsv | 25xxx |

---

## Pré-requisitos

| Requisito | Versão mínima |
|-----------|---------------|
| Ubuntu / Debian | 20.04+ |
| Python | 3.8+ |
| Progress OpenEdge (`proserve`, `_mprshut`, `probkup`) | 12.x |
| Usuário Linux com sudo | `ti` (ou outro — ver seção 4) |
| Systemd | qualquer versão moderna |

```bash
python3 --version
which proserve _mprshut probkup
```

---

## Instalação passo a passo

### 1. Clonar o repositório

```bash
cd /opt
sudo git clone https://github.com/jeffersonwa/datasul-progress-monitor.git dashboard
sudo chown -R $USER:$USER /opt/dashboard
cd /opt/dashboard
```

### 2. Instalar dependências Python

**Opção A — via apt (recomendado para servidores Ubuntu)**

```bash
sudo apt update
sudo apt install -y python3-flask python3-psutil
```

Verificar:

```bash
python3 -c "import flask, psutil; print('OK')"
```

**Opção B — via pip (virtualenv)**

```bash
python3 -m venv venv
source venv/bin/activate
pip install flask flask-cors psutil werkzeug
```

> Se usar virtualenv, edite `dashboard.service` e altere:
> ```
> ExecStart=/opt/dashboard/venv/bin/python3 /opt/dashboard/app.py
> ```

### 3. Criar o banco de usuários e o primeiro admin

```bash
cd /opt/dashboard
python3 - <<'EOF'
import sqlite3
from werkzeug.security import generate_password_hash

conn = sqlite3.connect('users.db')
conn.execute('''CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'viewer'
)''')
conn.execute("INSERT OR IGNORE INTO users (username, password, role) VALUES (?, ?, ?)",
    ('admin', generate_password_hash('TROQUE-ESTA-SENHA'), 'admin'))
conn.commit()
conn.close()
print("users.db criado com sucesso")
EOF
```

> Troque `TROQUE-ESTA-SENHA` pela senha desejada antes de executar.

### 4. Configurar permissões sudo para os scripts

Os scripts de backup e controle de bancos precisam rodar como root sem senha interativa.
Crie os arquivos de sudoers (substitua `ti` pelo usuário do serviço, se diferente):

```bash
# Backup
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/executa_bkp.sh"      | sudo tee /etc/sudoers.d/dashboard-bkp
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/executa_bkp_8480.sh" | sudo tee /etc/sudoers.d/dashboard-bkp-8480
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/executa_bkp_8580.sh" | sudo tee /etc/sudoers.d/dashboard-bkp-8580

# Carga e derrubada de bancos
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/carga_8380.sh"    | sudo tee /etc/sudoers.d/dashboard-carga-8380
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/carga_8480.sh"    | sudo tee /etc/sudoers.d/dashboard-carga-8480
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/carga_8580.sh"    | sudo tee /etc/sudoers.d/dashboard-carga-8580
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/derruba_8380.sh"  | sudo tee /etc/sudoers.d/dashboard-derruba-8380
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/derruba_8480.sh"  | sudo tee /etc/sudoers.d/dashboard-derruba-8480
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/derruba_8580.sh"  | sudo tee /etc/sudoers.d/dashboard-derruba-8580

# Kick de usuário
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/kick_user.sh"      | sudo tee /etc/sudoers.d/dashboard-kick
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/kick_user_8480.sh" | sudo tee /etc/sudoers.d/dashboard-kick-8480
echo "ti ALL=(root) NOPASSWD: /opt/dashboard/kick_user_8580.sh" | sudo tee /etc/sudoers.d/dashboard-kick-8580

sudo chmod 440 /etc/sudoers.d/dashboard-*
```

Verificar sintaxe:

```bash
sudo visudo -c
```

### 5. Tornar os scripts executáveis

```bash
chmod +x /opt/dashboard/*.sh
```

### 6. Configurar os caminhos dos bancos e diretórios de backup

Edite `app.py` e ajuste as constantes do início do arquivo conforme o ambiente:

```python
# ── diretórios de banco ──────────────────────────────────────────────────────
DB_DIR_8380 = '/bancos/DATABASE-JA'        # Produção
DB_DIR_8480 = '/bancos/DATABASE-JA-8480'   # TST
DB_DIR_8580 = '/bancos/DATABASE-JA-8580'   # HML

# ── diretórios de log de backup ──────────────────────────────────────────────
BKP_LOG_DIR      = '/mnt/backup-progress/Backup-Progress/pp/logs'       # Produção
BKP_LOG_DIR_8480 = '/mnt/backup-progress/Backup-Progress/pp/8480/logs'  # TST
BKP_LOG_DIR_8580 = '/mnt/backup-progress/Backup-Progress/pp/8580/logs'  # HML

# ── portas Progress por ambiente ─────────────────────────────────────────────
PROGRESS_PORTS = {          # Produção — 23xxx
    'dtviewer': 23650, 'eai': 23621, 'ems2adt': 23600, 'ems2cad': 23601,
    'ems2mov': 23602, 'ems2mp': 23603, 'ems5cad': 23606, 'ems5mov': 23607,
    'emsdes': 23635, 'emsfnd': 23619, 'emsinc': 23009, 'hcm': 23608
}
PROGRESS_PORTS_8480 = {     # TST — 24xxx
    'dtviewer': 24650, 'eai': 24621, 'ems2adt': 24600, ...
}
PROGRESS_PORTS_8580 = {     # HML — 25xxx
    'dtviewer': 25650, 'eai': 25621, 'ems2adt': 25600, ...
}
```

### 7. Testar manualmente antes de instalar o serviço

```bash
cd /opt/dashboard
python3 app.py
```

Abra em outro terminal:

```bash
curl -s http://localhost:3000/api/metrics | python3 -m json.tool | head -30
```

Pressione `Ctrl+C` para parar.

### 8. Instalar como serviço systemd

```bash
# Copiar o arquivo de serviço
sudo cp /opt/dashboard/dashboard.service /etc/systemd/system/

# Recarregar o systemd
sudo systemctl daemon-reload

# Habilitar inicialização automática no boot
sudo systemctl enable dashboard

# Iniciar agora
sudo systemctl start dashboard

# Verificar status
sudo systemctl status dashboard
```

Saída esperada:

```
● dashboard.service - Monitor Datasul Progress Dashboard
     Active: active (running) since ...
   Main PID: XXXX (python3)
```

### 9. Abrir porta no firewall

**UFW (Ubuntu padrão):**

```bash
sudo ufw allow 3000/tcp comment "Dashboard Progress"
sudo ufw reload
sudo ufw status
```

**iptables:**

```bash
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### 10. Acessar o painel

De qualquer máquina na rede interna:

```
http://IP-DO-SERVIDOR:3000
```

Login inicial: `admin` / senha definida no passo 3.

---

## Configuração de ambiente — resumo das variáveis

| Constante | Produção (8380) | TST (8480) | HML (8580) |
|-----------|-----------------|------------|------------|
| `DB_DIR_*` | `/bancos/DATABASE-JA` | `/bancos/DATABASE-JA-8480` | `/bancos/DATABASE-JA-8580` |
| `BKP_LOG_DIR_*` | `pp/logs` | `pp/8480/logs` | `pp/8580/logs` |
| Portas bancos | 23xxx | 24xxx | 25xxx |
| Script backup | `executa_bkp.sh` | `executa_bkp_8480.sh` | `executa_bkp_8580.sh` |
| Script carga | `carga_8380.sh` | `carga_8480.sh` | `carga_8580.sh` |
| Script derruba | `derruba_8380.sh` | `derruba_8480.sh` | `derruba_8580.sh` |

---

## Mapeamento de portas Progress por banco

| Banco | Produção | TST | HML |
|-------|----------|-----|-----|
| dtviewer | 23650 | 24650 | 25650 |
| eai | 23621 | 24621 | 25621 |
| ems2adt | 23600 | 24600 | 25600 |
| ems2cad | 23601 | 24601 | 25601 |
| ems2mov | 23602 | 24602 | 25602 |
| ems2mp | 23603 | 24603 | 25603 |
| ems5cad | 23606 | 24606 | 25606 |
| ems5mov | 23607 | 24607 | 25607 |
| emsdes | 23635 | 24635 | 25635 |
| emsfnd | 23619 | 24619 | 25619 |
| emsinc | 23009 | 24009 | 25009 |
| hcm | 23608 | 24608 | 25608 |

---

## Gerenciamento de usuários

### Adicionar usuário via API (requer admin logado)

```bash
curl -X POST http://localhost:3000/api/admin/users \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"username":"joao","password":"senha123","role":"viewer"}'
```

### Roles disponíveis

| Role | Permissões |
|------|------------|
| `admin` | Tudo — backup, kick, carga/derrubada, gerenciar usuários |
| `viewer` | Somente leitura — visualizar métricas e usuários conectados |

### Resetar senha diretamente no banco

```bash
python3 - <<'EOF'
import sqlite3
from werkzeug.security import generate_password_hash
conn = sqlite3.connect('/opt/dashboard/users.db')
conn.execute("UPDATE users SET password=? WHERE username=?",
    (generate_password_hash('nova-senha'), 'admin'))
conn.commit()
conn.close()
print("Senha atualizada")
EOF
```

---

## Ajustes de kernel recomendados (Progress OpenEdge)

> Estes ajustes foram aplicados e validados no servidor **db-progress001** em 18/06/2026.
> O servidor passou de carga instável (swap em uso, ulimit crítico) para **CPU 99% idle, swap 0 B, latência de disco ~0,7 ms**.

### Comparativo antes × depois

#### Memória virtual (`vm.*`)

| Parâmetro | ❌ Antes | ✅ Depois | Por que importa |
|-----------|---------|----------|-----------------|
| `vm.swappiness` | **60** (padrão) / **10** (sysctl.conf conflitante) | **1** | Kernel praticamente não usa swap — mantém buffers do Progress na RAM |
| `vm.dirty_ratio` | **20%** | **10%** | Força escrita em disco mais cedo, evita pico de I/O repentino |
| `vm.dirty_background_ratio` | **10%** | **3%** | pdflush começa a gravar mais cedo, reduz acúmulo de dados sujos |
| `vm.dirty_expire_centisecs` | **3000** (30 s) | **500** (5 s) | Dados sujos escritos em 5 s em vez de 30 s |
| `vm.dirty_writeback_centisecs` | **500** (5 s) | **100** (1 s) | Frequência de flush 5× maior — mais consistência transacional |
| `vm.overcommit_memory` | **0** (heurístico) | **2** (estrito) | Progress aloca memória de forma segura — sem OOM inesperado |
| `vm.overcommit_ratio` | **50%** (padrão) | **95%** | Permite uso de até 95 % da RAM + swap |

#### Rede (`net.*`)

| Parâmetro | ❌ Antes | ✅ Depois | Por que importa |
|-----------|---------|----------|-----------------|
| `net.core.rmem_max` | **~200 KB** (212992) | **16 MB** (16777216) | Buffer de recepção TCP 80× maior — melhora throughput PASOE↔DB |
| `net.core.wmem_max` | **~200 KB** (212992) | **16 MB** (16777216) | Buffer de envio TCP 80× maior — reduz retransmissões |
| `net.ipv4.tcp_rmem` | padrão do kernel | **4K / 87K / 16M** | Ajuste dinâmico do buffer de recepção por conexão |
| `net.ipv4.tcp_wmem` | padrão do kernel | **4K / 64K / 16M** | Ajuste dinâmico do buffer de envio por conexão |
| `net.ipv4.tcp_fin_timeout` | **60 s** | **15 s** | Conexões encerradas liberadas 4× mais rápido |
| `net.ipv4.tcp_keepalive_time` | **7200 s** (2 h) | **300 s** (5 min) | Sessões Progress inativas detectadas em 5 min em vez de 2 h |
| `net.core.somaxconn` | **4096** | **4096** | Sem alteração — já adequado para a carga |

#### Filesystem e I/O

| Parâmetro | ❌ Antes | ✅ Depois | Por que importa |
|-----------|---------|----------|-----------------|
| `fs.aio-max-nr` | **65.536** | **1.048.576** | Suporta volume alto de operações async I/O dos bancos Progress |
| Transparent HugePages | **madvise** | **never** | Elimina latência de fragmentação de memória — recomendado pelo Progress |

#### Limites de processo

| Parâmetro | ❌ Antes | ✅ Depois | Por que importa |
|-----------|---------|----------|-----------------|
| `open files` (ulimit -n) | **1024** ⚠️ crítico | **65.536** | 1024 causava erros "too many open files" com 12 bancos × múltiplas conexões |

---

### Aplicar os ajustes

```bash
sudo tee /etc/sysctl.d/99-progress-db.conf <<'EOF'
# Memória virtual
vm.swappiness                  = 1
vm.dirty_ratio                 = 10
vm.dirty_background_ratio      = 3
vm.dirty_expire_centisecs      = 500
vm.dirty_writeback_centisecs   = 100
vm.overcommit_memory           = 2
vm.overcommit_ratio            = 95

# Rede
net.core.rmem_max              = 16777216
net.core.wmem_max              = 16777216
net.ipv4.tcp_rmem              = 4096 87380 16777216
net.ipv4.tcp_wmem              = 4096 65536 16777216
net.ipv4.tcp_fin_timeout       = 15
net.ipv4.tcp_keepalive_time    = 300
net.core.somaxconn             = 4096

# I/O assíncrono
fs.aio-max-nr                  = 1048576
EOF

sudo sysctl --system
```

> **Atenção:** se o `/etc/sysctl.conf` contiver `vm.swappiness` com valor diferente, ele pode sobrescrever o arquivo acima.
> Verifique e corrija:
> ```bash
> grep swappiness /etc/sysctl.conf /etc/sysctl.d/*.conf
> # Se aparecer valor diferente de 1 em algum arquivo, edite e corrija
> ```

Limites de processo:

```bash
sudo tee /etc/security/limits.d/99-progress-db.conf <<'EOF'
ti soft nofile 65536
ti hard nofile 65536
EOF
```

Desabilitar Transparent HugePages (recomendado pelo Progress):

```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Persistir após reboot
sudo tee -a /etc/rc.local <<'EOF'
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
EOF
sudo chmod +x /etc/rc.local
```

### Verificar se os ajustes foram aplicados

```bash
sysctl vm.swappiness vm.dirty_ratio vm.dirty_background_ratio \
       vm.overcommit_memory net.core.rmem_max net.ipv4.tcp_keepalive_time \
       fs.aio-max-nr

cat /proc/sys/kernel/mm/transparent_hugepage/enabled
# esperado: always madvise [never]

ulimit -n
# esperado: 65536
```

---

## Backup online

O backup utiliza `probkup online` — os bancos continuam disponíveis durante o processo.

**Executar manualmente:**

```bash
sudo /opt/dashboard/executa_bkp.sh        # Produção
sudo /opt/dashboard/executa_bkp_8480.sh   # TST
sudo /opt/dashboard/executa_bkp_8580.sh   # HML
```

**Agendar via cron (exemplo — Produção às 22h):**

```bash
crontab -e
# Adicionar:
0 22 * * * sudo /opt/dashboard/executa_bkp.sh >> /var/log/bkp-progress.log 2>&1
```

**Logs gerados:**

| Ambiente | Diretório de log |
|----------|------------------|
| Produção | `/mnt/backup-progress/Backup-Progress/pp/logs/` |
| TST | `/mnt/backup-progress/Backup-Progress/pp/8480/logs/` |
| HML | `/mnt/backup-progress/Backup-Progress/pp/8580/logs/` |

Logs mais antigos que 30 dias são removidos automaticamente pelo script.

---

## API REST — referência

Todos os endpoints requerem sessão autenticada (cookie de sessão).

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/login` | Autenticar (`{"username":"...","password":"..."}`) |
| POST | `/api/logout` | Encerrar sessão |
| GET | `/api/me` | Dados do usuário logado |
| GET | `/api/metrics` | Métricas Produção (CPU, RAM, bancos, usuários) |
| GET | `/api/metrics-8480` | Métricas TST |
| GET | `/api/metrics-8580` | Métricas HML |
| GET | `/api/backup-status` | Status último backup Produção |
| GET | `/api/backup-status-8480` | Status último backup TST |
| GET | `/api/backup-status-8580` | Status último backup HML |
| POST | `/api/banco/8380/bkp` | Executar backup Produção |
| POST | `/api/banco/8480/bkp` | Executar backup TST |
| POST | `/api/banco/8580/bkp` | Executar backup HML |
| POST | `/api/kick-user` | Derrubar usuário conectado (admin) |
| GET | `/api/admin/users` | Listar usuários (admin) |
| POST | `/api/admin/users` | Criar usuário (admin) |
| PUT | `/api/admin/users/<id>` | Editar usuário (admin) |
| DELETE | `/api/admin/users/<id>` | Excluir usuário (admin) |

---

## Comandos úteis

| Ação | Comando |
|------|---------|
| Ver status | `sudo systemctl status dashboard` |
| Parar serviço | `sudo systemctl stop dashboard` |
| Reiniciar | `sudo systemctl restart dashboard` |
| Ver logs em tempo real | `sudo journalctl -u dashboard -f` |
| Ver últimos 100 logs | `sudo journalctl -u dashboard -n 100` |
| Desabilitar autostart | `sudo systemctl disable dashboard` |
| Testar API localmente | `curl -s http://localhost:3000/api/metrics \| python3 -m json.tool` |

---

## Solução de problemas

### Serviço não inicia

```bash
sudo journalctl -u dashboard -n 50
```

Causas comuns:
- `ModuleNotFoundError: flask` → instalar dependências (passo 2)
- `PermissionError` nos scripts → verificar sudoers (passo 4)
- `Address already in use` → outra aplicação na porta 3000

### Métricas não aparecem / dados zerados

1. Verificar se os bancos Progress estão rodando:
   ```bash
   ps aux | grep proserve
   ```
2. Verificar se as portas estão ouvindo:
   ```bash
   ss -tlnp | grep -E '236|246|256'
   ```
3. Verificar se `_mprshut` está no PATH:
   ```bash
   which _mprshut || echo "não encontrado — adicionar DLC ao PATH"
   export DLC=/usr/dlc128
   export PATH=$PATH:$DLC/bin
   ```

### Backup falha com "não montado"

O script verifica se `/mnt/backup-progress` está montado antes de executar.

```bash
mountpoint -q /mnt/backup-progress && echo "montado" || echo "NÃO montado"
```

Se não montado, verificar `/etc/fstab` ou montar manualmente:

```bash
sudo mount /mnt/backup-progress
```

### Usuário não consegue fazer login

Verificar se o `users.db` existe e tem o usuário:

```bash
python3 -c "
import sqlite3
conn = sqlite3.connect('/opt/dashboard/users.db')
for row in conn.execute('SELECT id, username, role FROM users'):
    print(row)
"
```

---

## Ambiente de referência (JA)

| Item | Valor |
|------|-------|
| Servidor DB | db-progress001 |
| IP DB | 192.168.7.9 |
| Servidor PASOE/Tomcat | SRV-DTSAPP001 |
| IP PASOE | 192.168.7.10 |
| OpenEdge | 12.8 |
| DLC | `/usr/dlc128` |
| Diretório bancos | `/bancos/` |
| Backup | `/mnt/backup-progress/Backup-Progress/pp/` |
| URL do painel | http://192.168.7.9:3000 |
| Porta do painel | 3000 |
| Serviço | `dashboard.service` |
| Usuário serviço | `ti` |
