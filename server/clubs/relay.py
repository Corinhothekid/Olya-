"""PolyLax Clubs private-room relay. Run behind an HTTPS reverse proxy."""

import argparse
from collections import defaultdict, deque
from contextlib import contextmanager
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
from pathlib import Path
import re
import secrets
import sqlite3
from threading import Lock
import time


MAX_BODY = 65_536
MAX_INPUTS = 96
INPUT_PAGE = 24
MAX_SEQUENCE = 2**53 - 1
PRESENCE_SECONDS = 12
CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
STAGES = {"highSchool", "college", "professional"}
POSITION_NAMES = {
    "attack": 1, "a": 1, "att": 1, "midfield": 2, "mid": 2, "m": 2,
    "defense": 3, "d": 3, "dpole": 3, "faceoff": 4, "f": 4, "fo": 4, "fogo": 4,
    "goalie": 5, "g": 5,
    "lsm": 6, "longstickmid": 6, "longstickmidfield": 6,
    "ssdm": 7, "shortstickdefmid": 7,
}
POSITION_SLOTS = {
    1: (1, 2, 3), 2: (5, 6, 4), 3: (7, 8, 9), 4: (4,),
    5: (10,), 6: (5, 6), 7: (6, 5),
}
APPEARANCE_CAPS = {
    "FACE": 4, "HAIR": 6, "BEARD": 6, "BODY": 4, "HELMET": 11,
    "GLOVES": 6, "SHORTS": 6, "CLEATS": 6, "STICK": 6, "NUMBER": 100,
    "SLEEVES": 8, "HOODIE": 4, "HEIGHT": 19,
}

SCHEMA = """
CREATE TABLE IF NOT EXISTS rooms (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    team TEXT NOT NULL,
    stage TEXT NOT NULL,
    host_id TEXT NOT NULL,
    phase TEXT NOT NULL DEFAULT 'lobby',
    match_id TEXT,
    snapshot TEXT,
    snapshot_seq INTEGER NOT NULL DEFAULT -1,
    result TEXT,
    last_result TEXT,
    reopened_match_id TEXT,
    revision INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS members (
    id TEXT PRIMARY KEY,
    room TEXT NOT NULL REFERENCES rooms(code) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    profile TEXT NOT NULL,
    position INTEGER NOT NULL,
    slot INTEGER NOT NULL DEFAULT 0,
    ready INTEGER NOT NULL DEFAULT 0,
    last_seen REAL NOT NULL,
    last_input INTEGER NOT NULL DEFAULT -1
);
CREATE INDEX IF NOT EXISTS members_room ON members(room);
CREATE TABLE IF NOT EXISTS inputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room TEXT NOT NULL REFERENCES rooms(code) ON DELETE CASCADE,
    member TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    body TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS inputs_room ON inputs(room, id);
"""


class RelayError(Exception):
    def __init__(self, status, code, message):
        super().__init__(message)
        self.status = status
        self.code = code


def invalid(message):
    raise RelayError(400, "invalid_request", message)


def conflict(message):
    raise RelayError(409, "conflict", message)


