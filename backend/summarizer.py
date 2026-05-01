from openai import OpenAI
import os
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def summarize_email(email_text):
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "Summarize this email in ONE short line (max 12 words). Also classify as Important, Normal, or Ignore."
                },
                {
                    "role": "user",
                    "content": email_text[:1000]
                }
            ]
        )

        return response.choices[0].message.content.strip()

    except Exception as e:
        print("OPENAI ERROR:", e)
        fallback = email_text[:80].strip().replace("\n", " ")
        return f"Normal: {fallback}..."