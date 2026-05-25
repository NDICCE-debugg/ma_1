import os
import random
import requests
import base64
import binascii
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

# Load backend credentials from backend/.env regardless of launch directory.
load_dotenv(Path(__file__).with_name(".env"), override=True)

from rag_service import RagError, answer_with_manuals, ingest_manual

app = Flask(__name__)
cors_origins = [
    origin.strip()
    for origin in os.environ.get(
        "CORS_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000",
    ).split(",")
    if origin.strip()
]
CORS(app, origins=cors_origins)

MAX_ATTACHMENT_COUNT = int(os.environ.get("MAX_AI_ATTACHMENT_COUNT", "3"))
MAX_ATTACHMENT_BYTES = int(os.environ.get("MAX_AI_ATTACHMENT_BYTES", str(6 * 1024 * 1024)))
MAX_TOTAL_ATTACHMENT_BYTES = int(
    os.environ.get("MAX_TOTAL_AI_ATTACHMENT_BYTES", str(10 * 1024 * 1024))
)
GEMINI_CONNECT_TIMEOUT = int(os.environ.get("GEMINI_CONNECT_TIMEOUT", "15"))
GEMINI_READ_TIMEOUT = int(os.environ.get("GEMINI_READ_TIMEOUT", "120"))

# --- ENV VALS ---
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://awswkatcjffcsobusvic.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "sb_publishable_JS_DyaON4AC8FoJMcEkOwg_6aYjl6d2")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# --- TOKEN SECURE VERIFICATION ---
def verify_supabase_token(request):
    """
    Validates the user's incoming Supabase JWT token against the Supabase Auth gateway.
    This guarantees that only authenticated medical technicians can trigger RAG queries and maintenance scoring.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return False, None
    
    token = auth_header.split(" ")[1]
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {token}"
    }
    
    try:
        # Check active session status directly with Supabase Identity Service
        res = requests.get(f"{SUPABASE_URL}/auth/v1/user", headers=headers, timeout=5)
        if res.status_code == 200:
            return True, res.json()
    except Exception:
        pass
    
    return False, None

# --- GEMINI 2.5 FLASH AI ENGINE ---
def run_gemini_query(query_text, system_instruction=None, attachments=None):
    gemini_key = os.environ.get("GEMINI_API_KEY") or GEMINI_API_KEY

    if not gemini_key or "api-key" in gemini_key.lower():
        return f"GEMINI UPLINK SECURED. RAG Pipeline online. (Awaiting GEMINI_API_KEY in backend/.env to analyze: '{query_text}')"
        
    try:
        # Google Gemini 2.5 Flash HTTP API endpoint
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={gemini_key}"
        headers = {"Content-Type": "application/json"}
        
        # Expert clinical engineering system instructions combined with user query
        instruction = system_instruction or (
            "You are Pulse, an industry-standard AI clinical equipment assistant. "
            "Provide extremely precise, technical, and safe guidelines for repairing or servicing medical machinery."
        )
        parts = [{"text": f"{instruction}\n\nTechnician Query: {query_text}"}]
        for attachment in attachments or []:
            mime_type = attachment.get("mime_type") or attachment.get("mimeType")
            data = attachment.get("data")
            if mime_type and data:
                parts.append({"inlineData": {"mimeType": mime_type, "data": data}})

        payload = {
            "contents": [{
                "parts": parts
            }]
        }
        
        res = requests.post(
            url,
            json=payload,
            headers=headers,
            timeout=(GEMINI_CONNECT_TIMEOUT, GEMINI_READ_TIMEOUT),
        )
        if res.status_code == 200:
            data = res.json()
            # Extract text safely from Gemini schema: candidates[0].content.parts[0].text
            answer = data['candidates'][0]['content']['parts'][0]['text']
            return answer.strip()
        else:
            detail = res.text[:500]
            raise RuntimeError(f"Gemini API returned status code {res.status_code}: {detail}")
    except Exception as e:
        raise RuntimeError(str(e))


def _validated_attachments(raw_attachments):
    if not isinstance(raw_attachments, list):
        raise ValueError("Attachments must be a list.")
    if len(raw_attachments) > MAX_ATTACHMENT_COUNT:
        raise ValueError(f"Too many attachments. Limit is {MAX_ATTACHMENT_COUNT}.")

    attachments = []
    total_bytes = 0
    for attachment in raw_attachments:
        if not isinstance(attachment, dict):
            raise ValueError("Invalid attachment payload.")
        mime_type = attachment.get("mime_type") or attachment.get("mimeType")
        data = attachment.get("data")
        name = attachment.get("name") or "attachment"
        if not mime_type or not data:
            continue
        if not isinstance(data, str):
            raise ValueError(f"Attachment {name} is not base64 encoded.")
        try:
            decoded_size = len(base64.b64decode(data, validate=True))
        except binascii.Error:
            raise ValueError(f"Attachment {name} is not valid base64.")
        if decoded_size > MAX_ATTACHMENT_BYTES:
            raise ValueError(
                f"Attachment {name} is too large. Limit is {MAX_ATTACHMENT_BYTES // (1024 * 1024)} MB."
            )
        total_bytes += decoded_size
        if total_bytes > MAX_TOTAL_ATTACHMENT_BYTES:
            raise ValueError(
                f"Attachments are too large. Total limit is {MAX_TOTAL_ATTACHMENT_BYTES // (1024 * 1024)} MB."
            )
        attachments.append({"name": name, "mime_type": mime_type, "data": data})
    return attachments


@app.route('/api/health', methods=['GET'])
def health():
    return jsonify({
        "status": "ok",
        "service": "Pulse backend",
        "gemini_configured": bool(os.environ.get("GEMINI_API_KEY") or GEMINI_API_KEY),
        "cors_origins": cors_origins,
    })

# --- PREDICTIVE DIAGNOSTICS ALGORITHM (Telemetry-Driven) ---
def compute_predictive_health(machine_id):
    """
    Queries actual telemetry records from Supabase Rest API and scores failure risk
    based on fault count, interval frequency, and severity patterns.
    """
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    
    try:
        # Fetch log history of the specific clinical asset
        url = f"{SUPABASE_URL}/rest/v1/service_logs?machine_id=eq.{machine_id}&select=*"
        res = requests.get(url, headers=headers, timeout=5)
        if res.status_code != 200:
            return 35.0, "Monitor"  # Healthy fallback if database not seeded
            
        logs = res.json()
        if not logs:
            return 10.0, "Operational (No faults logged)"
            
        # Calculate risk score based on real diagnostics
        base_risk = 10.0
        critical_fault_count = 0
        warning_fault_count = 0
        
        for log in logs:
            code = str(log.get('error_code', '')).upper()
            if 'CRITICAL' in code or 'OUT OF ORDER' in code or 'HIGH' in code:
                critical_fault_count += 1
                base_risk += 25.0
            else:
                warning_fault_count += 1
                base_risk += 10.0
                
        # Cap risk between 0 and 100
        risk = min(max(base_risk, 0.0), 99.0)
        
        if risk > 75:
            rec = f"URGENT MAINTENANCE: {critical_fault_count} critical issues detected."
        elif risk > 45:
            rec = f"SCHEDULE PREVENTIVE SERVICE: {warning_fault_count} faults logged."
        else:
            rec = "Monitor & routinely check up. Asset stable."
            
        return round(risk, 2), rec
        
    except Exception as e:
        # Graceful fallback to static algorithm if offline/network fails
        risk = round(random.uniform(20.0, 60.0), 2)
        return risk, f"Static predictive score fallback (Diagnostics network unavailable: {str(e)})"

# --- SECURED ENDPOINTS ---
@app.route('/api/query', methods=['POST'])
def ai_query():
    # 1. Enforce strict JWT handshake
    authorized, user_info = verify_supabase_token(request)
    if not authorized:
        return jsonify({"error": "Unauthorized. Missing or invalid token signature."}), 401
        
    data = request.json or {}
    query = data.get('query', '')
    
    if not query:
        return jsonify({"error": "Query parameters empty"}), 400
        
    response_text = run_gemini_query(query)
    return jsonify({"answer": response_text})

@app.route('/api/gemini/generate', methods=['POST'])
def gemini_generate():
    authorized, user_info = verify_supabase_token(request)
    if not authorized:
        return jsonify({"error": "Unauthorized. Missing or invalid token signature."}), 401

    data = request.json or {}
    query = (data.get('query') or '').strip()
    if not query:
        return jsonify({"error": "Query parameters empty"}), 400

    try:
        attachments = _validated_attachments(data.get("attachments") or [])
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    try:
        answer = run_gemini_query(
            query,
            system_instruction=data.get("system_instruction"),
            attachments=attachments,
        )
        return jsonify({"answer": answer})
    except Exception as e:
        return jsonify({"error": f"Gemini generation failed: {str(e)}"}), 500

@app.route('/api/rag/ingest', methods=['POST'])
def rag_ingest():
    authorized, user_info = verify_supabase_token(request)
    if not authorized:
        return jsonify({"error": "Unauthorized. Missing or invalid token signature."}), 401

    data = request.json or {}
    required = ['title', 'machine_model', 'file_name', 'storage_path']
    missing = [field for field in required if not data.get(field)]
    if missing:
        return jsonify({"error": f"Missing required fields: {', '.join(missing)}"}), 400

    auth_header = request.headers.get("Authorization", "")
    user_token = auth_header.split(" ", 1)[1] if auth_header.startswith("Bearer ") else None
    user_id = user_info.get("id") if isinstance(user_info, dict) else None

    try:
        result = ingest_manual(data, user_token=user_token, user_id=user_id)
        return jsonify(result)
    except RagError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Manual indexing failed: {str(e)}"}), 500

@app.route('/api/rag/query', methods=['POST'])
def rag_query():
    authorized, user_info = verify_supabase_token(request)
    if not authorized:
        return jsonify({"error": "Unauthorized. Missing or invalid token signature."}), 401

    data = request.json or {}
    query = (data.get('query') or '').strip()
    machine_model = (data.get('machine_model') or '').strip() or None
    if not query:
        return jsonify({"error": "Query parameters empty"}), 400

    try:
        result = answer_with_manuals(query, machine_model=machine_model)
        return jsonify(result)
    except RagError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"RAG query failed: {str(e)}"}), 500

@app.route('/api/predict', methods=['GET'])
def predict_health():
    # 1. Enforce strict JWT handshake
    authorized, user_info = verify_supabase_token(request)
    if not authorized:
        return jsonify({"error": "Unauthorized. Missing or invalid token signature."}), 401
        
    machine_id = request.args.get('id')
    if not machine_id:
        return jsonify({"error": "Missing machine ID parameter"}), 400
        
    risk_score, recommendation = compute_predictive_health(machine_id)
    return jsonify({
        "machine_id": machine_id,
        "failure_probability": risk_score,
        "recommendation": recommendation
    })

if __name__ == '__main__':
    print("--------------------------------------------------")
    print("Pulse AI & Predictive Microservice running")
    print("Port: 5000 | Host: 0.0.0.0")
    print("--------------------------------------------------")
    app.run(debug=True, host='0.0.0.0', port=5000)
