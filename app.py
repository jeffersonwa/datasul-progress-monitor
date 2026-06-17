#!/usr/bin/env python3
from flask import Flask, jsonify, send_from_directory, request, session, redirect, url_for
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
import psutil, subprocess, os, time, glob, re, sqlite3
from functools import wraps

app = Flask(__name__, static_folder='static')
app.secret_key = 'ja8380-progress-monitor-2026'
CORS(app, supports_credentials=True)

DB_PATH   = '/opt/dashboard/users.db'
PROGRESS_PORTS = {
    'dtviewer': 23650, 'eai': 23621, 'ems2adt': 23600, 'ems2cad': 23601,
    'ems2mov': 23602, 'ems2mp': 23603, 'ems5cad': 23606, 'ems5mov': 23607,
    'emsdes': 23635, 'emsfnd': 23619, 'emsinc': 23009, 'hcm': 23608
}
BKP_LOG_DIR = '/mnt/backup-progress/Backup-Progress/pp/logs'

PROGRESS_PORTS_8480 = {
    'dtviewer': 24650, 'eai': 24621, 'ems2adt': 24600, 'ems2cad': 24601,
    'ems2mov': 24602, 'ems2mp': 24603, 'ems5cad': 24606, 'ems5mov': 24607,
    'emsdes': 24635, 'emsfnd': 24619, 'emsinc': 24009, 'hcm': 24608
}
DB_DIR_8480 = '/bancos/DATABASE-JA-8480'

PROGRESS_PORTS_8580 = {
    'dtviewer': 25650, 'eai': 25621, 'ems2adt': 25600, 'ems2cad': 25601,
    'ems2mov': 25602, 'ems2mp': 25603, 'ems5cad': 25606, 'ems5mov': 25607,
    'emsdes': 25635, 'emsfnd': 25619, 'emsinc': 25009, 'hcm': 25608
}
DB_DIR_8580 = '/bancos/DATABASE-JA-8580'

# ── banco de usuarios ─────────────────────────────────────────────────────────
def db_conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c

def init_db():
    with db_conn() as c:
        c.execute('''CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            login TEXT UNIQUE NOT NULL,
            senha TEXT NOT NULL,
            nome TEXT NOT NULL,
            perfil TEXT NOT NULL DEFAULT 'viewer',
            ativo INTEGER NOT NULL DEFAULT 1,
            criado_em TEXT DEFAULT (datetime('now','localtime'))
        )''')
        # admin padrao se nao existir
        if not c.execute("SELECT 1 FROM usuarios WHERE login='admin'").fetchone():
            c.execute("INSERT INTO usuarios (login,senha,nome,perfil) VALUES (?,?,?,?)",
                      ('admin', generate_password_hash('admin123'), 'Administrador', 'admin'))
        c.commit()

init_db()

import threading

# cache de metricas do sistema atualizado a cada 3s em background
_sys_metrics = {}
_sys_metrics_lock = threading.Lock()

def _update_sys_metrics():
    # primer inicial do cpu_percent (primeiro call retorna 0)
    psutil.cpu_percent(interval=None, percpu=True)
    for p in psutil.process_iter(['name', 'cpu_percent']):
        pass
    while True:
        try:
            pc = psutil.cpu_percent(interval=2, percpu=True)
            vm = psutil.virtual_memory()
            sw = psutil.swap_memory()
            mem_used_real = vm.total - vm.available  # inclui cache/buffers do kernel
            with _sys_metrics_lock:
                _sys_metrics['cpu']      = {'percent': round(sum(pc)/len(pc), 1), 'per_core': pc, 'count': psutil.cpu_count()}
                _sys_metrics['memory']   = {'total_gb': round(vm.total/1e9,1), 'used_gb': round(mem_used_real/1e9,1), 'available_gb': round(vm.available/1e9,1), 'percent': vm.percent}
                _sys_metrics['swap']     = {'total_gb': round(sw.total/1e9,1), 'used_gb': round(sw.used/1e9,1), 'percent': sw.percent}
                _sys_metrics['load_avg'] = list(os.getloadavg())
                _sys_metrics['disk']     = get_disk_info()
        except Exception:
            pass

threading.Thread(target=_update_sys_metrics, daemon=True).start()

