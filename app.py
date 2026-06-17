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
        out = subprocess.check_output(['ps', 'auxww'], text=True)
        for line in out.splitlines():
            if 'proserve' in line or '_mprosrv' in line:
                p = line.split()
                cmd = ' '.join(p[10:])
                # banco fica no path: /bancos/DATABASE-JA-8380/<nome>
                db_match = re.search(r'/bancos/[^/]+/(\w+)', cmd)
                banco = db_match.group(1) if db_match else ''
                procs.append({'pid': p[1], 'cpu': p[2], 'mem': p[3], 'banco': banco, 'cmd': cmd[:120]})
    except:
        pass
    return procs

# ── api protegida ─────────────────────────────────────────────────────────────
@app.route('/api/metrics')
@login_required
def metrics():
    vm = psutil.virtual_memory()
    sw = psutil.swap_memory()
    return jsonify({
        'timestamp': time.time(),
        'cpu': (lambda pc: {'percent': round(sum(pc)/len(pc),1), 'per_core': pc, 'count': psutil.cpu_count()})(psutil.cpu_percent(interval=0.5, percpu=True)),
        'memory': {'total_gb': round(vm.total/1e9,1), 'used_gb': round(vm.used/1e9,1), 'available_gb': round(vm.available/1e9,1), 'percent': vm.percent},
        'swap': {'total_gb': round(sw.total/1e9,1), 'used_gb': round(sw.used/1e9,1), 'percent': sw.percent},
        'disk': get_disk_info(), 'load_avg': list(os.getloadavg()),
        'progress_processes': get_progress_processes(), 'db_connections': get_db_connections()
    })

@app.route('/api/users')
@login_required
def users():
    u = get_progress_users()
    return jsonify({'total': len(u), 'users': u})

@app.route('/api/backup-status')
@login_required
def backup_status():
    return jsonify(get_backup_status())

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

@app.route('/')
@login_required
def index():
    return send_from_directory('static', 'index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=False)
