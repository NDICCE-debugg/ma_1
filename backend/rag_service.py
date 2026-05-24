import io
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import requests

try:
    import fitz  # PyMuPDF
except ImportError:  # pragma: no cover - handled at runtime
    fitz = None


SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get(
    "SUPABASE_KEY", ""
)
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY") or os.environ.get("OPENAI_API_KEY")

MANUAL_BUCKET = os.environ.get("MANUAL_BUCKET", "manuals")
EMBEDDING_MODEL = os.environ.get("RAG_EMBEDDING_MODEL", "gemini-embedding-001")
EMBEDDING_DIMENSION = int(os.environ.get("RAG_EMBEDDING_DIMENSION", "768"))
GENERATION_MODEL = os.environ.get("RAG_GENERATION_MODEL", "gemini-2.5-flash")


class RagError(Exception):
    pass


@dataclass
class ManualChunk:
    text: str
    page_number: int
    chunk_index: int
    section_title: str
    token_count: int


def _supabase_headers(token: Optional[str] = None) -> Dict[str, str]:
    auth_token = token or SUPABASE_KEY
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {auth_token}",
        "Content-Type": "application/json",
    }


def _rest_url(path: str) -> str:
    if not SUPABASE_URL:
        raise RagError("SUPABASE_URL is not configured.")
    return f"{SUPABASE_URL}/rest/v1/{path.lstrip('/')}"


def _storage_url(bucket: str, path: str) -> str:
    if not SUPABASE_URL:
        raise RagError("SUPABASE_URL is not configured.")
    return f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path.lstrip('/')}"


def download_manual_pdf(storage_path: str, user_token: Optional[str] = None) -> bytes:
    response = requests.get(
        _storage_url(MANUAL_BUCKET, storage_path),
        headers=_supabase_headers(user_token if not os.environ.get("SUPABASE_SERVICE_ROLE_KEY") else None),
        timeout=30,
    )
    if response.status_code >= 400:
        raise RagError(f"Could not download PDF from Storage: {response.text}")
    return response.content


def extract_pdf_pages(pdf_bytes: bytes) -> List[Dict[str, Any]]:
    if fitz is None:
        raise RagError("PyMuPDF is not installed. Run: pip install -r backend/requirements.txt")

    pages: List[Dict[str, Any]] = []
    with fitz.open(stream=io.BytesIO(pdf_bytes), filetype="pdf") as doc:
        for page_index, page in enumerate(doc):
            text = page.get_text("text").strip()
            if text:
                pages.append({"page_number": page_index + 1, "text": normalize_text(text)})
    return pages


def normalize_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def estimate_tokens(text: str) -> int:
    return max(1, len(re.findall(r"\S+", text)))


def section_title_for(text: str) -> str:
    for line in text.splitlines():
        clean = line.strip()
        if 4 <= len(clean) <= 90 and not clean.endswith("."):
            return clean
    return "Manual excerpt"


def chunk_pages(
    pages: List[Dict[str, Any]],
    max_words: int = 650,
    overlap_words: int = 90,
) -> List[ManualChunk]:
    chunks: List[ManualChunk] = []
    chunk_index = 0

    for page in pages:
        page_number = int(page["page_number"])
        words = page["text"].split()
        if not words:
            continue

        start = 0
        while start < len(words):
            end = min(start + max_words, len(words))
            text = " ".join(words[start:end]).strip()
            if len(text) > 120:
                chunks.append(
                    ManualChunk(
                        text=text,
                        page_number=page_number,
                        chunk_index=chunk_index,
                        section_title=section_title_for(text),
                        token_count=estimate_tokens(text),
                    )
                )
                chunk_index += 1
            if end >= len(words):
                break
            start = max(0, end - overlap_words)

    return chunks