# ── auth helpers ──────────────────────────────────────────────────────────────
def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            if request.path.startswith('/api/'):
                return jsonify({'ok': False, 'msg': 'Nao autenticado'}), 401
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get('perfil') != 'admin':
            return jsonify({'ok': False, 'msg': 'Acesso negado — perfil admin necessario'}), 403
        return f(*args, **kwargs)
    return decorated

# ── rotas de autenticacao ─────────────────────────────────────────────────────
@app.route('/login')
def login_page():
    if 'user_id' in session:
        return redirect('/')
    return send_from_directory('static', 'login.html')

@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.json or {}
    login = data.get('login', '').strip()
    senha = data.get('senha', '')
    with db_conn() as c:
        u = c.execute("SELECT * FROM usuarios WHERE login=? AND ativo=1", (login,)).fetchone()
    if not u or not check_password_hash(u['senha'], senha):
        return jsonify({'ok': False, 'msg': 'Login ou senha incorretos'}), 401
    session.permanent = True
    session['user_id'] = u['id']
    session['login']   = u['login']
    session['nome']    = u['nome']
    session['perfil']  = u['perfil']
    return jsonify({'ok': True, 'nome': u['nome'], 'perfil': u['perfil']})

@app.route('/api/logout', methods=['POST'])
def api_logout():
    session.clear()
    return jsonify({'ok': True})

@app.route('/api/me')
def api_me():
    if 'user_id' not in session:
        return jsonify({'ok': False}), 401
    return jsonify({'ok': True, 'login': session['login'], 'nome': session['nome'], 'perfil': session['perfil']})

# ── crud de usuarios (admin) ──────────────────────────────────────────────────
@app.route('/api/usuarios', methods=['GET'])
@login_required
@admin_required
def listar_usuarios():
    with db_conn() as c:
        rows = c.execute("SELECT id,login,nome,perfil,ativo,criado_em FROM usuarios ORDER BY id").fetchall()
    return jsonify([dict(r) for r in rows])

@app.route('/api/usuarios', methods=['POST'])
@login_required
@admin_required
def criar_usuario():
    d = request.json or {}
    login  = d.get('login','').strip()
    nome   = d.get('nome','').strip()
    senha  = d.get('senha','')
    perfil = d.get('perfil','viewer')
    if not login or not nome or not senha:
        return jsonify({'ok': False, 'msg': 'login, nome e senha obrigatorios'}), 400
    if perfil not in ('admin','viewer'):
        return jsonify({'ok': False, 'msg': 'perfil invalido'}), 400
    try:
        with db_conn() as c:
            c.execute("INSERT INTO usuarios (login,senha,nome,perfil) VALUES (?,?,?,?)",
                      (login, generate_password_hash(senha), nome, perfil))
            c.commit()
        return jsonify({'ok': True, 'msg': f'Usuario {login} criado'})
    except sqlite3.IntegrityError:
        return jsonify({'ok': False, 'msg': f'Login {login} ja existe'}), 409

@app.route('/api/usuarios/<int:uid>', methods=['PUT'])
@login_required
@admin_required
def editar_usuario(uid):
    d = request.json or {}
    campos, vals = [], []
    if 'nome'   in d: campos.append('nome=?');   vals.append(d['nome'])
    if 'perfil' in d: campos.append('perfil=?'); vals.append(d['perfil'])
    if 'ativo'  in d: campos.append('ativo=?');  vals.append(1 if d['ativo'] else 0)
    if 'senha'  in d and d['senha']:
        campos.append('senha=?'); vals.append(generate_password_hash(d['senha']))
    if not campos:
        return jsonify({'ok': False, 'msg': 'Nenhum campo para atualizar'}), 400
    vals.append(uid)
    with db_conn() as c:
        c.execute(f"UPDATE usuarios SET {','.join(campos)} WHERE id=?", vals)
        c.commit()
    return jsonify({'ok': True, 'msg': 'Usuario atualizado'})

@app.route('/api/usuarios/<int:uid>', methods=['DELETE'])
@login_required
@admin_required
def excluir_usuario(uid):
    if uid == session.get('user_id'):
        return jsonify({'ok': False, 'msg': 'Nao e possivel excluir o proprio usuario'}), 400
    with db_conn() as c:
        c.execute("DELETE FROM usuarios WHERE id=?", (uid,))
        c.commit()
    return jsonify({'ok': True, 'msg': 'Usuario excluido'})

