#!/usr/bin/env python3
from flask import Flask, jsonify, send_from_directory, request
from flask_cors import CORS
import psutil, subprocess, os, time, glob, re

app = Flask(__name__, static_folder='static')
CORS(app)

PROGRESS_PORTS = {
    'dtviewer': 23650, 'eai': 23621, 'ems2adt': 23600, 'ems2cad': 23601,
    'ems2mov': 23602, 'ems2mp': 23603, 'ems5cad': 23606, 'ems5mov': 23607,
    'emsdes': 23635, 'emsfnd': 23619, 'emsinc': 23009, 'hcm': 23608
}
BKP_LOG_DIR = '/mnt/backup-progress/Backup-Progress/pp/logs'

def get_progress_processes():
    procs = []
    try:
        out = subprocess.check_output(['ps', 'aux'], text=True)
        for line in out.splitlines():
            if 'proserve' in line or '_mprosrv' in line:
                parts = line.split()
                procs.append({'pid': parts[1], 'cpu': parts[2], 'mem': parts[3], 'cmd': ' '.join(parts[10:])[:80]})
    except:
        pass
    return procs

def get_db_connections():
    conns = {}
    try:
        out = subprocess.check_output(['ss', '-tnp'], text=True)
        for name, port in PROGRESS_PORTS.items():
            count = sum(1 for l in out.splitlines() if f':{port}' in l and 'ESTAB' in l)
            conns[name] = count
    except:
        pass
    return conns

def parse_mprshut_line(db, line):
    parts = line.split()
    if not parts or not parts[0].isdigit() or len(parts) < 11:
        return None
    usr   = parts[0]
    pid   = parts[1]
    login = ' '.join(parts[5:10])
    if parts[10].startswith('REMC'):
        usuario = '--'
        tipo    = parts[10]
        tty     = parts[11] if len(parts) > 11 else '--'
    else:
        usuario = parts[10]
        tipo    = parts[11] if len(parts) > 11 else '--'
        tty     = parts[12] if len(parts) > 12 else '--'
    return {'db': db, 'usr_num': usr, 'pid': pid, 'usuario': usuario,
            'workstation': tty, 'tipo': tipo, 'hora': login}

def get_progress_users():
    users = []
    seen = set()
    try:
        out = subprocess.check_output(
            ['sudo', '/opt/dashboard/list_users.sh'],
            text=True, stderr=subprocess.DEVNULL, timeout=30
        )
        for line in out.splitlines():
            if '|' not in line:
                continue
            db, rest = line.split('|', 1)
            u = parse_mprshut_line(db, rest)
            if not u:
                continue
            key = f"{db}_{u['usr_num']}_{u['pid']}"
            if key in seen:
                continue
            seen.add(key)
            users.append(u)
    except Exception as e:
        pass
    return sorted(users, key=lambda x: (x['usuario'], x['db']))

def get_backup_status():
    status = {
        'running': False,
        'pid': None,
        'last_log_date': None,
        'last_log_lines': [],
        'last_result': None,
        'mount_ok': os.path.ismount('/mnt/backup-progress')
    }
    try:
        out = subprocess.check_output(['pgrep', '-af', 'probkup'], text=True)
        if out.strip():
            status['running'] = True
            status['pid'] = out.strip().split()[0]
    except:
        pass
    try:
        logs = sorted(glob.glob(f'{BKP_LOG_DIR}/backup-*.log'))
        if logs:
            last = logs[-1]
            status['last_log_date'] = os.path.basename(last).replace('backup-', '').replace('.log', '')
            with open(last) as f:
                lines = [l.rstrip() for l in f.readlines() if l.strip()]
            status['last_log_lines'] = lines[-30:]
            erros = [l for l in lines if 'ERRO' in l]
            oks = [l for l in lines if l.startswith('OK:')]
            if erros:
                status['last_result'] = f'ERRO ({len(erros)} falha(s))'
            elif oks:
                status['last_result'] = f'OK ({len(oks)} banco(s))'
            else:
                status['last_result'] = 'Incompleto'
    except:
        pass
    return status

def get_disk_info():
    disks = []
    for p in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(p.mountpoint)
            disks.append({'mount': p.mountpoint, 'total_gb': round(usage.total/1e9,1),
                          'used_gb': round(usage.used/1e9,1), 'percent': usage.percent})
        except:
            pass
    return disks

@app.route('/api/metrics')
def metrics():
    vm = psutil.virtual_memory()
    sw = psutil.swap_memory()
    return jsonify({
        'timestamp': time.time(),
        'cpu': {'percent': psutil.cpu_percent(interval=0.1), 'per_core': psutil.cpu_percent(interval=1, percpu=True), 'count': psutil.cpu_count()},
        'memory': {'total_gb': round(vm.total/1e9,1), 'used_gb': round(vm.used/1e9,1), 'available_gb': round(vm.available/1e9,1), 'percent': vm.percent},
        'swap': {'total_gb': round(sw.total/1e9,1), 'used_gb': round(sw.used/1e9,1), 'percent': sw.percent},
        'disk': get_disk_info(),
        'load_avg': list(os.getloadavg()),
        'progress_processes': get_progress_processes(),
        'db_connections': get_db_connections()
    })

@app.route('/api/users')
def users():
    u = get_progress_users()
    return jsonify({'total': len(u), 'users': u})

@app.route('/api/backup-status')
def backup_status():
    return jsonify(get_backup_status())

@app.route('/api/kick-user', methods=['POST'])
def kick_user():
    data = request.json
    usuario = data.get('usuario', '')
    if not usuario:
        return jsonify({'ok': False, 'msg': 'usuario obrigatorio'}), 400
    try:
        out = subprocess.check_output(
            ['sudo', '/opt/dashboard/kick_user.sh', usuario],
            text=True, stderr=subprocess.STDOUT, timeout=60
        )
        linhas = [l for l in out.splitlines() if l.strip()]
        oks    = [l for l in linhas if l.startswith('OK:')]
        erros  = [l for l in linhas if l.startswith('ERRO:')]
        if oks:
            bancos = [l.split(':')[1] for l in oks]
            msg = f"Usuario {usuario} desconectado de {len(oks)} banco(s): {', '.join(bancos)}"
            if erros:
                msg += f" | Erros: {len(erros)}"
            return jsonify({'ok': True, 'msg': msg})
        elif erros:
            return jsonify({'ok': False, 'msg': f"Erro ao desconectar {usuario}: {erros[0]}"})
        else:
            return jsonify({'ok': False, 'msg': f'Nenhuma sessao encontrada para {usuario}'})
    except Exception as e:
        return jsonify({'ok': False, 'msg': str(e)}), 500

@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=False)
