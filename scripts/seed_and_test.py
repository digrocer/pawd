#!/usr/bin/env python3
"""End-to-end backend verification + demo seeding for PAWD.

Creates real auth users, logs in to get JWTs, and exercises the full core loop
through PostgREST exactly as the app does (RLS enforced). Also seeds demo pets
around Accra so the discovery deck is populated.
"""
import os, json, urllib.request, urllib.error, sys, random

# Secrets come from the environment — never hard-code service keys in a repo.
#   SUPABASE_PROJECT_REF    (default: pawd project)
#   SUPABASE_ANON_KEY       anon/publishable key
#   SUPABASE_SERVICE_KEY    service_role key (admin ops + bypass RLS)
REF = os.environ.get("SUPABASE_PROJECT_REF", "vaeiskltcpzthaffyejg")
BASE = f"https://{REF}.supabase.co"
ANON = os.environ.get("SUPABASE_ANON_KEY")
SERVICE = os.environ.get("SUPABASE_SERVICE_KEY")
if not (ANON and SERVICE):
    raise SystemExit("Set SUPABASE_ANON_KEY and SUPABASE_SERVICE_KEY in the environment first.")

def req(method, path, token, body=None, base=BASE, extra=None):
    url = base + path
    data = json.dumps(body).encode() if body is not None else None
    headers = {"apikey": ANON, "Authorization": f"Bearer {token}",
               "Content-Type": "application/json", "User-Agent": "curl/8.0"}
    if extra: headers.update(extra)
    r = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r) as resp:
            txt = resp.read().decode()
            return resp.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

def admin_create_user(email, password):
    return req("POST", "/auth/v1/admin/users", SERVICE,
               {"email": email, "password": password, "email_confirm": True})

def login(email, password):
    s, b = req("POST", "/auth/v1/token?grant_type=password", ANON,
               {"email": email, "password": password})
    if s != 200: raise RuntimeError(f"login failed {s}: {b}")
    return b["access_token"], b["user"]["id"]

def ok(cond, msg):
    print(("  PASS " if cond else "  FAIL ") + msg)
    if not cond: FAILS.append(msg)

FAILS = []
PW = "pawd-Test-123!"

# ── Accra-area demo pets ────────────────────────────────────────
# (lat, lng, name, species, breed, sex, purposes, bio, temperament)
DEMO = [
    (5.6360, -0.1680, "Bruno",  "dog", "Boerboel",          "male",   ["playdates","walking"], "Big softie who loves the beach.", ["Gentle","Calm"]),
    (5.6500, -0.1500, "Lola",   "dog", "Golden Retriever",  "female", ["playdates","friends"], "Fetch fanatic. Will trade sticks for snacks.", ["Playful","Friendly"]),
    (5.6200, -0.1750, "Simba",  "cat", "Domestic Shorthair","male",   ["friends"],             "Rooftop explorer seeking chill feline friends.", ["Curious"]),
    (5.6100, -0.2000, "Ziggy",  "dog", "Mixed/Unknown",     "male",   ["walking","friends"],   "Rescue pup, endless energy for morning walks.", ["Energetic","Friendly"]),
    (5.6400, -0.1400, "Nala",   "dog", "German Shepherd",   "female", ["playdates","walking"], "Smart and loyal, loves obstacle courses.", ["Protective","Curious"]),
    (5.6300, -0.1900, "Coco",   "cat", "Persian",           "female", ["friends"],             "Fluffy diva. Naps then judges you.", ["Calm","Shy"]),
]

print("== Seeding demo pets near Accra ==")
seed_tokens = []
for i, d in enumerate(DEMO):
    email = f"demo{i+1}@pawd.test"
    admin_create_user(email, PW)  # ignore if exists
    try:
        tok, uid = login(email, PW)
    except RuntimeError as e:
        print("   login issue:", e); continue
    req("PATCH", f"/rest/v1/owners?id=eq.{uid}", tok,
        {"display_name": ["Ama","Kojo","Efua","Kwame","Akosua","Yaw"][i], "area": "Accra", "age_attested": True})
    req("POST", "/rest/v1/rpc/set_my_location", tok, {"p_lat": d[0], "p_lng": d[1]})
    req("DELETE", f"/rest/v1/pets?owner_id=eq.{uid}", tok)  # idempotent: one pet per seed
    s, b = req("POST", "/rest/v1/pets", tok, {
        "owner_id": uid, "name": d[2], "species": d[3], "breed": d[4], "sex": d[5],
        "purposes": d[6], "bio": d[7], "temperament": d[8], "energy_level": random.randint(2,5),
        "vaccination": "up_to_date",
    }, extra={"Prefer": "return=representation"})
    print(f"   seeded {d[2]:6} -> {s}")
    seed_tokens.append((tok, uid, d[2]))