# ── progress helpers ──────────────────────────────────────────────────────────
def parse_mprshut_line(db, line):
    parts = line.split()
    if not parts or not parts[0].isdigit() or len(parts) < 11:
        return None
    usr   = parts[0]
    pid   = parts[1]
    login = ' '.join(parts[5:10])
    if parts[10].startswith('REMC'):
        usuario = '--'; tipo = parts[10]; tty = parts[11] if len(parts) > 11 else '--'
    else:
        usuario = parts[10]; tipo = parts[11] if len(parts) > 11 else '--'; tty = parts[12] if len(parts) > 12 else '--'
    return {'db': db, 'usr_num': usr, 'pid': pid, 'usuario': usuario, 'workstation': tty, 'tipo': tipo, 'hora': login}

def get_progress_users():
    users = []
    seen  = set()
    try:
        out = subprocess.check_output(['sudo', '/opt/dashboard/list_users.sh'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=30)
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
    except:
        pass
    return sorted(users, key=lambda x: (x['usuario'], x['db']))

def get_backup_status():
    status = {'running': False, 'pid': None, 'last_log_date': None,
              'last_log_lines': [], 'last_result': None,
              'mount_ok': os.path.ismount('/mnt/backup-progress')}
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
            status['last_log_date'] = os.path.basename(last).replace('backup-','').replace('.log','')
            with open(last) as f:
                lines = [l.rstrip() for l in f.readlines() if l.strip()]
            status['last_log_lines'] = lines[-30:]
            erros = [l for l in lines if 'ERRO' in l]
            oks   = [l for l in lines if l.startswith('OK:')]
            status['last_result'] = f'ERRO ({len(erros)} falha(s))' if erros else (f'OK ({len(oks)} banco(s))' if oks else 'Incompleto')
    except:
        pass
    return status

def get_disk_info():
    disks = []
    for p in psutil.disk_partitions():
        try:
            u = psutil.disk_usage(p.mountpoint)
            disks.append({'mount': p.mountpoint, 'total_gb': round(u.total/1e9,1),
                          'used_gb': round(u.used/1e9,1), 'percent': u.percent})
        except:
            pass
    return disks

def get_db_connections():
    # Progress usa portas dinamicas para sessoes — contar via _mprshut list
    conns = {name: 0 for name in PROGRESS_PORTS}
    try:
        out = subprocess.check_output(['sudo', '/opt/dashboard/list_users.sh'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=30)
        for line in out.splitlines():
            if '|' not in line:
                continue
            db = line.split('|', 1)[0].strip()
            if db in conns:
                conns[db] += 1
    except:
        pass
    return conns

def get_progress_processes():
    procs = []
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent', 'memory_percent']):
            try:
                name = proc.info['name'] or ''
                if '_mprosrv' not in name and 'proserve' not in name:
                    continue
                cmd = ' '.join(proc.info['cmdline'] or [])
                db_match = re.search(r'/bancos/[^/]+/(\w+)', cmd)
                banco = db_match.group(1) if db_match else ''
                procs.append({
                    'pid': str(proc.info['pid']),
                    'cpu': round(proc.info['cpu_percent'], 1),
                    'mem': round(proc.info['memory_percent'], 1),
                    'banco': banco,
                    'cmd': cmd[:120]
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except:
        pass
    return procs

DB_DIR = '/bancos/DATABASE-JA-8380'

def get_db_connections_8480():
    conns = {name: 0 for name in PROGRESS_PORTS_8480}
    try:
        out = subprocess.check_output(['sudo', '/opt/dashboard/list_users_8480.sh'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=30)
        for line in out.splitlines():
            if '|' not in line:
                continue
            db = line.split('|', 1)[0].strip()
            if db in conns:
                conns[db] += 1
    except:
        pass
    return conns

def get_progress_users_8480():
    users = []
    seen  = set()
    try:
        out = subprocess.check_output(['sudo', '/opt/dashboard/list_users_8480.sh'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=30)
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
    except:
        pass
    return sorted(users, key=lambda x: (x['usuario'], x['db']))

def get_progress_processes_8480():
    procs = []
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent', 'memory_percent']):
            try:
                name = proc.info['name'] or ''
                if '_mprosrv' not in name and 'proserve' not in name:
                    continue
                cmd = ' '.join(proc.info['cmdline'] or [])
                if 'DATABASE-JA-8480' not in cmd:
                    continue
                db_match = re.search(r'/bancos/DATABASE-JA-8480/(\w+)', cmd)
                banco = db_match.group(1) if db_match else ''
                procs.append({
                    'pid': str(proc.info['pid']),
                    'cpu': round(proc.info['cpu_percent'], 1),
                    'mem': round(proc.info['memory_percent'], 1),
                    'banco': banco,
                    'cmd': cmd[:120]
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except:
        pass
    return procs

def get_db_resources_8480():
    banks = list(PROGRESS_PORTS_8480.keys())
    resources = {}
    for banco in banks:
        size_mb = 0
        try:
            for ext in ['.db', '.bi', '.ai', '.lg']:
                f = os.path.join(DB_DIR_8480, banco + ext)
                if os.path.exists(f):
                    size_mb += os.path.getsize(f) / (1024 * 1024)
        except:
            pass
        resources[banco] = {'cpu': 0.0, 'mem_mb': 0.0, 'io_read_mb': 0.0, 'io_write_mb': 0.0,
                            'size_mb': round(size_mb, 1), 'pids': []}
    for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent',
                                     'memory_info', 'io_counters']):
        try:
            name = proc.info['name'] or ''
            if '_mprosrv' not in name and 'proserve' not in name:
                continue
            cmd = ' '.join(proc.info['cmdline'] or [])
            db_match = re.search(r'/bancos/DATABASE-JA-8480/(\w+)', cmd)
            if not db_match:
                continue
            banco = db_match.group(1)
            if banco not in resources:
                continue
            resources[banco]['cpu']    += proc.info['cpu_percent'] or 0
            resources[banco]['mem_mb'] += (proc.info['memory_info'].rss / (1024*1024)) if proc.info['memory_info'] else 0
            resources[banco]['pids'].append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    try:
        io_out = subprocess.check_output(['sudo', '/opt/dashboard/db_io_8480.sh'],
                                         text=True, stderr=subprocess.DEVNULL, timeout=10)
        for line in io_out.splitlines():
            parts = line.strip().split('|')
            if len(parts) == 3 and parts[0] in resources:
                resources[parts[0]]['io_read_mb']  += int(parts[1]) / (1024*1024)
                resources[parts[0]]['io_write_mb'] += int(parts[2]) / (1024*1024)
    except Exception:
        pass
    for v in resources.values():
        v['cpu']         = round(v['cpu'], 1)
        v['mem_mb']      = round(v['mem_mb'], 1)
        v['io_read_mb']  = round(v['io_read_mb'], 1)
        v['io_write_mb'] = round(v['io_write_mb'], 1)
    return resources

def get_db_connections_8580():
    conns = {name: 0 for name in PROGRESS_PORTS_8580}
    try:
        out = subprocess.check_output(['sudo', '/opt/dashboard/list_users_8580.sh'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=30)
        for line in out.splitlines():
            if '|' not in line:
                continue
            db = line.split('|', 1)[0].strip()
            if db in conns:
                conns[db] += 1
    except:
        pass
    return conns

def get_progress_users_8580():
    users = []
    seen  = set()
    try:
        out = subprocess.check_output(['sudo', '/opt/dashboard/list_users_8580.sh'],
                                      text=True, stderr=subprocess.DEVNULL, timeout=30)
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
    except:
        pass
    return sorted(users, key=lambda x: (x['usuario'], x['db']))

def get_progress_processes_8580():
    procs = []
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent', 'memory_percent']):
            try:
                name = proc.info['name'] or ''
                if '_mprosrv' not in name and 'proserve' not in name:
                    continue
                cmd = ' '.join(proc.info['cmdline'] or [])
                if 'DATABASE-JA-8580' not in cmd:
                    continue
                db_match = re.search(r'/bancos/DATABASE-JA-8580/(\w+)', cmd)
                banco = db_match.group(1) if db_match else ''
                procs.append({
                    'pid': str(proc.info['pid']),
                    'cpu': round(proc.info['cpu_percent'], 1),
                    'mem': round(proc.info['memory_percent'], 1),
                    'banco': banco,
                    'cmd': cmd[:120]
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except:
        pass
    return procs

def get_db_resources_8580():
    banks = list(PROGRESS_PORTS_8580.keys())
    resources = {}
    for banco in banks:
        size_mb = 0
        try:
            for ext in ['.db', '.bi', '.ai', '.lg']:
                f = os.path.join(DB_DIR_8580, banco + ext)
                if os.path.exists(f):
                    size_mb += os.path.getsize(f) / (1024 * 1024)
        except:
            pass
        resources[banco] = {'cpu': 0.0, 'mem_mb': 0.0, 'io_read_mb': 0.0, 'io_write_mb': 0.0,
                            'size_mb': round(size_mb, 1), 'pids': []}
    for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent',
                                     'memory_info', 'io_counters']):
        try:
            name = proc.info['name'] or ''
            if '_mprosrv' not in name and 'proserve' not in name:
                continue
            cmd = ' '.join(proc.info['cmdline'] or [])
            db_match = re.search(r'/bancos/DATABASE-JA-8580/(\w+)', cmd)
            if not db_match:
                continue
            banco = db_match.group(1)
            if banco not in resources:
                continue
            resources[banco]['cpu']    += proc.info['cpu_percent'] or 0
            resources[banco]['mem_mb'] += (proc.info['memory_info'].rss / (1024*1024)) if proc.info['memory_info'] else 0
            resources[banco]['pids'].append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    try:
        io_out = subprocess.check_output(['sudo', '/opt/dashboard/db_io_8580.sh'],
                                         text=True, stderr=subprocess.DEVNULL, timeout=10)
        for line in io_out.splitlines():
            parts = line.strip().split('|')
            if len(parts) == 3 and parts[0] in resources:
                resources[parts[0]]['io_read_mb']  += int(parts[1]) / (1024*1024)
                resources[parts[0]]['io_write_mb'] += int(parts[2]) / (1024*1024)
    except Exception:
        pass
    for v in resources.values():
        v['cpu']         = round(v['cpu'], 1)
        v['mem_mb']      = round(v['mem_mb'], 1)
        v['io_read_mb']  = round(v['io_read_mb'], 1)
        v['io_write_mb'] = round(v['io_write_mb'], 1)
    return resources

def get_db_resources():
    banks = list(PROGRESS_PORTS.keys())
    resources = {}

    # tamanho dos arquivos de banco no disco
    for banco in banks:
        size_mb = 0
        try:
            for ext in ['.db', '.bi', '.ai', '.lg']:
                f = os.path.join(DB_DIR, banco + ext)
                if os.path.exists(f):
                    size_mb += os.path.getsize(f) / (1024 * 1024)
        except:
            pass
        resources[banco] = {'cpu': 0.0, 'mem_mb': 0.0, 'io_read_mb': 0.0, 'io_write_mb': 0.0,
                            'size_mb': round(size_mb, 1), 'pids': []}

    # CPU, memória e I/O por processo
    for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent',
                                     'memory_info', 'io_counters']):
        try:
            name = proc.info['name'] or ''
            if '_mprosrv' not in name and 'proserve' not in name:
                continue
            cmd = ' '.join(proc.info['cmdline'] or [])
            db_match = re.search(r'/bancos/DATABASE-JA-8380/(\w+)', cmd)
            if not db_match:
                continue
            banco = db_match.group(1)
            if banco not in resources:
                continue
            resources[banco]['cpu']    += proc.info['cpu_percent'] or 0
            resources[banco]['mem_mb'] += (proc.info['memory_info'].rss / (1024*1024)) if proc.info['memory_info'] else 0
            pass  # IO lido via db_io.sh abaixo
            resources[banco]['pids'].append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    # I/O via script com sudo (lê /proc/<pid>/io como root)
    try:
        io_out = subprocess.check_output(['sudo', '/opt/dashboard/db_io.sh'],
                                         text=True, stderr=subprocess.DEVNULL, timeout=10)
        for line in io_out.splitlines():
            parts = line.strip().split('|')
            if len(parts) == 3 and parts[0] in resources:
                resources[parts[0]]['io_read_mb']  += int(parts[1]) / (1024*1024)
                resources[parts[0]]['io_write_mb'] += int(parts[2]) / (1024*1024)
    except Exception:
        pass

    # arredondar
    for v in resources.values():
        v['cpu']          = round(v['cpu'], 1)
        v['mem_mb']       = round(v['mem_mb'], 1)
        v['io_read_mb']   = round(v['io_read_mb'], 1)
        v['io_write_mb']  = round(v['io_write_mb'], 1)

    return resources

# ── api protegida ─────────────────────────────────────────────────────────────
def _base_metrics():
    with _sys_metrics_lock:
        return {
            'timestamp':  time.time(),
            'cpu':        _sys_metrics.get('cpu',      {'percent':0,'per_core':[],'count':0}),
            'memory':     _sys_metrics.get('memory',   {'total_gb':0,'used_gb':0,'available_gb':0,'percent':0}),
            'swap':       _sys_metrics.get('swap',     {'total_gb':0,'used_gb':0,'percent':0}),
            'load_avg':   _sys_metrics.get('load_avg', [0,0,0]),
            'disk':       _sys_metrics.get('disk',     []),
        }

@app.route('/api/metrics')
@login_required
def metrics():
    d = _base_metrics()
    d['progress_processes'] = get_progress_processes()
    d['db_connections']     = get_db_connections()
    return jsonify(d)

@app.route('/api/users')
@login_required
def users():
    u = get_progress_users()
    return jsonify({'total': len(u), 'users': u})

@app.route('/api/backup-status')
@login_required
def backup_status():
    return jsonify(get_backup_status())

@app.route('/api/db-resources')
@login_required
def db_resources():
    return jsonify(get_db_resources())

@app.route('/api/kick-user', methods=['POST'])
@login_required
def kick_user():
    if session.get('perfil') != 'admin':
        return jsonify({'ok': False, 'msg': 'Apenas administradores podem derrubar usuarios'}), 403
    data    = request.json
    usuario = data.get('usuario', '')
    if not usuario:
        return jsonify({'ok': False, 'msg': 'usuario obrigatorio'}), 400
    try:
        out   = subprocess.check_output(['sudo', '/opt/dashboard/kick_user.sh', usuario],
                                        text=True, stderr=subprocess.STDOUT, timeout=60)
        linhas = [l for l in out.splitlines() if l.strip()]
        oks    = [l for l in linhas if l.startswith('OK:')]
        erros  = [l for l in linhas if l.startswith('ERRO:')]
        if oks:
            bancos = [l.split(':')[1] for l in oks]
            msg = f"Usuario {usuario} desconectado de {len(oks)} banco(s): {', '.join(bancos)}"
            return jsonify({'ok': True, 'msg': msg})
        elif erros:
            return jsonify({'ok': False, 'msg': erros[0]})
        else:
            return jsonify({'ok': False, 'msg': f'Nenhuma sessao encontrada para {usuario}'})
    except Exception as e:
        return jsonify({'ok': False, 'msg': str(e)}), 500

@app.route('/api/metrics-8480')
@login_required
def metrics_8480():
    d = _base_metrics()
    d['progress_processes'] = get_progress_processes_8480()
    d['db_connections']     = get_db_connections_8480()
    return jsonify(d)

@app.route('/api/users-8480')
@login_required
def users_8480():
    u = get_progress_users_8480()
    return jsonify({'total': len(u), 'users': u})

@app.route('/api/backup-status-8480')
@login_required
def backup_status_8480():
    return jsonify(get_backup_status())

@app.route('/api/db-resources-8480')
@login_required
def db_resources_8480():
    return jsonify(get_db_resources_8480())

@app.route('/api/kick-user-8480', methods=['POST'])
@login_required
def kick_user_8480():
    if session.get('perfil') != 'admin':
        return jsonify({'ok': False, 'msg': 'Apenas administradores podem derrubar usuarios'}), 403
    data    = request.json
    usuario = data.get('usuario', '')
    if not usuario:
        return jsonify({'ok': False, 'msg': 'usuario obrigatorio'}), 400
    try:
        out   = subprocess.check_output(['sudo', '/opt/dashboard/kick_user_8480.sh', usuario],
                                        text=True, stderr=subprocess.STDOUT, timeout=60)
        linhas = [l for l in out.splitlines() if l.strip()]
        oks    = [l for l in linhas if l.startswith('OK:')]
        erros  = [l for l in linhas if l.startswith('ERRO:')]
        if oks:
            bancos = [l.split(':')[1] for l in oks]
            return jsonify({'ok': True, 'msg': f"Usuario {usuario} desconectado de {len(oks)} banco(s): {', '.join(bancos)}"})
        elif erros:
            return jsonify({'ok': False, 'msg': erros[0]})
        else:
            return jsonify({'ok': False, 'msg': f'Nenhuma sessao encontrada para {usuario}'})
    except Exception as e:
        return jsonify({'ok': False, 'msg': str(e)}), 500

@app.route('/api/metrics-8580')
@login_required
def metrics_8580():
    d = _base_metrics()
    d['progress_processes'] = get_progress_processes_8580()
    d['db_connections']     = get_db_connections_8580()
    return jsonify(d)

@app.route('/api/users-8580')
@login_required
def users_8580():
    u = get_progress_users_8580()
    return jsonify({'total': len(u), 'users': u})

@app.route('/api/backup-status-8580')
@login_required
def backup_status_8580():
    return jsonify(get_backup_status())

@app.route('/api/db-resources-8580')
@login_required
def db_resources_8580():
    return jsonify(get_db_resources_8580())

@app.route('/api/kick-user-8580', methods=['POST'])
@login_required
def kick_user_8580():
    if session.get('perfil') != 'admin':
        return jsonify({'ok': False, 'msg': 'Apenas administradores podem derrubar usuarios'}), 403
    data    = request.json
    usuario = data.get('usuario', '')
    if not usuario:
        return jsonify({'ok': False, 'msg': 'usuario obrigatorio'}), 400
    try:
        out   = subprocess.check_output(['sudo', '/opt/dashboard/kick_user_8580.sh', usuario],
                                        text=True, stderr=subprocess.STDOUT, timeout=60)
        linhas = [l for l in out.splitlines() if l.strip()]
        oks    = [l for l in linhas if l.startswith('OK:')]
        erros  = [l for l in linhas if l.startswith('ERRO:')]
        if oks:
            bancos = [l.split(':')[1] for l in oks]
            msg = f"Usuario {usuario} desconectado de {len(oks)} banco(s): {', '.join(bancos)}"
            return jsonify({'ok': True, 'msg': msg})
        elif erros:
            return jsonify({'ok': False, 'msg': erros[0]})
        else:
            return jsonify({'ok': False, 'msg': f'Nenhuma sessao encontrada para {usuario}'})
    except Exception as e:
        return jsonify({'ok': False, 'msg': str(e)}), 500

import shlex

BANCO_SCRIPTS = {
    '8480': {
        'derruba':  '/opt/dashboard/derruba_8480.sh',
        'inicia':   '/opt/dashboard/carga_8480.sh',
        'atualiza': '/opt/dashboard/atualiza_8480.sh',
    },
    '8380': {
        'derruba': '/opt/dashboard/derruba_8380.sh',
        'inicia':  '/opt/dashboard/carga_8380.sh',
    },
    '8580': {
        'derruba':  '/opt/dashboard/derruba_8580.sh',
        'inicia':   '/opt/dashboard/carga_8580.sh',
        'atualiza': '/opt/dashboard/atualiza_8580.sh',
    }
}

_banco_job = {}  # env -> {'status','log','started'}

@app.route('/api/banco-action', methods=['POST'])
@login_required
def banco_action():
    if session.get('perfil') != 'admin':
        return jsonify({'ok': False, 'msg': 'Apenas administradores podem executar esta acao'}), 403
    data   = request.json or {}
    env    = data.get('env', '')
    action = data.get('action', '')
    if env not in BANCO_SCRIPTS or action not in BANCO_SCRIPTS[env]:
        return jsonify({'ok': False, 'msg': 'Acao ou ambiente invalido'}), 400
    script = BANCO_SCRIPTS[env][action]
    job_key = f"{env}_{action}"
    if _banco_job.get(job_key, {}).get('status') == 'running':
        return jsonify({'ok': False, 'msg': f'Ja existe um processo {action} {env} em execucao'}), 409
    def _run():
        _banco_job[job_key] = {'status': 'running', 'log': [], 'started': time.strftime('%H:%M:%S')}
        try:
            proc = subprocess.Popen(['sudo', script], stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True)
            for line in proc.stdout:
                _banco_job[job_key]['log'].append(line.rstrip())
            proc.wait()
            _banco_job[job_key]['status'] = 'ok' if proc.returncode == 0 else 'erro'
        except Exception as e:
            _banco_job[job_key]['status'] = 'erro'
            _banco_job[job_key]['log'].append(str(e))
    threading.Thread(target=_run, daemon=True).start()
    return jsonify({'ok': True, 'msg': f'Iniciado: {action} {env}', 'job': job_key})

@app.route('/api/banco-job/<job_key>')
@login_required
def banco_job_status(job_key):
    job = _banco_job.get(job_key)
    if not job:
        return jsonify({'status': 'idle', 'log': []})
    return jsonify({'status': job['status'], 'log': job['log'], 'started': job.get('started','')})

@app.route('/')
@login_required
def index():
    return send_from_directory('static', 'index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=False)
