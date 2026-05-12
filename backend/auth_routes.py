import uuid
import json
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify, current_app
from flask_bcrypt import Bcrypt
from flask_jwt_extended import (
    JWTManager, create_access_token, create_refresh_token,
    jwt_required, get_jwt_identity, verify_jwt_in_request
)
from google.oauth2 import id_token
from google.auth.transport import requests
import sqlite3

auth_bp = Blueprint('auth', __name__)
bcrypt = Bcrypt()
jwt = JWTManager()

DB_NAME = "biomed_database.db"

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

# --- INITIALIZE SCHEMA (Called on boot) ---
def init_auth_db():
    conn = get_db()
    conn.execute('''CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL,
        password_hash TEXT, reg_number TEXT UNIQUE NOT NULL, role TEXT,
        google_id TEXT, email_verified INTEGER DEFAULT 0, verification_token TEXT,
        reset_token TEXT, reset_token_expiry TEXT, created_at TEXT,
        last_login TEXT, online INTEGER DEFAULT 0, last_seen TEXT, avatar_color TEXT)''')
    conn.commit()
    conn.close()

# --- REGISTER ---
@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.json
    name, email = data.get('name'), data.get('email')
    password, reg_number = data.get('password'), data.get('reg_number')

    if not all([name, email, password, reg_number]):
        return jsonify({"success": False, "message": "All fields are required."}), 400

    if len(password) < 8:
        return jsonify({"success": False, "message": "Password must be at least 8 characters."}), 400

    conn = get_db()
    
    # Check if email or reg_number exists
    if conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone():
        return jsonify({"success": False, "message": "Email already registered."}), 400
    if conn.execute("SELECT id FROM users WHERE reg_number = ?", (reg_number,)).fetchone():
        return jsonify({"success": False, "message": "Registration number already in use."}), 400

    user_id = str(uuid.uuid4())
    pw_hash = bcrypt.generate_password_hash(password).decode('utf-8')
    v_token = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()

    conn.execute('''INSERT INTO users (id, name, email, password_hash, reg_number, role, 
                    email_verified, verification_token, created_at) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                 (user_id, name, email, pw_hash, reg_number, 'technician', 0, v_token, now))
    conn.commit()
    conn.close()

    # TO DO: Integrate Flask-Mail here to send v_token link to user's email

    return jsonify({"success": True, "message": "Registration successful. Check your email to verify your account."})

# --- LOGIN ---
@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.json
    email, password = data.get('email'), data.get('password')

    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    
    if not user or not user['password_hash']:
        return jsonify({"success": False, "message": "Invalid email or password."}), 401

    if not bcrypt.check_password_hash(user['password_hash'], password):
        return jsonify({"success": False, "message": "Invalid email or password."}), 401

    if user['email_verified'] == 0:
        return jsonify({"success": False, "message": "Please verify your email first."}), 403

    # Generate Tokens
    now = datetime.utcnow().isoformat()
    conn.execute("UPDATE users SET last_login = ?, online = 1 WHERE id = ?", (now, user['id']))
    conn.commit()
    conn.close()

    access_token = create_access_token(identity=user['id'])
    refresh_token = create_refresh_token(identity=user['id'])

    return jsonify({
        "success": True,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user": {"id": user['id'], "name": user['name'], "email": user['email'], "reg_number": user['reg_number'], "role": user['role']}
    })

# --- GOOGLE AUTH ---
@auth_bp.route('/google', methods=['POST'])
def google_auth():
    data = request.json
    token, reg_number = data.get('id_token'), data.get('reg_number')

    try:
        # Verify Firebase/Google Token
        idinfo = id_token.verify_firebase_token(token, requests.Request(), audience=current_app.config.get('FIREBASE_PROJECT_ID'))
        email, name, google_id = idinfo['email'], idinfo.get('name', 'Technician'), idinfo['sub']

        conn = get_db()
        user = conn.execute("SELECT * FROM users WHERE email = ? OR google_id = ?", (email, google_id)).fetchone()
        now = datetime.utcnow().isoformat()

        if not user:
            if not reg_number:
                return jsonify({"success": False, "message": "reg_number_required"}), 400
                
            user_id = str(uuid.uuid4())
            conn.execute('''INSERT INTO users (id, name, email, google_id, reg_number, role, email_verified, created_at, last_login)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''', 
                         (user_id, name, email, google_id, reg_number, 'technician', 1, now, now))
            conn.commit()
            user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        else:
            conn.execute("UPDATE users SET last_login = ?, google_id = ? WHERE id = ?", (now, google_id, user['id']))
            conn.commit()

        access_token = create_access_token(identity=user['id'])
        refresh_token = create_refresh_token(identity=user['id'])
        conn.close()

        return jsonify({
            "success": True, "access_token": access_token, "refresh_token": refresh_token,
            "user": {"id": user['id'], "name": user['name'], "email": user['email'], "reg_number": user['reg_number'], "role": user['role']}
        })
    except Exception as e:
        return jsonify({"success": False, "message": "Invalid Google token."}), 401

# --- REFRESH TOKEN ---
@auth_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    current_user = get_jwt_identity()
    new_access_token = create_access_token(identity=current_user)
    return jsonify({"success": True, "access_token": new_access_token})

# --- LOGOUT ---
@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    current_user = get_jwt_identity()
    conn = get_db()
    conn.execute("UPDATE users SET online = 0, last_seen = ? WHERE id = ?", (datetime.utcnow().isoformat(), current_user))
    conn.commit()
    conn.close()
    return jsonify({"success": True, "message": "Logged out securely."})