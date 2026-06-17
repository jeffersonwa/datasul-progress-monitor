# Monitor Datasul Progress

Painel de monitoramento em tempo real para servidores Progress OpenEdge / Datasul TOTVS.

## Funcionalidades

- CPU, memória, swap e disco em tempo real (atualização a cada 5s)
- Processos `proserve` ativos com PID, CPU% e MEM%
- Conexões TCP ativas por banco Progress (ems2adt, ems2cad, ems2mov, etc.)
- Gráficos históricos de CPU e RAM (últimos 30 pontos)
- Interface dark mode responsiva

## Requisitos

- Python 3.8+
- `flask`, `flask-cors`, `psutil`

```bash
pip install flask flask-cors psutil
```

## Execução

```bash
python3 app.py
# Acesse: http://localhost:3000
```

## Deploy como serviço (Linux/systemd)

```bash
sudo cp dashboard.service /etc/systemd/system/
sudo systemctl enable dashboard
sudo systemctl start dashboard
```

## Ambiente de produção

- Servidor: `db-progress001` (192.168.7.9)
- Acesso interno: http://192.168.7.9:3000
