from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room, leave_room
from datetime import datetime
import sqlite3
import uuid

app = Flask(__name__)
app.config['SECRET_KEY'] = 'biomed-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*")

DB_NAME = "chat_system.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    # Users & Presence
    cursor.execute('''CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY, name TEXT, reg_number TEXT UNIQUE, 
        online INTEGER DEFAULT 0, last_seen TEXT)''')
    # Conversations
    cursor.execute('''CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY, is_group INTEGER, group_name TEXT, 
        last_message TEXT, last_message_time TEXT)''')
    # Messages
    cursor.execute('''CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY, conversation_id TEXT, sender_id TEXT, 
        sender_name TEXT, message_text TEXT, message_type TEXT, 
        file_url TEXT, timestamp TEXT, read_by TEXT)''')
    # Meetings
    cursor.execute('''CREATE TABLE IF NOT EXISTS meetings (
        id TEXT PRIMARY KEY, topic TEXT, scheduled_time TEXT, 
        duration TEXT, participants TEXT, history_transcript TEXT)''')
    conn.commit()
    conn.close()

# --- NEW REST ENDPOINTS FOR REAL USERS ---
@app.route('/api/users', methods=['GET'])
def get_users():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    users = conn.execute("SELECT id, name, reg_number, online, last_seen FROM users").fetchall()
    conn.close()
    return jsonify([dict(u) for u in users])

@app.route('/api/chat/register', methods=['POST'])
def register_chat_user():
    data = request.json
    user_id = str(uuid.uuid4()) # Generate a unique ID for the technician
    conn = sqlite3.connect(DB_NAME)
    try:
        conn.execute("INSERT INTO users (id, name, reg_number) VALUES (?, ?, ?)", 
                     (user_id, data.get('name'), data.get('reg_number')))
        conn.commit()
        return jsonify({"status": "success", "user_id": user_id, "name": data.get('name')})
    except sqlite3.IntegrityError:
        return jsonify({"status": "error", "message": "Technician already registered."}), 400
    finally:
        conn.close()

# --- SOCKET IO EVENTS ---
@socketio.on('connect')
def handle_connect():
    print(f"Client Connected: {request.sid}")

@socketio.on('user_online')
def on_online(data):
    user_id = data.get('user_id')
    conn = sqlite3.connect(DB_NAME)
    conn.execute("UPDATE users SET online = 1 WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    emit('presence_update', {'user_id': user_id, 'online': True}, broadcast=True)

@socketio.on('join')
def on_join(data):
    room = data['conversation_id']
    join_room(room)

@socketio.on('send_message')
def handle_message(data):
    room = data['conversation_id']
    msg_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()
    
    conn = sqlite3.connect(DB_NAME)
    conn.execute('''INSERT INTO messages 
        (id, conversation_id, sender_id, sender_name, message_text, message_type, timestamp, read_by) 
        VALUES (?,?,?,?,?,?,?,?)''', 
        (msg_id, room, data.get('sender_id'), data.get('sender_name'), 
         data.get('message_text'), data.get('message_type', 'text'), timestamp, '[]'))
    
    conn.execute('''UPDATE conversations SET last_message = ?, last_message_time = ? 
        WHERE id = ?''', (data.get('message_text'), timestamp, room))
    conn.commit()
    conn.close()

    data['id'] = msg_id
    data['timestamp'] = timestamp
    emit('receive_message', data, room=room)

@socketio.on('typing')
def handle_typing(data):
    room = data['conversation_id']
    emit('user_typing', data, room=room, include_self=False)

if __name__ == '__main__':
    init_db()
    socketio.run(app, host='0.0.0.0', port=5001, debug=True)