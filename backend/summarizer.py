import os
from dotenv import load_dotenv
from google import genai

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None

def summarize_email(email_text):
    try:
        if not client:
            fallback = email_text[:80].strip().replace("\n", " ")
            return f"Normal: {fallback}..."

        prompt = f"Summarize this email in ONE short line (max 12 words) and classify as Important, Normal, or Ignore:\n\n{email_text[:1000]}"

        response = client.models.generate_content(
            model="gemini-1.5-flash",
            contents=prompt
        )

        return response.text.strip()

    except Exception as e:
        print("GEMINI ERROR:", e)
        fallback = email_text[:80].strip().replace("\n", " ")
        return f"Normal: {fallback}..."