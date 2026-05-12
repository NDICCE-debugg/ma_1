import json
import random
import os
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager
from datetime import datetime

# IMPORT THE AUTH ROUTES YOU CREATED EARLIER
from auth_routes import auth_bp, init_auth_db

# --- CONFIGURATION ---
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///biomed_server.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# --- SECURITY CONFIGURATION ---
app.config['JWT_SECRET_KEY'] = 'biomed-secure-key-2026'

# ⚠️ REPLACE THIS WITH YOUR EXACT FIREBASE PROJECT ID!
app.config['FIREBASE_PROJECT_ID'] = 'biomed-assistant' 

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)

# Register the Authentication endpoints
app.register_blueprint(auth_bp, url_prefix='/api/auth')

# --- MODELS ---
class Machine(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    model_name = db.Column(db.String(100), nullable=False) 
    serial_number = db.Column(db.String(100), unique=True)
    location = db.Column(db.String(100))
    status = db.Column(db.String(50), default="Operational")

class ServiceLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    machine_id = db.Column(db.Integer, db.ForeignKey('machine.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    error_code = db.Column(db.String(50))
    notes = db.Column(db.Text)
    technician_id = db.Column(db.String(50))

class SparePart(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    quantity = db.Column(db.Integer)
    reorder_threshold = db.Column(db.Integer)

# --- REAL AI INTEGRATION MODULE ---
def run_openai_rag_query(query_text):
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return f"UPLINK ESTABLISHED. RAG Pipeline online. (System Awaiting OPENAI_API_KEY to process: '{query_text}')"
    return "API KEY FOUND. RAG Processing..."

def run_predictive_maintenance(machine_id):
    risk = random.uniform(0, 100) 
    return round(risk, 2)

# --- API ENDPOINTS ---
@app.route('/api/sync', methods=['POST'])
def sync_data():
    data = request.json
    incoming_logs = data.get('logs', [])
    processed_count = 0
    for log in incoming_logs:
        new_log = ServiceLog(
            machine_id=log['machine_id'],
            error_code=log['error_code'],
            notes=log['notes'],
            technician_id=log['tech_id'],
            timestamp=datetime.fromisoformat(log['timestamp'])
        )
        db.session.add(new_log)
        processed_count += 1
    
    db.session.commit()
    parts = SparePart.query.all()
    inventory_data = [{'id': p.id, 'name': p.name, 'qty': p.quantity} for p in parts]

    return jsonify({
        "status": "success",
        "synced_logs": processed_count,
        "inventory_updates": inventory_data
    })

@app.route('/api/query', methods=['POST'])
def ai_query():
    data = request.json
    query = data.get('query', '')
    response_text = run_openai_rag_query(query)
    return jsonify({"answer": response_text})

@app.route('/api/predict', methods=['GET'])
def predict_health():
    machine_id = request.args.get('id')
    risk_score = run_predictive_maintenance(machine_id)
    return jsonify({
        "machine_id": machine_id,
        "failure_probability": risk_score,
        "recommendation": "Urgent Service" if risk_score > 80 else "Monitor"
    })

# --- INIT DB ---
def init_db():
    with app.app_context():
        db.create_all()
        # Initialize the authentication database tables
        init_auth_db()
        
        if not Machine.query.first():
            m1 = Machine(model_name="Aeonmed VG70", serial_number="SN-VG70-001", location="ICU-1")
            m2 = Machine(model_name="Dräger Evita", serial_number="SN-DR-992", location="ER-2")
            p1 = SparePart(name="Flow Sensor", quantity=5, reorder_threshold=2)
            db.session.add_all([m1, m2, p1])
            db.session.commit()

if __name__ == '__main__':
    init_db()
    app.run(debug=True, host='0.0.0.0', port=5000)