# ── Core-loop verification with a tester user ───────────────────
print("\n== Core loop verification ==")
admin_create_user("tester@pawd.test", PW)
t_tok, t_uid = login("tester@pawd.test", PW)
req("PATCH", f"/rest/v1/owners?id=eq.{t_uid}", t_tok, {"display_name": "Tester", "area": "East Legon", "age_attested": True})
req("POST", "/rest/v1/rpc/set_my_location", t_tok, {"p_lat": 5.6355, "p_lng": -0.1670})
req("DELETE", f"/rest/v1/pets?owner_id=eq.{t_uid}", t_tok)  # idempotent
s, pet = req("POST", "/rest/v1/pets", t_tok, {
    "owner_id": t_uid, "name": "Rex", "species": "dog", "breed": "Labrador", "sex": "male",
    "purposes": ["playdates","walking","friends"], "bio": "Test dog", "energy_level": 4,
}, extra={"Prefer": "return=representation"})
tester_pet = pet[0]["id"]
ok(s == 201, f"create tester pet (status {s})")

# discovery deck
s, deck = req("POST", "/rest/v1/rpc/discovery_deck", t_tok, {"p_viewer_pet": tester_pet, "p_radius_km": 25})
ok(s == 200 and isinstance(deck, list) and len(deck) >= 3, f"discovery deck returned {len(deck) if isinstance(deck,list) else deck} pets")
if isinstance(deck, list) and deck:
    card = deck[0]
    ok("distance_km" in card and "primary_photo" in card, "deck card has distance + photo fields")
    ok(all(k not in card for k in ("location","lat","lng")), "deck card exposes NO raw coordinates")
    print("   nearest:", card["name"], card["distance_km"], "km,", card["breed"])

# location privacy: tester must NOT be able to read others' owner rows/location
s, others = req("GET", "/rest/v1/owners?select=id,location", t_tok)
ok(isinstance(others, list) and len(others) <= 1, f"RLS: tester can only see own owner row (saw {len(others) if isinstance(others,list) else others})")

# pick a seed pet, like it; then have that seed pet like back -> match
target = deck[0]
target_pet_id = target["pet_id"]
# find that seed's token
seed = next((st for st in seed_tokens if st[2] == target["name"]), None)
s, res = req("POST", "/rest/v1/rpc/record_swipe", t_tok,
             {"p_swiper_pet": tester_pet, "p_target_pet": target_pet_id, "p_direction": "like"})
ok(s == 200 and res.get("ok") and res.get("matched") == False, f"tester likes {target['name']} (no match yet)")

if seed:
    seed_tok, seed_uid, seed_name = seed
    # seed's pet id
    s, seed_pets = req("GET", f"/rest/v1/pets?owner_id=eq.{seed_uid}&select=id", seed_tok)
    seed_pet_id = seed_pets[0]["id"]
    s, res2 = req("POST", "/rest/v1/rpc/record_swipe", seed_tok,
                  {"p_swiper_pet": seed_pet_id, "p_target_pet": tester_pet, "p_direction": "like"})
    ok(s == 200 and res2.get("matched") == True, f"{seed_name} likes back -> MATCH created")

    # tester my_matches
    s, matches = req("POST", "/rest/v1/rpc/my_matches", t_tok, {})
    ok(s == 200 and len(matches) >= 1, f"tester my_matches shows {len(matches)} match")
    if matches:
        mid = matches[0]["match_id"]
        # send a message
        s, msg = req("POST", "/rest/v1/messages", t_tok,
                     {"match_id": mid, "sender_id": t_uid, "body": "Hi! Wanna set up a playdate?"},
                     extra={"Prefer": "return=representation"})
        ok(s == 201, f"tester sends message (status {s})")
        # seed can read the message (participant), a stranger cannot
        s, seed_view = req("GET", f"/rest/v1/messages?match_id=eq.{mid}&select=body", seed_tok)
        ok(isinstance(seed_view, list) and len(seed_view) == 1, "matched partner can read the message")
        stranger_tok = seed_tokens[-1][0] if seed_tokens[-1][2] != seed_name else seed_tokens[0][0]
        s, stranger_view = req("GET", f"/rest/v1/messages?match_id=eq.{mid}&select=body", stranger_tok)
        ok(isinstance(stranger_view, list) and len(stranger_view) == 0, "non-participant is BLOCKED from reading the chat")

# daily like limit sanity (limit param respected)
s, res3 = req("POST", "/rest/v1/rpc/record_swipe", t_tok,
              {"p_swiper_pet": tester_pet, "p_target_pet": deck[1]["pet_id"] if len(deck)>1 else target_pet_id,
               "p_direction": "like", "p_daily_like_limit": 0})
ok(s == 200 and res3.get("ok") == False and res3.get("error") == "daily_like_limit", "daily like limit is enforced")

print("\n== RESULT ==")
if FAILS:
    print(f"{len(FAILS)} checks FAILED:")
    for f in FAILS: print("  -", f)
    sys.exit(1)
print("All checks passed. Backend core loop verified end-to-end.")
