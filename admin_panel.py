from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO
import threading
import time
from datetime import datetime
from prediction import predict_risk
from sensor import generate_sensor_data

app = Flask(__name__)
socketio = SocketIO(app)

@socketio.on('connect')
def handle_connect():
    print('Client connected')

# Global state
monitoring_active = False
last_risk_status = "Normal"
history = []
latest_sensor_data = None

def monitor_sensor():
    global monitoring_active, last_risk_status, history, latest_sensor_data
    while monitoring_active:
        data = generate_sensor_data()
        latest_sensor_data = data
        socketio.emit('sensor_update', {
            'type': 'sensor',
            'data': data
        })
        risk = predict_risk(data)
        if risk != last_risk_status:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            history.append({
                'timestamp': timestamp,
                'status': risk,
                'data': data
            })
            last_risk_status = risk
            print(f"[{timestamp}] Risk status changed: {risk}")
            socketio.emit('console_message', {
                'type': 'console',
                'message': f"[{timestamp}] Risk status changed: {risk}"
            })
        time.sleep(2)

@app.route('/api/current_data')
def get_current_data():
    if latest_sensor_data is None:
        return jsonify({'error': 'No data available yet'}), 200
    return jsonify(latest_sensor_data)

@app.route('/history')
def get_history():
    return jsonify(history)

@app.route('/clear_history', methods=['POST'])
def clear_history():
    global history
    history = []
    return jsonify({'status': 'History cleared'})

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/status')
def status():
    return jsonify({
        'monitoring_active': monitoring_active,
        'last_risk_status': last_risk_status
    })

@app.route('/start', methods=['POST'])
def start_monitoring():
    global monitoring_active
    if not monitoring_active:
        monitoring_active = True
        threading.Thread(target=monitor_sensor).start()
    return jsonify({'status': 'Monitoring started'})

@app.route('/stop', methods=['POST'])
def stop_monitoring():
    global monitoring_active
    monitoring_active = False
    return jsonify({'status': 'Monitoring stopped'})

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', debug=True)