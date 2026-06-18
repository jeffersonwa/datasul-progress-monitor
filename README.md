# Monitor Datasul Progress Dashboard

Monitor em tempo real para ambientes Progress OpenEdge 12.8 (Datasul).  
Exibe conexões, processos, recursos de disco/memória, I/O por banco e status de backup.

---

## Estrutura do Repositório

```
datasul-progress-monitor/
├── install.sh                  ← script de instalação (execute como root)
├── app/
│   ├── app.py                  ← aplicação Flask (API + servidor web)
│   └── static/
│       ├── index.html          ← painel principal
│       └── login.html          ← tela de login
├── scripts/                    ← scripts auxiliares chamados pelo monitor
│   ├── list_users.sh           ← lista usuários conectados (8380 Produção)
│   ├── list_users_8480.sh      ←   idem TST 8480
│   ├── list_users_8580.sh      ←   idem HML 8580
│   ├── kick_user.sh            ← desconecta usuário (8380)
│   ├── kick_user_8480.sh       ←   idem TST
│   ├── kick_user_8580.sh       ←   idem HML
│   ├── carga_8380.sh           ← sobe bancos Produção
│   ├── carga_8480.sh           ←   idem TST
│   ├── carga_8580.sh           ←   idem HML
│   ├── derruba_8380.sh         ← derruba bancos Produção
│   ├── derruba_8480.sh         ←   idem TST
│   ├── derruba_8580.sh         ←   idem HML
│   ├── db_io_8480.sh           ← I/O por banco TST
│   ├── db_io_8580.sh           ←   idem HML
│   └── executa_bkp.sh          ← backup online Produção
└── systemd/
    └── dashboard.service       ← unit file do serviço systemd
```

---

## Pré-requisitos

| Requisito | Detalhe |
|-----------|---------|
| OS | Ubuntu 24.04 LTS |
| Progress OpenEdge | 12.8 instalado em `/usr/dlc128` |
| Usuário de serviço | `ti` deve existir (`adduser ti`) |
| Bancos de dados | montados em `/bancos/DATABASE-JA-{8380,8480,8580}` |
| Backup (opcional) | mount `/mnt/backup-progress` para o script de backup |

---

## Instalação

```bash
# 1. Clonar o repositório
git clone https://github.com/jeffersonwa/datasul-progress-monitor.git
cd datasul-progress-monitor

# 2. Executar o instalador como root
sudo bash install.sh
```

O script realiza automaticamente:

1. Instala dependências de sistema (`apt`) e Python (`pip3`)
2. Copia `app/` e `scripts/` para `/opt/dashboard/`
3. Cria o banco SQLite de usuários (`users.db`)
4. Configura `/etc/sudoers.d/dashboard` (NOPASSWD para todos os scripts)
5. Instala e habilita `systemd/dashboard.service`

Ao final exibe a URL de acesso.

---

## Ambientes monitorados

| Ambiente | Porta Progress | Diretório dos bancos |
|----------|---------------|----------------------|
| Produção | 8380 | `/bancos/DATABASE-JA-8380` |
| TST      | 8480 | `/bancos/DATABASE-JA-8480` |
| HML      | 8580 | `/bancos/DATABASE-JA-8580` |

O monitor roda na porta **3000** — acesse `http://<ip-do-servidor>:3000`.

---

## Operação

```bash
# Status do serviço
systemctl status dashboard

# Logs em tempo real
journalctl -u dashboard -f

# Reiniciar após alterar app.py
sudo systemctl restart dashboard
```

---

## Parâmetros de Kernel (ajustes aplicados no servidor)

Arquivo: `/etc/sysctl.d/99-progress-db.conf`

| Parâmetro | Antes | Depois | Motivo |
|-----------|-------|--------|--------|
| `kernel.shmmax` | 33 554 432 | 68 719 476 736 | Memória compartilhada para os bancos |
| `kernel.shmall` | 2 097 152 | 16 777 216 | Páginas de memória compartilhada |
| `vm.swappiness` | 60 | 10 | Reduz pressão de swap |
| `net.core.somaxconn` | 4 096 | 65 535 | Fila de conexões TCP |
| `net.ipv4.tcp_tw_reuse` | 0 | 1 | Reutilização de sockets TIME_WAIT |
| `fs.file-max` | padrão | 1 048 576 | Limite global de file descriptors |

```bash
# Aplicar sem reiniciar
sudo sysctl -p /etc/sysctl.d/99-progress-db.conf
```

---

## Estrutura no servidor (após instalação)

```
/opt/dashboard/
├── app.py
├── static/
│   ├── index.html
│   └── login.html
├── users.db              ← banco SQLite (usuários do monitor)
└── *.sh                  ← scripts auxiliares

/etc/systemd/system/dashboard.service
/etc/sudoers.d/dashboard
```