def gemini_embedding(text: str, task_type: str = "RETRIEVAL_DOCUMENT") -> List[float]:
    if not GEMINI_API_KEY:
        raise RagError("GEMINI_API_KEY is not configured in backend/.env.")

    url = (
        "https://generativelanguage.googleapis.com/v1beta/"
        f"models/{EMBEDDING_MODEL}:embedContent?key={GEMINI_API_KEY}"
    )
    payload = {
        "content": {"parts": [{"text": text[:16000]}]},
        "embedContentConfig": {
            "taskType": task_type,
            "outputDimensionality": EMBEDDING_DIMENSION,
        },
    }
    response = requests.post(url, json=payload, timeout=30)
    if response.status_code >= 400:
        raise RagError(f"Gemini embedding failed: {response.text}")

    data = response.json()
    values = data.get("embedding", {}).get("values")
    if not values and data.get("embeddings"):
        values = data["embeddings"][0].get("values")
    if not values:
        raise RagError("Gemini embedding response did not include values.")
    return values


def create_manual_record(metadata: Dict[str, Any], user_id: Optional[str]) -> Dict[str, Any]:
    body = {
        "title": metadata["title"],
        "machine_model": metadata["machine_model"],
        "category": metadata.get("category") or "Service Manual",
        "file_name": metadata["file_name"],
        "file_type": metadata.get("file_type") or "pdf",
        "file_size": metadata.get("file_size") or 0,
        "storage_bucket": MANUAL_BUCKET,
        "storage_path": metadata["storage_path"],
        "uploaded_by": user_id,
        "indexed_status": "indexing",
    }
    response = requests.post(
        _rest_url("manuals"),
        headers={**_supabase_headers(), "Prefer": "return=representation"},
        json=body,
        timeout=20,
    )
    if response.status_code >= 400:
        raise RagError(f"Could not create manual record: {response.text}")
    return response.json()[0]


def update_manual_status(
    manual_id: str,
    status: str,
    chunk_count: int = 0,
    error_message: Optional[str] = None,
) -> None:
    body: Dict[str, Any] = {
        "indexed_status": status,
        "chunk_count": chunk_count,
    }
    if status == "indexed":
        body["indexed_at"] = datetime.now(timezone.utc).isoformat()
    if error_message:
        body["error_message"] = error_message[:500]

    requests.patch(
        _rest_url(f"manuals?id=eq.{manual_id}"),
        headers=_supabase_headers(),
        json=body,
        timeout=20,
    )


def insert_chunks(
    manual_id: str,
    chunks: List[ManualChunk],
    metadata: Dict[str, Any],
) -> int:
    rows = []
    for chunk in chunks:
        embedding = gemini_embedding(
            retrieval_text(metadata, chunk.text),
            task_type="RETRIEVAL_DOCUMENT",
        )
        rows.append(
            {
                "manual_id": manual_id,
                "chunk_index": chunk.chunk_index,
                "chunk_text": chunk.text,
                "page_number": chunk.page_number,
                "section_title": chunk.section_title,
                "machine_model": metadata["machine_model"],
                "file_name": metadata["file_name"],
                "token_count": chunk.token_count,
                "embedding_model": EMBEDDING_MODEL,
                "embedding_dimension": EMBEDDING_DIMENSION,
                "embedding": embedding,
            }
        )

        if len(rows) == 25:
            _insert_chunk_batch(rows)
            rows = []

    if rows:
        _insert_chunk_batch(rows)

    return len(chunks)


def _insert_chunk_batch(rows: List[Dict[str, Any]]) -> None:
    response = requests.post(
        _rest_url("manual_chunks"),
        headers=_supabase_headers(),
        json=rows,
        timeout=60,
    )
    if response.status_code >= 400:
        raise RagError(f"Could not insert manual chunks: {response.text}")


def retrieval_text(metadata: Dict[str, Any], text: str) -> str:
    return (
        f"Manual title: {metadata['title']}\n"
        f"Machine model: {metadata['machine_model']}\n"
        f"Category: {metadata.get('category') or 'Service Manual'}\n"
        f"Content:\n{text}"
    )


def ingest_manual(metadata: Dict[str, Any], user_token: Optional[str], user_id: Optional[str]) -> Dict[str, Any]:
    manual = create_manual_record(metadata, user_id)
    manual_id = manual["id"]
    try:
        pdf_bytes = download_manual_pdf(metadata["storage_path"], user_token=user_token)
        pages = extract_pdf_pages(pdf_bytes)
        if not pages:
            raise RagError("No extractable text was found in this PDF.")
        chunks = chunk_pages(pages)
        if not chunks:
            raise RagError("PDF text was extracted, but no useful chunks were created.")
        chunk_count = insert_chunks(manual_id, chunks, metadata)
        update_manual_status(manual_id, "indexed", chunk_count=chunk_count)
        return {
            "manual_id": manual_id,
            "status": "indexed",
            "pages": len(pages),
            "chunks": chunk_count,
        }
    except Exception as exc:
        update_manual_status(manual_id, "failed", error_message=str(exc))
        raise


