#!/usr/bin/env python3
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
import psutil, subprocess, os, time, re

app = Flask(__name__, static_folder='static')
CORS(app)

PROGRESS_PORTS = {
    'ems2adt': 23600, 'ems2cad': 23601, 'ems2mov': 23602, 'ems2mp': 23603,
    'ems5cad': 23606, 'ems5mov': 23607, 'hcm': 23608, 'emsfnd': 23619,
    'eai': 23621, 'dtviewer': 23650, 'emsdes': 23635, 'broker': 23009
}

def get_progress_processes():
    dbs = []
    try:
        out = subprocess.check_output(['ps', 'aux'], text=True)
        for line in out.splitlines():
            if 'proserve' in line or '_mprosrv' in line:
                parts = line.split()
                dbs.append({
                    'pid': parts[1],
                    'cpu': parts[2],
                    'mem': parts[3],
                    'cmd': ' '.join(parts[10:])[:80]
                })
    except:
        pass
    return dbs

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

def get_disk_info():
    disks = []
    for p in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(p.mountpoint)
            disks.append({
                'mount': p.mountpoint,
                'total_gb': round(usage.total / 1e9, 1),
                'used_gb': round(usage.used / 1e9, 1),
                'percent': usage.percent
            })
        except:
            pass
    return disks

@app.route('/api/metrics')
def metrics():
    vm = psutil.virtual_memory()
    swap = psutil.swap_memory()
    cpu_per = psutil.cpu_percent(interval=1, percpu=True)
    return jsonify({
        'timestamp': time.time(),
        'cpu': {
            'percent': psutil.cpu_percent(interval=0.1),
            'per_core': cpu_per,
            'count': psutil.cpu_count()
        },
        'memory': {
            'total_gb': round(vm.total / 1e9, 1),
            'used_gb': round(vm.used / 1e9, 1),
            'available_gb': round(vm.available / 1e9, 1),
            'percent': vm.percent
        },
        'swap': {
            'total_gb': round(swap.total / 1e9, 1),
            'used_gb': round(swap.used / 1e9, 1),
            'percent': swap.percent
        },
        'disk': get_disk_info(),
        'load_avg': list(os.getloadavg()),
        'progress_processes': get_progress_processes(),
        'db_connections': get_db_connections()
    })

@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=False)
