from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from supabase import create_client, Client
from apscheduler.schedulers.asyncio import AsyncIOScheduler
import httpx
import asyncio
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, messaging

load_dotenv()

# ─────────────────────────────────────────────
#  APP SETUP
# ─────────────────────────────────────────────
app = FastAPI(title="CP Tracker API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────
#  SUPABASE CLIENT
# ─────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ─────────────────────────────────────────────
#  FIREBASE ADMIN INIT
#  📌 Download serviceAccountKey.json from:
#  Firebase Console → Project Settings → Service Accounts → Generate Key
# ─────────────────────────────────────────────
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# ─────────────────────────────────────────────
#  SCHEDULER (runs jobs automatically)
# ─────────────────────────────────────────────
scheduler = AsyncIOScheduler()

# ─────────────────────────────────────────────
#  HEALTH CHECK
# ─────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "CP Tracker Backend running ✅"}

@app.get("/ping")
def ping():
    return {"pong": True}

# ─────────────────────────────────────────────
#  SEND FCM NOTIFICATION
# ─────────────────────────────────────────────
def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict,
):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in data.items()},
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="contest_alerts",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                        category="CONTEST_24H",
                    )
                )
            ),
        )
        response = messaging.send(message)
        print(f"Notification sent: {response}")
        return True
    except Exception as e:
        print(f"FCM error: {e}")
        return False

# ─────────────────────────────────────────────
#  FETCH CODEFORCES CONTESTS
# ─────────────────────────────────────────────
async def fetch_cf_contests():
    async with httpx.AsyncClient() as client:
        res = await client.get("https://codeforces.com/api/contest.list")
        data = res.json()
        if data["status"] != "OK":
            return []

        contests = []
        for c in data["result"]:
            if c["phase"] == "BEFORE":  # upcoming only
                start_time = datetime.fromtimestamp(c["startTimeSeconds"])
                contests.append({
                    "platform":     "Codeforces",
                    "name":         c["name"],
                    "start_time":   start_time.isoformat(),
                    "duration_secs": c["durationSeconds"],
                    "url": f"https://codeforces.com/contest/{c['id']}",
                    "cf_id":        str(c["id"]),
                })
        return contests

# ─────────────────────────────────────────────
#  FETCH CODECHEF CONTESTS
# ─────────────────────────────────────────────
async def fetch_cc_contests():
    async with httpx.AsyncClient() as client:
        try:
            res  = await client.get(
                "https://www.codechef.com/api/list/contests/all",
                headers={"User-Agent": "Mozilla/5.0"},
            )
            data = res.json()
            contests = []
            for c in data.get("future_contests", []):
                contests.append({
                    "platform":   "Codechef",
                    "name":       c["contest_name"],
                    "start_time": c["contest_start_date_iso"],
                    "url": f"https://www.codechef.com/{c['contest_code']}",
                    "cf_id":      c["contest_code"],
                })
            return contests
        except Exception as e:
            print(f"CC fetch error: {e}")
            return []

# ─────────────────────────────────────────────
#  FETCH ATCODER CONTESTS
# ─────────────────────────────────────────────
async def fetch_at_contests():
    async with httpx.AsyncClient() as client:
        try:
            res  = await client.get(
                "https://atcoder-problems-api.vercel.app/v3/user/contests",
                headers={"User-Agent": "Mozilla/5.0"},
            )
            # AtCoder unofficial API
            data = res.json()
            contests = []
            now = datetime.utcnow()
            for c in data:
                start = datetime.fromisoformat(
                    c.get("start_epoch_second", 0))
                if start > now:
                    contests.append({
                        "platform":   "Atcoder",
                        "name":       c.get("title", ""),
                        "start_time": start.isoformat(),
                        "url": f"https://atcoder.jp/contests/{c.get('id','')}",
                        "cf_id":      c.get("id", ""),
                    })
            return contests
        except Exception as e:
            print(f"AT fetch error: {e}")
            return []

# ─────────────────────────────────────────────
#  SAVE CONTESTS TO SUPABASE
# ─────────────────────────────────────────────
async def save_contests_to_db(contests: list):
    for c in contests:
        try:
            supabase.table("upcoming_contests").upsert(
                c, on_conflict="platform,cf_id"
            ).execute()
        except Exception as e:
            print(f"Save contest error: {e}")

# ─────────────────────────────────────────────
#  CHECK AND SEND 24H NOTIFICATIONS
# ─────────────────────────────────────────────
async def send_24h_notifications():
    print("Checking 24h notifications...")
    now    = datetime.utcnow()
    in_24h = now + timedelta(hours=24)
    in_25h = now + timedelta(hours=25)

    # get contests starting in ~24 hours
    res = supabase.table("upcoming_contests")\
        .select("*")\
        .gte("start_time", in_24h.isoformat())\
        .lte("start_time", in_25h.isoformat())\
        .execute()

    contests = res.data or []
    if not contests:
        print("No contests in 24h window")
        return

    # get all users with FCM tokens
    users_res = supabase.table("profiles")\
        .select("id, fcm_token")\
        .not_.is_("fcm_token", "null")\
        .execute()

    users = users_res.data or []
    print(f"Sending 24h alerts to {len(users)} users for {len(contests)} contests")

    for contest in contests:
        contest_time = datetime.fromisoformat(contest["start_time"])
        for user in users:
            token = user.get("fcm_token")
            if not token:
                continue

            send_push_notification(
                fcm_token=token,
                title=f"📅 Contest Tomorrow!",
                body=f"{contest['name']} on {contest['platform']} starts in 24 hours!",
                data={
                    "type":         "24h",
                    "contest_id":   str(contest["id"]),
                    "contest_name": contest["name"],
                    "platform":     contest["platform"],
                    "contest_time": contest["start_time"],
                    "url":          contest.get("url", ""),
                },
            )

