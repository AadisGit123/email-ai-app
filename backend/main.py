from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from gmail_service import fetch_emails
from summarizer import summarize_email
from gmail_service import generate_ai_reply, summarize_inbox
from fastapi import Request

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi import FastAPI, Query

@app.get("/emails")
def get_summaries(page_token: str = Query(None)):
    data = fetch_emails(page_token=page_token)

    emails = data["emails"]
    next_token = data["nextPageToken"]

    results = []

    for email in emails:
        summary_text = summarize_email(email["body"])

        priority = "Normal"
        clean_summary = summary_text

        if ":" in summary_text:
            parts = summary_text.split(":", 1)
            possible_priority = parts[0].strip().capitalize()

            if possible_priority in ["Important", "Normal", "Ignore"]:
                priority = possible_priority
                clean_summary = parts[1].strip()

        results.append({
            "sender": email["sender"],
            "subject": email["subject"],
            "summary": clean_summary,
            "priority": priority
        })

    return {
        "emails": results,
        "nextPageToken": next_token
    }


@app.get("/test")
def test():
    return fetch_emails()


# AI reply endpoint
@app.post("/reply")
async def generate_reply(request: Request):
    data = await request.json()
    email_text = data.get("text", "")

    reply = generate_ai_reply(email_text)

    return {
        "reply": reply
    }


# Inbox summary endpoint
@app.get("/summary")
def inbox_summary():
    data = fetch_emails()
    emails = data["emails"]

    summary = summarize_inbox(emails)

    return {
        "summary": summary
    }