def match_chunks(query: str, machine_model: Optional[str], match_count: int = 8) -> List[Dict[str, Any]]:
    query_embedding = gemini_embedding(query, task_type="RETRIEVAL_QUERY")
    response = requests.post(
        _rest_url("rpc/match_manual_chunks"),
        headers=_supabase_headers(),
        json={
            "query_embedding": query_embedding,
            "match_threshold": 0.25,
            "match_count": match_count,
            "filter_model": machine_model,
        },
        timeout=30,
    )
    if response.status_code >= 400:
        raise RagError(f"Manual vector search failed: {response.text}")
    chunks = response.json()
    return rerank_keyword_matches(query, chunks)[:match_count]


def rerank_keyword_matches(query: str, chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    terms = set(re.findall(r"[A-Za-z0-9-]{3,}", query.lower()))

    def score(row: Dict[str, Any]) -> float:
        text = f"{row.get('chunk_text', '')} {row.get('title', '')}".lower()
        keyword_hits = sum(1 for term in terms if term in text)
        return float(row.get("similarity") or 0) + (keyword_hits * 0.035)

    return sorted(chunks, key=score, reverse=True)


def generate_grounded_answer(query: str, chunks: List[Dict[str, Any]]) -> str:
    if not chunks:
        return (
            "I could not find matching service manual context for this question. "
            "Check the correct machine model/manual is uploaded and indexed before using Pulse for this procedure."
        )

    context = "\n\n---\n\n".join(
        [
            (
                f"Source {index + 1}: {chunk.get('title')} | {chunk.get('file_name')} "
                f"| page {chunk.get('page_number') or 'N/A'}\n"
                f"{chunk.get('chunk_text')}"
            )
            for index, chunk in enumerate(chunks)
        ]
    )
    prompt = f"""
You are Pulse AI, a clinical engineering assistant for biomedical technicians.
Answer ONLY from the manual excerpts below when giving device-specific values,
steps, alarm meanings, calibration limits, or service instructions.

If the excerpts do not contain the requested specification or procedure, say
that the uploaded manuals do not contain enough evidence and give only safe
next checks. Do not invent manufacturer values.

Technician question:
{query}

Manual excerpts:
{context}

Respond with:
1. Direct answer
2. Safe procedure/checks
3. When to stop/escalate
4. Manual sources used with file name and page number
"""
    return run_gemini_generation(prompt)


def run_gemini_generation(prompt: str) -> str:
    if not GEMINI_API_KEY:
        raise RagError("GEMINI_API_KEY is not configured in backend/.env.")

    url = (
        "https://generativelanguage.googleapis.com/v1beta/"
        f"models/{GENERATION_MODEL}:generateContent?key={GEMINI_API_KEY}"
    )
    response = requests.post(
        url,
        headers={"Content-Type": "application/json"},
        json={"contents": [{"parts": [{"text": prompt}]}]},
        timeout=60,
    )
    if response.status_code >= 400:
        raise RagError(f"Gemini generation failed: {response.text}")
    data = response.json()
    return data["candidates"][0]["content"]["parts"][0]["text"].strip()


def answer_with_manuals(query: str, machine_model: Optional[str] = None) -> Dict[str, Any]:
    chunks = match_chunks(query, machine_model)
    answer = generate_grounded_answer(query, chunks)
    sources = [
        {
            "manual_id": chunk.get("manual_id"),
            "title": chunk.get("title"),
            "file_name": chunk.get("file_name"),
            "page_number": chunk.get("page_number"),
            "section_title": chunk.get("section_title"),
            "similarity": chunk.get("similarity"),
        }
        for chunk in chunks
    ]
    return {
        "answer": answer,
        "sources": sources,
        "context_count": len(chunks),
    }