# ─────────────────────────────────────────────
#  FETCH ALL CONTESTS JOB (runs every hour)
# ─────────────────────────────────────────────
async def fetch_all_contests_job():
    print("Fetching all contests...")
    cf = await fetch_cf_contests()
    cc = await fetch_cc_contests()
    at = await fetch_at_contests()

    all_contests = cf + cc + at
    await save_contests_to_db(all_contests)
    print(f"Saved {len(all_contests)} contests to DB")

    # After fetching, check 24h notifications
    await send_24h_notifications()

# ─────────────────────────────────────────────
#  STARTUP — start scheduler
# ─────────────────────────────────────────────
@app.on_event("startup")
async def startup():
    # Fetch immediately on startup
    await fetch_all_contests_job()

    # Then every hour
    scheduler.add_job(
        fetch_all_contests_job,
        "interval",
        hours=1,
        id="fetch_contests",
    )
    scheduler.start()
    print("Scheduler started ✅")

@app.on_event("shutdown")
async def shutdown():
    scheduler.shutdown()

# ─────────────────────────────────────────────
#  MANUAL ENDPOINTS
# ─────────────────────────────────────────────
@app.get("/contests")
async def get_contests():
    """Get all upcoming contests from DB"""
    res = supabase.table("upcoming_contests")\
        .select("*")\
        .gte("start_time", datetime.utcnow().isoformat())\
        .order("start_time")\
        .execute()
    return {"contests": res.data}

@app.get("/fetch/contests/now")
async def fetch_now():
    """Manually trigger contest fetch"""
    await fetch_all_contests_job()
    return {"status": "Fetched and saved ✅"}

@app.get("/fetch/all/{user_id}")
async def fetch_user_stats(user_id: str):
    """Fetch CF/CC/AT stats for a user"""
    res = supabase.table("profiles")\
        .select("cf_handle, cc_handle, at_handle")\
        .eq("id", user_id)\
        .single()\
        .execute()

    if not res.data:
        raise HTTPException(status_code=404, detail="User not found")

    profile = res.data
    results = {}

    async with httpx.AsyncClient() as client:
        # Codeforces
        cf = profile.get("cf_handle", "")
        if cf:
            try:
                r = await client.get(
                    f"https://codeforces.com/api/user.info?handles={cf}")
                d = r.json()
                if d["status"] == "OK":
                    u = d["result"][0]
                    results["codeforces"] = {
                        "rating":     u.get("rating", 0),
                        "max_rating": u.get("maxRating", 0),
                        "rank":       u.get("rank", "unrated"),
                    }
                    supabase.table("user_stats").upsert({
                        "user_id":    user_id,
                        "platform":   "codeforces",
                        "handle":     cf,
                        "rating":     u.get("rating", 0),
                        "max_rating": u.get("maxRating", 0),
                        "rank":       u.get("rank", "unrated"),
                        "updated_at": datetime.utcnow().isoformat(),
                    }, on_conflict="user_id,platform").execute()
            except Exception as e:
                results["codeforces"] = {"error": str(e)}

        # Codechef
        cc = profile.get("cc_handle", "")
        if cc:
            try:
                r = await client.get(
                    f"https://codechef-api.vercel.app/handle/{cc}")
                d = r.json()
                results["codechef"] = {
                    "rating":     d.get("currentRating", 0),
                    "max_rating": d.get("highestRating", 0),
                    "stars":      d.get("stars", ""),
                }
                supabase.table("user_stats").upsert({
                    "user_id":    user_id,
                    "platform":   "codechef",
                    "handle":     cc,
                    "rating":     d.get("currentRating", 0),
                    "max_rating": d.get("highestRating", 0),
                    "rank":       d.get("stars", ""),
                    "updated_at": datetime.utcnow().isoformat(),
                }, on_conflict="user_id,platform").execute()
            except Exception as e:
                results["codechef"] = {"error": str(e)}

        # Atcoder
        at = profile.get("at_handle", "")
        if at:
            try:
                r = await client.get(
                    f"https://atcoder-api.vercel.app/users/{at}")
                d = r.json()
                results["atcoder"] = {
                    "rating":     d.get("Rating", 0),
                    "max_rating": d.get("HighestRating", 0),
                }
                supabase.table("user_stats").upsert({
                    "user_id":    user_id,
                    "platform":   "atcoder",
                    "handle":     at,
                    "rating":     d.get("Rating", 0),
                    "max_rating": d.get("HighestRating", 0),
                    "updated_at": datetime.utcnow().isoformat(),
                }, on_conflict="user_id,platform").execute()
            except Exception as e:
                results["atcoder"] = {"error": str(e)}

    return {"user_id": user_id, "stats": results}