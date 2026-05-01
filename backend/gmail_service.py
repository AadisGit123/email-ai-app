from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
import base64
from bs4 import BeautifulSoup
import html
import time
import os

CACHE = {
    "data": None,
    "timestamp": 0
}
CACHE_TTL = 30  # seconds

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']


def get_gmail_service():
    
    try:
        print("GOOGLE_TOKEN exists:", bool(os.environ.get("GOOGLE_TOKEN")))
        # Create token.json from ENV (Render-safe)
        if os.environ.get("GOOGLE_TOKEN"):
            with open("token.json", "w") as f:
                f.write(os.environ["GOOGLE_TOKEN"])

        if not os.path.exists("token.json"):
            print("token.json not found")
            return None

        creds = Credentials.from_authorized_user_file("token.json", SCOPES)
        return build('gmail', 'v1', credentials=creds)

    except Exception as e:
        print("Gmail service error:", e)
        return None


def extract_headers(msg_data):
    headers = msg_data.get('payload', {}).get('headers', [])
    subject = ""
    sender = ""

    for h in headers:
        if h['name'] == 'Subject':
            subject = h['value']
        elif h['name'] == 'From':
            sender = h['value']

    return subject, sender


def extract_body(payload):
    body_data = ""

    if 'parts' in payload:
        for part in payload['parts']:
            mime = part.get('mimeType', '')

            if mime == 'text/plain':
                return part['body'].get('data', '')
            elif mime == 'text/html':
                body_data = part['body'].get('data', '')

    return payload.get('body', {}).get('data', '') or body_data


def clean_email_text(raw_data):
    try:
        import quopri
        import html
        import re

        # Fix padding
        missing_padding = len(raw_data) % 4
        if missing_padding:
            raw_data += '=' * (4 - missing_padding)

        # Decode base64
        decoded_bytes = base64.urlsafe_b64decode(raw_data)

        # Handle quoted-printable encoding
        decoded_bytes = quopri.decodestring(decoded_bytes)

        # Decode to string
        decoded = decoded_bytes.decode('utf-8', errors='ignore')

        # Remove HTML tags
        soup = BeautifulSoup(decoded, "html.parser")

        # Remove scripts/styles (important)
        for tag in soup(["script", "style"]):
            tag.decompose()

        text = soup.get_text(separator=" ")

        # Decode HTML entities
        text = html.unescape(text)

        # Remove URLs
        text = re.sub(r'http\S+', '', text)

        # Remove email signatures (common patterns)
        text = re.split(r'(--|Regards,|Thanks,|Best,)', text)[0]

        # Remove excessive special characters
        text = re.sub(r'[^\w\s.,!?₹$@-]', ' ', text)

        # Normalize whitespace
        text = " ".join(text.split())

        # Remove repetitive words (basic cleanup)
        words = text.split()
        cleaned_words = []
        for w in words:
            if len(cleaned_words) == 0 or w != cleaned_words[-1]:
                cleaned_words.append(w)

        text = " ".join(cleaned_words)

        return text[:400]

    except Exception:
        return ""


def fetch_emails(page_token=None, max_results=30):
    try:
        # Return cached data if recent
        if CACHE["data"] and time.time() - CACHE["timestamp"] < CACHE_TTL:
            print("Returning cached emails...")
            return CACHE["data"]

        service = get_gmail_service()
        if not service:
            return {"emails": [], "nextPageToken": None}

        results = service.users().messages().list(
            userId='me',
            maxResults=max_results,
            pageToken=page_token
        ).execute()

        messages = results.get('messages', [])
        next_page_token = results.get('nextPageToken')

        emails = []
        print("Fetching emails from Gmail API...")

        for msg in messages:
            msg_data = service.users().messages().get(userId='me', id=msg['id']).execute()

            subject, sender = extract_headers(msg_data)
            payload = msg_data.get('payload', {})

            body_data = extract_body(payload)
            if not body_data:
                continue

            cleaned = clean_email_text(body_data)

            if len(cleaned) < 20 or "unsubscribe" in cleaned.lower():
                continue

            priority = "Normal"
            category = "General"
            is_spam = False

            text_lower = (subject + " " + cleaned).lower()

            if any(word in text_lower for word in ["urgent", "asap", "important", "deadline", "exam"]):
                priority = "Important"

            if any(word in text_lower for word in ["sale", "offer", "discount", "unsubscribe", "win", "free"]):
                category = "Promotions"
                is_spam = True
            elif any(word in text_lower for word in ["order", "account", "login", "security", "alert"]):
                category = "Updates"
            elif any(word in text_lower for word in ["friend", "follow", "like", "comment"]):
                category = "Social"

            emails.append({
                "subject": subject,
                "sender": sender,
                "body": cleaned,
                "priority": priority,
                "category": category,
                "spam": is_spam
            })

        result = {
            "emails": emails,
            "nextPageToken": next_page_token
        }

        CACHE["data"] = result
        CACHE["timestamp"] = time.time()

        return result

    except Exception as e:
        print("Fetch emails error:", e)
        return {"emails": [], "nextPageToken": None}

# ---------- GEMINI AI FEATURES ----------

from google import genai

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None


def generate_ai_reply(email_text):
    try:
        if not client:
            return "AI not configured"
        prompt = f"Write a short polite reply to this email:\n{email_text[:500]}"
        response = client.models.generate_content(
            model="gemini-1.5-flash",
            contents=prompt
        )
        return response.text.strip()
    except Exception as e:
        print("Gemini Reply Error:", e)
        return "Could not generate reply."


def summarize_inbox(emails):
    try:
        if not client:
            return "AI not configured"
        combined = " ".join([e.get("body", "") for e in emails[:20]])

        prompt = f"""
        Summarize this inbox:
        - Count important emails 
        - Count promotions
        - Highlight key actions

        {combined[:2000]}
        """

        response = client.models.generate_content(
            model="gemini-1.5-flash",
            contents=prompt
        )
        return response.text.strip()
    except Exception as e:
        print("Gemini Summary Error:", e)
        return "Could not generate summary."