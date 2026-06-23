# Painel de Monitoramento Datasul & Progress OpenEdge

[![Python](https://img.shields.io/badge/Python-3.14%2B-blue?logo=python&logoColor=white)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.x-lightgrey?logo=flask&logoColor=white)](https://flask.palletsprojects.com)
[![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20Server-orange?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Progress OpenEdge](https://img.shields.io/badge/Progress-OpenEdge%2012.8-red)](https://www.progress.com/openedge)

Este é um dashboard web leve e seguro desenvolvido em **Flask (Python 3)** para monitorar e gerenciar recursos de sistema e bancos de dados **Progress OpenEdge** dos ambientes **8380 (Produção)**, **8480 (Homologação)** e **8580 (Homologação)** hospedados no servidor Ubuntu.

O painel oferece monitoramento de hardware em tempo real, status dos bancos de dados, conexões ativas, logs de backup e a capacidade de realizar ações administrativas (iniciar/derrubar base, atualizar estrutura e desconectar usuários travados).

---

## 📌 Tabela de Conteúdos

- [🏗️ Arquitetura do Sistema](#️-arquitetura-do-sistema)
- [🛠️ Tecnologias Utilizadas](#️-tecnologias-utilizadas)
- [📂 Estrutura de Arquivos no Projeto](#-estrutura-de-arquivos-no-projeto)
- [💾 Mapeamento de Ambientes e Bancos de Dados (Recursos)](#-mapeamento-de-ambientes-e-bancos-de-dados-recursos)
- [📜 Scripts de Administração e Monitoramento](#-scripts-de-administração-e-monitoramento-optdashboard)
- [📊 Detalhamento das APIs e Endpoints do Backend](#-detalhamento-das-apis-e-endpoints-do-backend)
- [⚙️ Configuração do Servidor e Implantação](#️-configuração-do-servidor-e-implantação)
- [📈 Comandos Úteis e Diagnósticos](#-comandos-úteis-e-diagnósticos)
- [🛠️ Resolução de Problemas (Troubleshooting)](#️-resolução-de-problemas-troubleshooting)
- [🛡️ Recomendações de Segurança](#-recomendações-de-segurança)

---


## 🏗️ Arquitetura do Sistema

A imagem abaixo ilustra o fluxo de funcionamento e integração dos componentes do painel:

```mermaid
graph TD
    subgraph Cliente (Web)
        UI[Painel SPA HTML5/CSS3/JS]
        Chart[Gráficos Live Chart.js]
    end

    subgraph Servidor Ubuntu (10.0.0.240)
        Flask[Servidor Flask Backend]
        SQLite[(users.db - SQLite)]
        SysMetrics[Thread de Métricas psutil]
        ShellScripts[Scripts do Painel /opt/dashboard/*.sh]
        
        subgraph Bancos Progress
            DB_8380[(Ambiente 8380 - Porta 23xxx)]
            DB_8480[(Ambiente 8480 - Porta 24xxx)]
            DB_8580[(Ambiente 8580 - Porta 25xxx)]
        end
        
        subgraph Armazenamento
            LogBkp[/Logs de Backup /mnt/backup-progress/.../]
            DBFiles[/Arquivos .db em /bancos/.../]
        end
    end

    UI <-->|HTTP JSON APIs| Flask
    Flask <-->|Leitura/Escrita| SQLite
    Flask <-->|Coleta a cada 2s| SysMetrics
    Flask -->|Executa via Sudo| ShellScripts
    
    ShellScripts -->|promon / proshut / proserve| Bancos
    ShellScripts -->|Lê estatísticas de I/O| DBFiles
    Flask -->|Lê arquivos de log| LogBkp
```

---

## 🛠️ Tecnologias Utilizadas

### Backend
* **Python 3.14+**
* **Flask** & **Flask-CORS** (API e servidor web)
* **psutil** (coleta de recursos do sistema: CPU, RAM, Disco, rede, processos)
* **sqlite3** (banco de dados local para gerenciamento de usuários do painel)
* **werkzeug.security** (criptografia de senhas com PBKDF2)

### Frontend
* **HTML5** & **CSS3** (Tema escuro com design premium responsivo e micro-animações)
* **JavaScript (Vanilla SPA)** (Consumo assíncrono das APIs via `fetch`)
* **Chart.js v4.4** (Gráficos dinâmicos de consumo de CPU e RAM dos últimos 30 pontos de amostragem)

---

## 📂 Estrutura de Arquivos no Projeto

* `app.py`: Backend Flask principal contendo as rotas de API, conexões de banco de dados SQLite, threads de coleta de métricas e gerenciador de subprocessos.
* `users.db`: Banco de dados SQLite contendo a tabela de usuários com senhas hash-criptografadas.
* `static/`:
  * `index.html`: Interface principal do dashboard (monitor, bancos, processos, backups, ações).
  * `login.html`: Tela de login do painel.
* **Scripts de Suporte (`/opt/dashboard/`):**
  * `list_users*.sh`: Executa comandos `_mprshut` para listar sessões conectadas em cada banco.
  * `kick_user*.sh`: Desconecta um usuário específico do banco de dados correspondente.
  * `carga_*.sh`: Inicializa os bancos (`proserve`) utilizando os devidos parâmetros de buffer (`-B`, `-L`, etc.).
  * `derruba_*.sh`: Desliga os bancos de dados com segurança (`proshut`).
  * `atualiza_*.sh`: Script de sincronização de produção para homologação.
  * `executa_bkp*.sh`: Executa backups online (`probkup`).
  * `db_io*.sh`: Lê informações em tempo real de I/O do `/proc` para os PIDs de bancos.

---

## 💾 Mapeamento de Ambientes e Bancos de Dados (Recursos)

O painel gerencia e monitora 12 bancos de dados Progress OpenEdge por ambiente. Abaixo está a tabela detalhada de portas TCP e caminhos físicos dos recursos do sistema:

### Ambientes

| Ambiente | Tipo de Ambiente | Porta Base | Diretório Físico dos Arquivos `.db` | Diretório de Logs de Backup |
| :--- | :--- | :--- | :--- | :--- |
| **8380** | Produção | `23xxx` | `/bancos/DATABASE-JA-8380` | `/mnt/backup-progress/Backup-Progress/SP/8380/logs` |
| **8480** | Homologação | `24xxx` | `/bancos/DATABASE-JA-8480` | `/mnt/backup-progress/Backup-Progress/SP/8480/logs` |
| **8580** | Homologação | `25xxx` | `/bancos/DATABASE-JA-8580` | `/mnt/backup-progress/Backup-Progress/SP/8580/logs` |

### Tabela de Bancos de Dados e Portas TCP

| Nome do Banco | Porta (Prod 8380) | Porta (HML 8480) | Porta (HML 8580) | Descrição do Recurso / Mapeamento Progress |
| :--- | :---: | :---: | :---: | :--- |
| `ems2adt` | 23600 | 24600 | 25600 | Módulo de Administração / Auditoria |
| `ems2cad` | 23601 | 24601 | 25601 | Cadastros Gerais do Datasul |
| `ems2mov` | 23602 | 24602 | 25602 | Movimentações Financeiras / Comerciais |
| `ems2mp` | 23603 | 24603 | 25603 | Módulo de Manufatura / Planejamento |
| `ems5cad` | 23606 | 24606 | 25606 | Cadastros de Controladoria |
| `ems5mov` | 23607 | 24607 | 25607 | Movimentações de Controladoria |
| `hcm` | 23608 | 24608 | 25608 | Recursos Humanos / HCM |
| `emsinc` | 23009 | 24009 | 25009 | Banco de Integrações / Inquéritos |
| `emsfnd` | 23619 | 24619 | 25619 | Foundation / Framework Datasul |
| `eai` | 23621 | 24621 | 25621 | Enterprise Application Integration |
| `emsdes` | 23635 | 24635 | 25635 | Desenvolvimento / Customizações locais |
| `dtviewer` | 23650 | 24650 | 25650 | Banco do Datasul Interactive Viewer |

---

## 📜 Scripts de Administração e Monitoramento (`/opt/dashboard/`)

O backend Flask interage com o Progress OpenEdge executando scripts bash via `sudo` sem senha (conforme regras do `sudoers`).

### 1. Inicialização de Bancos (`carga_*.sh`)
Executa o comando `proserve` para carregar o banco correspondente em memória com parâmetros otimizados para o ambiente.
* **Caminhos:** `/opt/dashboard/carga_8380.sh`, `/opt/dashboard/carga_8480.sh`, `/opt/dashboard/carga_8580.sh`
* **Exemplo de Parâmetros Utilizados (Banco `ems2mov` - 8380):**
  * `-B 309970` (Database Blocks Database Buffer Pool)
  * `-L 300000` (Lock Table entries)
  * `-Mm 4096` (Message Buffer Size em bytes)
  * `-N tcp -S 23602` (Protocolo de Rede e Porta TCP)
  * `-n 121 -Ma 11 -Mn 11` (Número máximo de conexões e servidores)
  * `-usernotifytime 0 -dbnotifytime 0` (Parâmetros de notificação de transações)

### 2. Parada de Bancos (`derruba_*.sh`)
Desliga com segurança todos os bancos de dados Progress no ambiente correspondente usando `proshut`.
* **Caminhos:** `/opt/dashboard/derruba_8380.sh`, `/opt/dashboard/derruba_8480.sh`, `/opt/dashboard/derruba_8580.sh`
* **Comando interno:** `proshut $DB_DIR/$banco -by` (modo em lote/forçado para desligamento imediato).

### 3. Execução de Backup Online (`executa_bkp*.sh`)
Efetua o backup online (`probkup online`) das bases de dados ativas e salva no diretório de destino.
* **Caminhos:** `/opt/dashboard/executa_bkp.sh` (8380), `/opt/dashboard/executa_bkp_8480.sh`, `/opt/dashboard/executa_bkp_8580.sh`
* **Dependência:** O compartilhamento `/mnt/backup-progress` deve estar montado.
* **Retenção:** Limpa logs antigos de backup gerados há mais de 30 dias (`find $LOG_DIR -name 'backup-*.log' -mtime +30 -delete`).

### 4. Sincronização de Estrutura (`atualiza_*.sh`)
Atualiza a estrutura e dados dos ambientes de homologação clonando a partir da produção.
* **Caminhos:** `/opt/dashboard/atualiza_8480.sh`, `/opt/dashboard/atualiza_8580.sh`
* **Script Interno:** Chama `/bancos/DATABASE-JA-<ENV>/scripts/atualiza-bancos-prod-<ENV>.sh`.

### 5. Listagem de Usuários Conectados (`list_users*.sh`)
Lista todos os usuários conectados nos bancos ativos do Progress.
* **Caminhos:** `/opt/dashboard/list_users.sh` (8380), `/opt/dashboard/list_users_8480.sh`, `/opt/dashboard/list_users_8580.sh`
* **Mecanismo:** Executa `_mprshut $DB_DIR/$db -C list` para capturar a tabela de usuários ativos na memória compartilhada do Progress.

### 6. Desconexão de Usuários (`kick_user*.sh`)
Desconecta/desloga à força uma sessão de usuário do Progress OpenEdge que esteja travada ou consumindo recursos.
* **Caminhos:** `/opt/dashboard/kick_user.sh` (8380), `/opt/dashboard/kick_user_8480.sh`, `/opt/dashboard/kick_user_8580.sh`
* **Sintaxe de Chamada:** `sudo /opt/dashboard/kick_user.sh <NOME_DO_USUARIO>`
* **Mecanismo:** Descobre a sessão do usuário com `_mprshut -C list`, localiza o número da sessão e desconecta usando `_mprshut $db -C disconnect $usr_num`.

### 7. Estatísticas de I/O em Tempo Real (`db_io*.sh`)
Coleta o volume total de leitura e escrita de disco acumulado por cada banco Progress.
* **Caminhos:** `/opt/dashboard/db_io.sh` (8380), `/opt/dashboard/db_io_8480.sh`, `/opt/dashboard/db_io_8580.sh`
* **Mecanismo:** Monitora os PIDs ativos dos servidores Progress (`_mprosrv`) e extrai as linhas `read_bytes` e `write_bytes` do pseudo-arquivo `/proc/<pid>/io`.

---

## 📊 Detalhamento das APIs e Endpoints do Backend

Todos os endpoints (exceto a tela de login estática e o endpoint de login) exigem autenticação do painel via cookie de sessão Flask.

### 🔑 Autenticação e Sessão

#### `GET /login`
Retorna a página de login em HTML caso o usuário não esteja autenticado. Redireciona para `/` se já estiver logado.

#### `POST /api/login`
Autentica as credenciais fornecidas contra o banco local SQLite.
* **Payload de Entrada (JSON):**
  ```json
  {
    "login": "admin",
    "senha": "admin123"
  }
  ```
* **Resposta de Sucesso (200 OK):**
  ```json
  {
    "ok": true,
    "nome": "Administrador",
    "perfil": "admin"
  }
  ```
* **Resposta de Erro (401 Unauthorized):**
  ```json
  {
    "ok": false,
    "msg": "Login ou senha incorretos"
  }
  ```

#### `POST /api/logout`
Limpa a sessão de usuário atual.
* **Resposta (200 OK):**
  ```json
  {
    "ok": true
  }
  ```

#### `GET /api/me`
Retorna os metadados do usuário autenticado no momento.
* **Resposta (200 OK):**
  ```json
  {
    "ok": true,
    "login": "admin",
    "nome": "Administrador",
    "perfil": "admin"
  }
  ```

---

### 👥 Gestão de Usuários (Apenas Administradores)

Todos os métodos abaixo exigem que o perfil logado no painel seja `admin`.

#### `GET /api/usuarios`
Lista todos os usuários registrados no banco de dados local.
* **Resposta (200 OK):**
  ```json
  [
    {
      "id": 1,
      "login": "admin",
      "nome": "Administrador",
      "perfil": "admin",
      "ativo": 1,
      "criado_em": "2026-06-23 12:00:00"
    }
  ]
  ```

#### `POST /api/usuarios`
Registra um novo usuário no banco de dados.
* **Payload de Entrada (JSON):**
  ```json
  {
    "login": "suporte.ti",
    "nome": "Suporte Técnico",
    "senha": "senhaSegura123",
    "perfil": "viewer"
  }
  ```
* **Resposta de Sucesso (200 OK):**
  ```json
  {
    "ok": true,
    "msg": "Usuario suporte.ti criado"
  }
  ```

#### `PUT /api/usuarios/<int:uid>`
Atualiza os atributos de um usuário existente.
* **Payload de Entrada (JSON):**
  ```json
  {
    "nome": "Suporte TI Alterado",
    "perfil": "admin",
    "ativo": true,
    "senha": "novaSenhaOpcional"
  }
  ```
* **Resposta (200 OK):**
  ```json
  {
    "ok": true,
    "msg": "Usuario atualizado"
  }
  ```

#### `DELETE /api/usuarios/<int:uid>`
Remove permanentemente o usuário. O backend impede que o usuário logado exclua a si mesmo.
* **Resposta (200 OK):**
  ```json
  {
    "ok": true,
    "msg": "Usuario excluido"
  }
  ```

---

### 🖥️ Monitoramento de Recursos e Hardware

As métricas do sistema são atualizadas por uma thread background em cache a cada 3 segundos, reduzindo overhead de processamento.

#### `GET /api/metrics` \| `/api/metrics-8480` \| `/api/metrics-8580`
Obtém métricas de uso de hardware e recursos globais.
* **Resposta (200 OK):**
  ```json
  {
    "timestamp": 1782223400.12,
    "cpu": {
      "percent": 15.4,
      "per_core": [12.1, 18.2, 14.0, 17.3],
      "count": 4
    },
    "memory": {
      "total_gb": 16.0,
      "used_gb": 8.4,
      "available_gb": 7.6,
      "percent": 52.5
    },
    "swap": {
      "total_gb": 4.0,
      "used_gb": 0.2,
      "percent": 5.0
    },
    "load_avg": [0.45, 0.55, 0.60],
    "disk": [
      {
        "mount": "/",
        "total_gb": 100.0,
        "used_gb": 45.2,
        "percent": 45.2
      }
    ],
    "monitor": {
      "cpu_percent": 0.4,
      "mem_mb": 42.1,
      "mem_percent": 0.26,
      "itens": [
        {
          "nome": "Dashboard (Flask)",
          "pid": 12345,
          "cpu": 0.3,
          "mem_mb": 35.2,
          "threads": 4,
          "uptime_s": 86400
        }
      ]
    },
    "progress_processes": [
      {
        "pid": "4892",
        "cpu": 1.2,
        "mem": 0.8,
        "banco": "ems2mov",
        "cmd": "_mprosrv /bancos/DATABASE-JA-8380/ems2mov -m1"
      }
    ],
    "db_connections": {
      "dtviewer": 4,
      "eai": 0,
      "ems2cad": 15
    }
  }
  ```

#### `GET /api/users` \| `/api/users-8480` \| `/api/users-8580`
Retorna a lista completa de sessões ativas coletadas via comando `_mprshut`.
* **Resposta (200 OK):**
  ```json
  {
    "total": 1,
    "users": [
      {
        "db": "ems2cad",
        "usr_num": "42",
        "pid": "10982",
        "usuario": "jefferson.almeida",
        "workstation": "WS-JA-01",
        "tipo": "SELF",
        "hora": "Jun 23 08:30"
      }
    ]
  }
  ```

#### `GET /api/backup-status` \| `/api/backup-status-8480` \| `/api/backup-status-8580`
Verifica se o backup está rodando ativamente e extrai estatísticas do último log gerado.
* **Resposta (200 OK):**
  ```json
  {
    "running": false,
    "pid": null,
    "mount_ok": true,
    "last_log_date": "2026-06-23",
    "last_result": "OK (12 banco(s))",
    "banco_status": {
      "ems2cad": "OK",
      "ems2mov": "OK"
    },
    "last_log_lines": [
      "=== INICIO BACKUP ONLINE: Ter Jun 23 02:00:00 -03 2026 ===",
      "OK: ems2cad",
      "OK: ems2mov",
      "=== FIM BACKUP: Ter Jun 23 02:22:15 -03 2026 ==="
    ]
  }
  ```

#### `GET /api/db-resources` \| `/api/db-resources-8480` \| `/api/db-resources-8580`
Calcula o consumo consolidado por banco Progress somando os consumos de seus processos filhos, juntamente com estatísticas de disco (I/O e tamanho físico do arquivo).
* **Resposta (200 OK):**
  ```json
  {
    "ems2cad": {
      "cpu": 2.4,
      "mem_mb": 850.5,
      "io_read_mb": 142.5,
      "io_write_mb": 94.2,
      "size_mb": 15420.0,
      "pids": [4892, 4893]
    }
  }
  ```

---

### ⚙️ Ações e Comandos de Gerenciamento

#### `POST /api/kick-user` \| `/api/kick-user-8480` \| `/api/kick-user-8580`
Remove à força um usuário das bases do ambiente correspondente.
* **Payload de Entrada (JSON):**
  ```json
  {
    "usuario": "jefferson.almeida"
  }
  ```
* **Resposta (200 OK):**
  ```json
  {
    "ok": true,
    "msg": "Usuario jefferson.almeida desconectado de 2 banco(s): ems2cad, ems2mov"
  }
  ```

#### `POST /api/banco-action` (Apenas Administradores)
Dispara um script administrativo em background em uma thread assíncrona.
* **Payload de Entrada (JSON):**
  ```json
  {
    "env": "8380",
    "action": "inicia"
  }
  ```
  *(Opções válidas para `env`: `"8380"`, `"8480"`, `"8580"`. Opções válidas para `action`: `"inicia"`, `"derruba"`, `"atualiza"`, `"bkp"`)*
* **Resposta (200 OK):**
  ```json
  {
    "ok": true,
    "msg": "Iniciado: inicia 8380",
    "job": "8380_inicia"
  }
  ```

#### `GET /api/banco-job/<job_key>`
Verifica o log e o status da tarefa assíncrona em execução.
* **Resposta (200 OK):**
  ```json
  {
    "status": "ok",
    "started": "14:15:32",
    "log": [
      "=== CARGA 8380: Ter Jun 23 14:15:32 -03 2026 ===",
      "UP: emsfnd (23619)",
      "UP: ems2cad (23601)",
      "=== FIM: Ter Jun 23 14:16:10 -03 2026 ==="
    ]
  }
  ```

#### `GET /api/relatorio/conexoes`
Retorna a listagem detalhada do histórico de sessões do Progress OpenEdge.
* **Parâmetros de Consulta (Query Params - Opcionais):**
  * `env`: Ambiente (`8380`, `8480`, `8580`)
  * `usuario`: Filtrar por nome do usuário
  * `data_inicio`: Data inicial de conexão (`YYYY-MM-DD`)
  * `data_fim`: Data limite de conexão (`YYYY-MM-DD`)
* **Resposta (200 OK):**
  ```json
  [
    {
      "id": 1,
      "env": "8380",
      "db": "ems2cad",
      "usr_num": "15",
      "pid": "32104",
      "usuario": "jefferson.almeida",
      "workstation": "WS-JA-02",
      "tipo": "REMC",
      "login_time_progress": "Jun 23 09:15",
      "conectado_em": "2026-06-23 09:15:02",
      "desconectado_em": "2026-06-23 10:30:15",
      "duracao_segundos": 4513
    }
  ]
  ```

#### `GET /api/relatorio/tempo-diario`
Retorna a consolidação do tempo de uso por usuário por dia em segundos.
* **Parâmetros de Consulta (Query Params - Opcionais):**
  * `env`: Ambiente (`8380`, `8480`, `8580`)
  * `usuario`: Filtrar por nome do usuário
  * `data_inicio`: Data inicial (`YYYY-MM-DD`)
  * `data_fim`: Data limite (`YYYY-MM-DD`)
* **Resposta (200 OK):**
  ```json
  [
    {
      "usuario": "jefferson.almeida",
      "env": "8380",
      "dia": "2026-06-23",
      "total_segundos": 4513,
      "total_conexoes": 1
    }
  ]
  ```

---

## ⚙️ Configuração do Servidor e Implantação

Para implantar o painel no servidor Ubuntu (IP `10.0.0.240`), você pode utilizar o **script de instalação automatizada** ou realizar os passos **manualmente**.

---

### 🚀 Método 1: Instalação Automatizada (Recomendado)

O repositório inclui o script [install.sh](install.sh) que executa todo o processo de setup de forma robusta e segura.

#### O que o script faz:
1. Valida se a execução está sendo feita com privilégios administrativos (`root`/`sudo`).
2. Instala dependências de pacotes do sistema via APT (`python3-venv`, `pip`, etc.).
3. Cria a estrutura de pastas no diretório alvo `/opt/dashboard`.
4. Copia a aplicação backend (`app.py`), assets estáticos (`static/`) e todos os scripts administrativos (`.sh`).
5. Garante que o usuário `ti` exista no sistema e define a propriedade das pastas para ele.
6. Cria um **ambiente virtual Python isolado (venv)** em `/opt/dashboard/venv` e instala as bibliotecas Flask, Flask-CORS, psutil e Werkzeug.
7. Instala o arquivo de permissões do sudoers em `/etc/sudoers.d/dashboard` com permissão restrita `0440`.
8. Instala e configura a unit do Systemd em `/etc/systemd/system/dashboard.service`.
9. Recarrega as configurações e inicia o serviço.

#### Como executar:
Você pode baixar o script diretamente do repositório no servidor Ubuntu e executá-lo:

```bash
# Baixar o instalador direto do GitHub
curl -O https://raw.githubusercontent.com/jeffersonwa/datasul-progress-monitor/main/install.sh

# Conceder permissão de execução ao instalador
chmod +x install.sh

# Executar o instalador como root
sudo ./install.sh
```


---

### 🛠️ Método 2: Instalação Manual

Caso prefira configurar cada componente individualmente:

#### 1. Estrutura de Diretórios e Cópia de Arquivos
Crie os diretórios e copie os arquivos da aplicação:
```bash
sudo mkdir -p /opt/dashboard/static
sudo cp app.py /opt/dashboard/
sudo cp -r static/* /opt/dashboard/static/
sudo cp *.sh /opt/dashboard/
sudo chmod +x /opt/dashboard/*.sh
sudo chown -R ti:ti /opt/dashboard
```

#### 2. Configuração da Venv e Dependências
Crie a venv utilizando o usuário `ti`:
```bash
sudo -u ti python3 -m venv /opt/dashboard/venv
sudo -u ti /opt/dashboard/venv/bin/pip install --upgrade pip
sudo -u ti /opt/dashboard/venv/bin/pip install Flask flask-cors psutil werkzeug
```

#### 3. Requisitos de Permissões (Sudoers)
Como o usuário `ti` (dono do serviço) não é root e precisa ler do `/proc` e rodar os comandos administrativos do Progress, salve o conteúdo abaixo em `/etc/sudoers.d/dashboard`:

```bash
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
```
Ajuste as permissões do arquivo criado:
```bash
sudo chmod 0440 /etc/sudoers.d/dashboard
```

#### 4. Serviço Systemd (`/etc/systemd/system/dashboard.service`)
Configure o systemd para gerenciar o processo da aplicação de forma contínua:

```ini
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
```

Ative e inicialize o serviço:
```bash
sudo systemctl daemon-reload
sudo systemctl enable dashboard.service
sudo systemctl start dashboard.service
sudo systemctl status dashboard.service
```

### 3. Estrutura do Banco de Dados SQLite (`users.db`)
O banco de dados SQLite local localiza-se em `/opt/dashboard/users.db`. O esquema das tabelas está estruturado da seguinte forma:

#### Tabela `usuarios`
```sql
CREATE TABLE usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    login TEXT UNIQUE NOT NULL,
    senha TEXT NOT NULL,
    nome TEXT NOT NULL,
    perfil TEXT NOT NULL DEFAULT 'viewer', -- 'admin' ou 'viewer'
    ativo INTEGER NOT NULL DEFAULT 1,      -- 1 para Ativo, 0 para Inativo
    criado_em TEXT DEFAULT (datetime('now','localtime'))
);
```

#### Tabela `historico_conexoes`
```sql
CREATE TABLE historico_conexoes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    env TEXT NOT NULL,                  -- '8380', '8480' ou '8580'
    db TEXT NOT NULL,                   -- Nome do banco (ex: 'ems2cad')
    usr_num TEXT NOT NULL,              -- Número de usuário Progress
    pid TEXT NOT NULL,                  -- Process ID do cliente Progress
    usuario TEXT NOT NULL,              -- Nome do usuário conectado no Datasul
    workstation TEXT NOT NULL,          -- Terminal / Workstation do usuário
    tipo TEXT NOT NULL,                 -- Tipo de conexão (ex: 'SELF', 'REMC')
    login_time_progress TEXT,           -- Hora do login informada pelo Progress
    conectado_em TEXT NOT NULL,         -- Data/Hora detecção da conexão ativa
    desconectado_em TEXT,               -- Data/Hora detecção do encerramento (ou NULL)
    duracao_segundos INTEGER DEFAULT 0  -- Tempo de conexão em segundos
);
```

---

## 🔑 Credenciais de Acesso Padrão
* **Login:** `admin`
* **Senha:** `admin123`

> [!WARNING]
> Recomenda-se alterar a senha do usuário `admin` logo no primeiro acesso ou criar uma nova conta administrativa e excluir a padrão por questões de segurança.

---

## 📈 Comandos Úteis e Diagnósticos

Caso precise gerenciar ou depurar o painel diretamente no console do servidor Ubuntu:

### Status e Logs do Serviço Systemd
```bash
# Verificar se o serviço está em execução
sudo systemctl status dashboard.service

# Visualizar logs em tempo real (últimas 100 linhas e segue ativo)
sudo journalctl -u dashboard.service -f -n 100

# Reiniciar o painel
sudo systemctl restart dashboard.service

# Parar o painel
sudo systemctl stop dashboard.service
```

### Verificação de Rede e Portas Ouvindo
```bash
# Verificar se o dashboard está rodando na porta 3000
sudo ss -tlnp | grep :3000

# Verificar se as portas TCP dos bancos Progress estão abertas (ex: porta 236xx, 246xx, 256xx)
sudo ss -tlnp | grep -E "236|246|256"
```

### Processos Ativos
```bash
# Listar processos Progress proserve ativos no sistema
ps -ef | grep _mprosrv

# Listar processos Glances ativos
ps -ef | grep glances
```

---

## 🛠️ Resolução de Problemas (Troubleshooting)

### 1. Banco de Dados Progress Não Inicia (Erro de Lock `.lk`)
Se o console do banco retornar erros ao tentar iniciar e o status ficar como `ERRO`, verifique se há arquivos `.lk` órfãos no diretório do banco.
* **Causa:** O banco de dados foi encerrado incorretamente (queda de energia, kill -9) e o arquivo de controle de lock ficou pendente.
* **Solução:**
  1. Certifique-se de que não há nenhum processo do banco rodando: `ps -ef | grep -E "_mprosrv|_mprshut|$banco"`.
  2. Remova o arquivo `.lk` correspondente: `sudo rm /bancos/DATABASE-JA-<ENV>/$banco.lk`.
  3. Tente subir o banco novamente pelo painel ou manualmente via `carga_*.sh`.

### 2. Ações de Iniciar/Derrubar Retornam `sudo: a password is required`
Se ao clicar em "Inicia Base" ou "Derruba Base" ocorrer erro interno no dashboard e logs do journalctl apontarem requisição de senha para o sudo.
* **Causa:** O arquivo `/etc/sudoers.d/dashboard` não existe, está com permissões incorretas ou o comando no script local não bate exatamente com a regra declarada.
* **Solução:**
  1. Verifique se o arquivo existe e tem permissão correta: `ls -la /etc/sudoers.d/dashboard` (deve ser `-r--r-----` / `0440`).
  2. Teste executar o comando como o usuário `ti` diretamente: `sudo -u ti sudo /opt/dashboard/list_users.sh`.
  3. Verifique se a linha do sudoers bate letra por letra com os scripts em `/opt/dashboard/`.

### 3. Bibliotecas do Python Faltando ou Erros de `Externally Managed Environment`
* **Causa:** Tentativa de instalar dependências globais via `pip3 install` em distribuições Linux modernas (Ubuntu 24.04+).
* **Solução:**
  Sempre utilize a venv criada em `/opt/dashboard/venv`. Para instalar pacotes adicionais:
  ```bash
  sudo -u ti /opt/dashboard/venv/bin/pip install <nome-do-pacote>
  ```

---

## 🛡️ Recomendações de Segurança

1. **Alteração de Senha Padrão:** Crie imediatamente um novo usuário com perfil `admin` e exclua o usuário `admin` original para mitigar ataques de força bruta.
2. **Permissões do SQLite:** Restrinja a leitura do arquivo `users.db` para que somente o proprietário `ti` o acesse:
   ```bash
   sudo chmod 600 /opt/dashboard/users.db
   sudo chown ti:ti /opt/dashboard/users.db
   ```
3. **HTTPS / Proxy Reverso:** Em ambientes de produção reais, recomenda-se configurar um proxy reverso com Nginx e certificados SSL (Let's Encrypt) na frente da porta 3000 para trafegar os cookies de sessão de forma criptografada.

