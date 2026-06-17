# Monitor Datasul Progress

Painel de monitoramento em tempo real para servidores Progress OpenEdge / Datasul TOTVS.

![Python](https://img.shields.io/badge/Python-3.8+-blue) ![Flask](https://img.shields.io/badge/Flask-3.x-green) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Funcionalidades

- CPU, memória, swap e disco em tempo real (atualização a cada 5s)
- Processos `proserve` ativos com PID, CPU% e MEM%
- Conexões TCP ativas por banco Progress (ems2adt, ems2cad, ems2mov, etc.)
- Gráficos históricos de CPU e RAM (últimos 30 pontos)
- Interface dark mode responsiva

---

## Pré-requisitos

- Ubuntu 20.04+ (ou qualquer Linux com systemd)
- Python 3.8 ou superior
- Acesso `sudo` no servidor

Verifique a versão do Python:

```bash
python3 --version
```

---

## 1. Clonar o repositório

```bash
cd /opt
sudo git clone https://github.com/jeffersonwa/datasul-progress-monitor.git dashboard
sudo chown -R $USER:$USER /opt/dashboard
cd /opt/dashboard
```

---

## 2. Instalar dependências Python

### Opção A — via apt (recomendado para servidores Ubuntu)

```bash
sudo apt update
sudo apt install -y python3-flask python3-psutil
```

Verificar instalação:

```bash
python3 -c "import flask, psutil; print('OK')"
```

### Opção B — via pip (virtualenv)

```bash
python3 -m venv venv
source venv/bin/activate
pip install flask flask-cors psutil
```

> Se usar virtualenv, edite o `dashboard.service` e altere:
> ```
> ExecStart=/opt/dashboard/venv/bin/python3 /opt/dashboard/app.py
> ```

---

## 3. Testar manualmente

```bash
cd /opt/dashboard
python3 app.py
```

Abra no browser: **http://IP-DO-SERVIDOR:3000**

Pressione `Ctrl+C` para parar.

---

## 4. Configurar como serviço systemd

### 4.1 Copiar o arquivo de serviço

```bash
sudo cp /opt/dashboard/dashboard.service /etc/systemd/system/
```

### 4.2 Recarregar o systemd

```bash
sudo systemctl daemon-reload
```

### 4.3 Habilitar inicialização automática no boot

```bash
sudo systemctl enable dashboard
```

### 4.4 Iniciar o serviço

```bash
sudo systemctl start dashboard
```

### 4.5 Verificar status

```bash
sudo systemctl status dashboard
```

Saída esperada:
```
● dashboard.service - Monitor Datasul Progress Dashboard
     Active: active (running) since ...
   Main PID: XXXX (python3)
```

---

## 5. Abrir porta no firewall

Se o servidor usar UFW (Ubuntu):

```bash
sudo ufw allow 3000/tcp
sudo ufw reload
sudo ufw status
```

Se usar iptables:

```bash
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
```

---

## 6. Acessar o painel

De qualquer máquina na rede interna:

```
http://192.168.7.9:3000
```

---

## 7. Personalizar os bancos monitorados

Edite o arquivo `app.py` e localize o dicionário `PROGRESS_PORTS`:

```python
PROGRESS_PORTS = {
    'ems2adt': 23600,
    'ems2cad': 23601,
    'ems2mov': 23602,
    'ems2mp':  23603,
    'ems5cad': 23606,
    'ems5mov': 23607,
    'hcm':     23608,
    'emsfnd':  23619,
    'eai':     23621,
    'dtviewer':23650,
    'emsdes':  23635,
    'broker':  23009,
}
```

Adicione ou remova bancos conforme necessário. Após editar, reinicie o serviço:

```bash
sudo systemctl restart dashboard
```

---

## 8. Alterar a porta do painel (opcional)

Por padrão o painel roda na porta `3000`. Para alterar, edite a última linha do `app.py`:

```python
app.run(host='0.0.0.0', port=3000, debug=False)
#                        ^^^^ altere aqui
```

Reinicie o serviço após a alteração.

---

## Comandos úteis

| Ação | Comando |
|------|---------|
| Ver status | `sudo systemctl status dashboard` |
| Parar serviço | `sudo systemctl stop dashboard` |
| Reiniciar | `sudo systemctl restart dashboard` |
| Ver logs | `sudo journalctl -u dashboard -f` |
| Desabilitar autostart | `sudo systemctl disable dashboard` |

---

## Estrutura do projeto

```
/opt/dashboard/
├── app.py                  # Backend Flask (API /api/metrics)
├── dashboard.service       # Serviço systemd
└── static/
    └── index.html          # Frontend do painel (Chart.js)
```

---

## Ambiente de produção

| Item | Valor |
|------|-------|
| Servidor | db-progress001 |
| IP | 192.168.7.9 |
| Porta | 3000 |
| URL interna | http://192.168.7.9:3000 |
| Serviço | `dashboard.service` |