def encode(data):
    return json.dumps(data, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def safe_text(value, name, limit):
    if not isinstance(value, str):
        invalid(f"{name} is required")
    value = value.strip()
    if not value or len(value) > limit or any(ord(char) < 32 or ord(char) == 127 for char in value):
        invalid(f"{name} must contain between 1 and {limit} printable characters")
    try:
        value.encode("utf-8")
    except UnicodeError:
        invalid(f"{name} must be valid Unicode")
    return value


def safe_int(value, name, lo, hi):
    if type(value) not in (int, float) or not lo <= value <= hi or int(value) != value:
        invalid(f"{name} is out of range")
    return int(value)


def safe_object(value, name):
    if not isinstance(value, dict):
        invalid(f"{name} must be an object")
    return value


def profile_data(raw):
    raw = safe_object(raw, "profile")
    pos = raw.get("position")
    if isinstance(pos, str):
        pos = POSITION_NAMES.get(re.sub("[^a-z]", "", pos.lower()))
    position = safe_int(pos, "position", 1, 7)
    name = safe_text(raw.get("name"), "Player name", 42)
    profile_id = safe_text(raw.get("id"), "Profile ID", 72)
    number = safe_int(raw.get("number", 0), "number", 0, 99)
    appearance = safe_object(raw.get("appearance", {}), "appearance")
    appearance = {key: safe_int(value, key, 1, APPEARANCE_CAPS[key])
                  for key, value in appearance.items() if key in APPEARANCE_CAPS}
    appearance["NUMBER"] = number + 1
    attributes = safe_object(raw.get("attributes", {}), "attributes")
    if len(attributes) > 40:
        invalid("Too many attributes")
    attributes = {key: safe_int(value, key, 0, 99) for key, value in attributes.items()
                  if re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,32}", key)}
    return {"id": profile_id, "name": name, "position": position, "number": number,
            "appearance": appearance, "attributes": attributes}


def bounded_json(value, depth=0):
    """Reject a narrow class of invalid or excessive values before forwarding."""
    if depth > 14:
        return False
    if isinstance(value, dict):
        return len(value) <= 300 and all(len(key) <= 72 and bounded_json(child, depth + 1)
                                         for key, child in value.items())
    if isinstance(value, list):
        return len(value) <= 300 and all(bounded_json(child, depth + 1) for child in value)
    if type(value) is float:
        return math.isfinite(value) and abs(value) <= MAX_SEQUENCE
    if type(value) is int:
        return abs(value) <= MAX_SEQUENCE
    if isinstance(value, str):
        return len(value) <= 2048
    return value is None or isinstance(value, bool)


def decode_body(body):
    try:
        value = json.loads(body)
        if not bounded_json(value):
            invalid("JSON exceeds relay limits")
        encode(value).encode("utf-8")
    except (UnicodeError, ValueError, RecursionError):
        invalid("Request must contain valid UTF-8 JSON")
    return safe_object(value, "Request")


def input_data(raw):
    raw = safe_object(raw, "input")
    seq = safe_int(raw.get("seq"), "input sequence", 0, MAX_SEQUENCE)
    x, z = raw.get("x", 0), raw.get("z", 0)
    if any(type(axis) not in (int, float) or not -1 <= axis <= 1 for axis in (x, z)):
        invalid("Movement axes must be between -1 and 1")
    sprint = raw.get("sprint", False)
    actions = raw.get("actions", [])
    # Empty Lua tables may encode as an object. Both encodings mean no actions.
    if actions == {}:
        actions = []
    if not isinstance(sprint, bool) or not isinstance(actions, list) or len(actions) > 12:
        invalid("Invalid sprint or action queue")
    if any(not isinstance(action, dict) or len(encode(action)) > 700 for action in actions):
        invalid("Invalid action")
    return {"seq": seq, "x": x, "z": z, "sprint": sprint, "actions": actions}


def room_code():
    return "".join(secrets.choice(CODE_ALPHABET) for _ in range(8))


def identity():
    return secrets.token_hex(12)


def token_hash(value):
    return hashlib.sha256(value.encode("ascii")).hexdigest()


def find_slots(members):
    """Find distinct match slots while keeping the requested lacrosse positions."""
    if sum(member["position"] == 6 for member in members) > 1:
        conflict("One long-stick midfielder can join this lineup")
    lineup = {}

    def find(member, visited):
        for slot in POSITION_SLOTS[member["position"]]:
            if slot in visited:
                continue
            visited.add(slot)
            other = lineup.get(slot)
            if not other or find(other, visited):
                lineup[slot] = member
                return True
        return False

    for member in reversed(members):
        if not find(member, set()):
            conflict("No match slot is available for that position")
    return {member["id"]: slot for slot, member in lineup.items()}


class Relay:
    def __init__(self, database):
        self.database = database
        with self.transaction() as db:
            db.executescript(SCHEMA)
        # Old databases retain their room codes, token digests and members.
        # executescript commits, so acquire a fresh write transaction for migration.
        with self.transaction() as db:
            columns = {column["name"] for column in db.execute("PRAGMA table_info(rooms)")}
            if "last_result" not in columns:
                db.execute("ALTER TABLE rooms ADD COLUMN last_result TEXT")
                db.execute("UPDATE rooms SET last_result=result WHERE phase='final' AND result IS NOT NULL")
            if "reopened_match_id" not in columns:
                db.execute("ALTER TABLE rooms ADD COLUMN reopened_match_id TEXT")
            if "revision" not in columns:
                db.execute("ALTER TABLE rooms ADD COLUMN revision INTEGER NOT NULL DEFAULT 0")

    @contextmanager
    def transaction(self):
        db = sqlite3.connect(self.database, isolation_level=None, timeout=5)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        try:
            db.execute("BEGIN IMMEDIATE")
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    def room(self, db, code):
        room = db.execute("SELECT * FROM rooms WHERE code=?", (code,)).fetchone()
        if not room:
            raise RelayError(404, "room_not_found", "That invitation code does not identify an active room")
        return room

    def members(self, db, code):
        return db.execute("SELECT * FROM members WHERE room=? ORDER BY rowid", (code,)).fetchall()

    def lobby(self, db, code):
        room = self.room(db, code)
        recent = time.time() - PRESENCE_SECONDS
        players = [{"id": member["id"], "slot": member["slot"], "ready": bool(member["ready"]),
                    "connected": member["last_seen"] >= recent, "profile": json.loads(member["profile"])}
                   for member in self.members(db, code)]
        return {
            "code": code, "name": room["name"], "team": json.loads(room["team"]), "stage": room["stage"],
            "phase": room["phase"], "hostId": room["host_id"], "players": players,
            "matchId": room["match_id"], "result": json.loads(room["result"]) if room["result"] else None,
            "lastResult": json.loads(room["last_result"]) if room["last_result"] else None,
            "revision": room["revision"],
        }

    def new_member(self, db, code, player_id, profile):
        token = secrets.token_urlsafe(32)
        db.execute("INSERT INTO members(id,room,token_hash,profile,position,last_seen) VALUES(?,?,?,?,?,?)",
                   (player_id, code, token_hash(token), encode(profile), profile["position"], time.time()))
        for member_id, slot in find_slots(self.members(db, code)).items():
            db.execute("UPDATE members SET slot=? WHERE id=?", (slot, member_id))
        return {"token": token, "playerId": player_id, "roomCode": code}

    def create(self, db, data):
        name = safe_text(data.get("name"), "Club name", 42)
        stage = data.get("stage", "highSchool")
        if not isinstance(stage, str) or stage not in STAGES:
            invalid("Invalid career stage")
        team = data.get("team", "briarbank")
        if stage == "professional":
            team = safe_int(team, "team", 1, 8)
        elif not isinstance(team, str) or not re.fullmatch(r"[a-z0-9_-]{1,24}", team):
            invalid("Invalid school identifier")
        profile = profile_data(data.get("profile"))
        for _ in range(10):
            code = room_code()
            if not db.execute("SELECT 1 FROM rooms WHERE code=?", (code,)).fetchone():
                break
        else:
            raise RelayError(503, "unavailable", "Could not allocate a room code")
        player_id = identity()
        db.execute("INSERT INTO rooms(code,name,team,stage,host_id) VALUES(?,?,?,?,?)",
                   (code, name, encode(team), stage, player_id))
        session = self.new_member(db, code, player_id, profile)
        return {"lobby": self.lobby(db, code), "session": session, "inputSeq": -1}

    def join(self, db, data):
        code = safe_text(data.get("roomCode"), "Invitation code", 12).upper()
        profile = profile_data(data.get("profile"))
        room = self.room(db, code)
        if room["phase"] != "lobby":
            conflict("This match has already started")
        members = self.members(db, code)
        if len(members) >= 10:
            conflict("This club lobby is full")
        if any(json.loads(member["profile"])["id"] == profile["id"] for member in members):
            conflict("This player already belongs to the room. Resume with the saved session")
        session = self.new_member(db, code, identity(), profile)
        return {"lobby": self.lobby(db, code), "session": session, "inputSeq": -1}

    def authenticate(self, db, auth):
        match = re.fullmatch(r"Bearer ([A-Za-z0-9_-]{43})", auth or "", re.IGNORECASE)
        if not match:
            raise RelayError(401, "unauthorized", "A saved room session is required")
        token = match.group(1)
        member = db.execute("SELECT * FROM members WHERE token_hash=?", (token_hash(token),)).fetchone()
        if not member:
            raise RelayError(401, "unauthorized", "That room session is no longer valid")
        db.execute("UPDATE members SET last_seen=? WHERE id=?", (time.time(), member["id"]))
        return member, self.room(db, member["room"]), token

    def host_only(self, member, room):
        if member["id"] != room["host_id"]:
            raise RelayError(403, "host_required", "Only the host may do that")

    def update_profile(self, db, member, room, raw):
        profile = profile_data(raw)
        previous = json.loads(member["profile"])
        if profile["id"] != previous["id"]:
            conflict("The profile ID does not match this member")
        if profile == previous:
            return
        if room["phase"] == "match":
            conflict("Player changes apply after the match")
        members = [dict(item) for item in self.members(db, room["code"])]
        next_member = next(item for item in members if item["id"] == member["id"])
        next_member["position"] = profile["position"]
        slots = find_slots(members)
        db.execute("UPDATE members SET profile=?,position=?,ready=0 WHERE id=?",
                   (encode(profile), profile["position"], member["id"]))
        for item in members:
            slot = slots[item["id"]]
            if slot != item["slot"]:
                db.execute("UPDATE members SET slot=?,ready=0 WHERE id=?", (slot, item["id"]))

    def reopen(self, db, data, member, room):
        self.host_only(member, room)
        match_id = safe_text(data.get("matchId"), "Match ID", 72)
        abandon = data.get("abandon", False)
        if not isinstance(abandon, bool):
            invalid("abandon must be true or false")
        code = room["code"]
        if room["phase"] == "lobby" and match_id == room["reopened_match_id"]:
            return {"lobby": self.lobby(db, code), "inputSeq": -1}
        if match_id != room["match_id"]:
            conflict("The lobby has moved on to another match")
        if room["phase"] == "match" and not abandon:
            conflict("Finish or abandon the current match before reopening")
        db.execute("""UPDATE rooms SET phase='lobby',match_id=NULL,snapshot=NULL,snapshot_seq=-1,
                   result=NULL,reopened_match_id=?,revision=revision+1 WHERE code=?""", (match_id, code))
        db.execute("UPDATE members SET ready=0,last_input=-1 WHERE room=?", (code,))
        db.execute("DELETE FROM inputs WHERE room=?", (code,))
        return {"lobby": self.lobby(db, code), "inputSeq": -1}

    def sync(self, db, data, member, room):
        code = room["code"]
        host = member["id"] == room["host_id"]
        snapshot = data.get("snapshot")
        raw_input = data.get("input")
        if snapshot is not None:
            self.host_only(member, room)
            snapshot = safe_object(snapshot, "snapshot")
        match_id = data.get("matchId")
        if match_id is None and snapshot is not None:
            match_id = snapshot.get("matchId")
        if match_id is not None and match_id != room["match_id"]:
            conflict("This request is for a different match")
        if room["revision"] > 0 and room["phase"] == "match" and match_id is None and (
            raw_input is not None or snapshot is not None
        ):
            conflict("A match ID is required after the lobby reopens")

        committed_snapshot = False
        if snapshot is not None:
            if room["phase"] != "match":
                conflict("Snapshots are accepted only during a match")
            seq = safe_int(snapshot.get("seq"), "snapshot sequence", 0, MAX_SEQUENCE)
            if snapshot.get("matchId", room["match_id"]) != room["match_id"]:
                conflict("Snapshot is for a different match")
            if seq > room["snapshot_seq"]:
                db.execute("UPDATE rooms SET snapshot=?, snapshot_seq=? WHERE code=?", (encode(snapshot), seq, code))
                committed_snapshot = True
                room = self.room(db, code)

        last_input = member["last_input"]
        # A guest may send one last in-flight input before seeing the final.
        if raw_input is not None and room["phase"] != "final":
            if room["phase"] != "match":
                conflict("Inputs are accepted only during a match")
            sample = input_data(raw_input)
            if sample["seq"] > last_input:
                if not host:
                    pending = db.execute("SELECT count(*) FROM inputs WHERE room=?", (code,)).fetchone()[0]
                    if pending >= MAX_INPUTS:
                        raise RelayError(429, "host_behind", "The host is not collecting new inputs")
                    db.execute("INSERT INTO inputs(room,member,body) VALUES(?,?,?)", (code, member["id"], encode(sample)))
                last_input = sample["seq"]
                db.execute("UPDATE members SET last_input=? WHERE id=?", (last_input, member["id"]))

        feed = []
        if host and room["phase"] == "match":
            after = safe_int(data.get("after", 0), "input acknowledgement", 0, MAX_SEQUENCE)
            if committed_snapshot:
                # Checkpoint the world and acknowledge inputs in the same transaction.
                db.execute("DELETE FROM inputs WHERE room=? AND id<=?", (code, after))
            rows = db.execute("""SELECT inputs.id, member, body, slot FROM inputs JOIN members
                               ON members.id=inputs.member WHERE inputs.room=? AND inputs.id>?
                               ORDER BY inputs.id LIMIT ?""", (code, after, INPUT_PAGE))
            feed = [{"id": row["id"], "playerId": row["member"], "slot": row["slot"], "input": json.loads(row["body"])}
                    for row in rows]
        response = {"lobby": self.lobby(db, code), "inputs": feed, "inputSeq": last_input}
        if room["snapshot"]:
            response["snapshot"] = json.loads(room["snapshot"])
        return response

    def authenticated(self, db, action, data, member, room, token):
        code = room["code"]
        if action == "sync":
            return self.sync(db, data, member, room)
        if action == "resume":
            profile_error = None
            if "profile" in data:
                try:
                    self.update_profile(db, member, room, data["profile"])
                except RelayError as error:
                    profile_error = str(error)
            state = self.sync(db, {}, member, room)
            state["session"] = {"roomCode": code, "playerId": member["id"], "token": token}
            if profile_error:
                state["profileError"] = profile_error
            return state
        if action == "reopen":
            return self.reopen(db, data, member, room)
        if action in ("start", "ready") and "revision" in data:
            revision = safe_int(data["revision"], "lobby revision", 0, MAX_SEQUENCE)
            if revision != room["revision"]:
                conflict("This lobby has changed. Refresh and try again")
        if action == "ready":
            ready = data.get("ready")
            if not isinstance(ready, bool):
                invalid("ready must be true or false")
            if room["phase"] != "lobby":
                conflict("Ready status can change only before a match")
            db.execute("UPDATE members SET ready=? WHERE id=?", (ready, member["id"]))
        elif action == "start":
            self.host_only(member, room)
            if room["phase"] == "lobby":
                members = self.members(db, code)
                if len(members) != 2:
                    conflict("The first match prototype requires exactly two human players")
                cutoff = time.time() - PRESENCE_SECONDS
                if not all(item["ready"] and item["last_seen"] >= cutoff for item in members):
                    conflict("Every player must be connected and ready")
                db.execute("UPDATE rooms SET phase='match',match_id=? WHERE code=?", (identity(), code))
            elif room["phase"] != "match":
                conflict("This room already completed its match")
        elif action == "finish":
            self.host_only(member, room)
            result = safe_object(data.get("result"), "result")
            if result.get("matchId") != room["match_id"] or room["match_id"] is None:
                conflict("Result is for a different match")
            if room["phase"] == "final":
                if json.loads(room["result"]) != result:
                    conflict("This match cannot accept a new result")
                return {"lobby": self.lobby(db, code)}
            for side in ("homeScore", "awayScore"):
                safe_int(result.get(side), side, 0, 999)
            stats = safe_object(result.get("stats"), "stats")
            members = {item["id"] for item in self.members(db, code)}
            if set(stats) != members or any(not isinstance(line, dict) for line in stats.values()):
                invalid("Result statistics must include each club member")
            snapshot = json.loads(room["snapshot"]) if room["snapshot"] else {}
            if room["phase"] != "match" or snapshot.get("phase") != "FINAL" or (
                snapshot.get("matchId") != room["match_id"]
                or any(snapshot.get(side) != result[side] for side in ("homeScore", "awayScore"))
            ):
                conflict("Send the final match snapshot before recording results")
            final = encode(result)
            db.execute("UPDATE rooms SET phase='final',result=?,last_result=? WHERE code=?", (final, final, code))
            db.execute("DELETE FROM inputs WHERE room=?", (code,))
        elif action == "leave":
            withdraw = data.get("withdraw", False)
            if not isinstance(withdraw, bool):
                invalid("withdraw must be true or false")
            if withdraw:
                if member["id"] == room["host_id"] or room["phase"] == "match":
                    conflict("This membership cannot be withdrawn now")
                db.execute("DELETE FROM members WHERE id=?", (member["id"],))
                return {"left": True}
            db.execute("UPDATE members SET last_seen=0,ready=0 WHERE id=?", (member["id"],))
            if room["phase"] == "match":
                return {"left": False, "disconnected": True, "lobby": self.lobby(db, code)}
            return {"left": True}
        return {"lobby": self.lobby(db, code)}

    def handle(self, action, data, auth):
        with self.transaction() as db:
            if action == "create":
                return self.create(db, data)
            if action == "join":
                return self.join(db, data)
            member, room, token = self.authenticate(db, auth)
            return self.authenticated(db, action, data, member, room, token)


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, database):
        self.relay = Relay(database)
        self.bootstrap = defaultdict(deque)
        self.limit_lock = Lock()
        super().__init__(address, Handler)

    def allow_bootstrap(self, source):
        now = time.monotonic()
        with self.limit_lock:
            expired = [ip for ip, hits in self.bootstrap.items() if now - hits[-1] >= 60]
            for ip in expired:
                del self.bootstrap[ip]
            hits = self.bootstrap[source]
            while hits and now - hits[0] >= 60:
                hits.popleft()
            if len(hits) >= 60:
                return False
            hits.append(now)
            return True


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        self.request.settimeout(8)
        super().setup()

    def reply(self, status, data):
        body = encode(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True, "protocol": 1})
        else:
            self.reply(404, {"code": "not_found", "error": "Unknown endpoint", "message": "Unknown endpoint"})

    def do_POST(self):
        route = re.fullmatch(r"/v1/(create|join|resume|ready|start|leave|sync|finish|reopen)", self.path)
        if not route:
            self.reply(404, {"code": "not_found", "error": "Unknown endpoint", "message": "Unknown endpoint"})
            return
        action = route.group(1)
        try:
            if action in ("create", "join") and not self.server.allow_bootstrap(self.client_address[0]):
                raise RelayError(429, "rate_limited", "Try creating or joining later")
            raw_length = self.headers.get("Content-Length", "")
            if not raw_length.isascii() or not raw_length.isdecimal() or len(raw_length) > 6:
                invalid("Content-Length is required")
            length = int(raw_length)
            if length > MAX_BODY:
                raise RelayError(413, "too_large", "The message exceeds the relay limit")
            body = self.rfile.read(length)
            data = decode_body(body)
            result = self.server.relay.handle(action, data, self.headers.get("Authorization"))
            self.reply(200, result)
        except RelayError as error:
            message = str(error)
            self.reply(error.status, {"code": error.code, "error": message, "message": message})
        except sqlite3.OperationalError:
            message = "The relay is temporarily unavailable"
            self.reply(503, {"code": "database_unavailable", "error": message, "message": message})


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--listen", default="127.0.0.1")
    cli.add_argument("--port", type=int, default=8765)
    cli.add_argument("--database", type=Path, default=Path("clubs.sqlite3"))
    args = cli.parse_args()
    with Server((args.listen, args.port), args.database) as server:
        print(f"Clubs relay listening at {args.listen}:{server.server_port}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
