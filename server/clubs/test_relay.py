"""Run using python3 -m unittest -v test_relay from this directory."""

from http.client import HTTPConnection
import json
from pathlib import Path
import sqlite3
from tempfile import TemporaryDirectory
from threading import Thread
from unittest import TestCase
from unittest.mock import patch

from relay import SCHEMA, Server, encode, token_hash


class Client:
    def __init__(self, port):
        self.port = port
        self.token = None

    def post(self, action, data=None):
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        with_connection = HTTPConnection("127.0.0.1", self.port, timeout=4)
        try:
            with_connection.request("POST", f"/v1/{action}", json.dumps(data or {}), headers)
            response = with_connection.getresponse()
            body = json.loads(response.read())
            if response.status == 200 and "session" in body:
                self.token = body["session"]["token"]
            return response.status, body
        finally:
            with_connection.close()


def athlete(name, position, number=21):
    return {"id": f"profile-{name}", "name": name, "position": position, "number": number,
            "appearance": {"HELMET": 2}, "attributes": {"speed": 71}}


class RelayTest(TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.database = Path(self.temp.name) / "clubs.sqlite3"
        self.boot()
        self.host = Client(self.server.server_port)
        self.guest = Client(self.server.server_port)
        self.addCleanup(self.stop)

    def boot(self):
        self.server = Server(("127.0.0.1", 0), self.database)
        self.thread = Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.02})
        self.thread.start()

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def call(self, client, action, data=None, expected=200):
        status, body = client.post(action, data)
        self.assertEqual(status, expected, body)
        return body

    def new_room(self, position=6):
        return self.call(self.host, "create", {"name": "Briarbank Club", "stage": "highSchool",
                           "team": "briarbank", "profile": athlete("Host", position)})

    def start(self, revision=0):
        for client in (self.host, self.guest):
            self.call(client, "ready", {"ready": True, "revision": revision})
        return self.call(self.host, "start", {"revision": revision})["lobby"]["matchId"]

    def test_two_clients_and_host_authority(self):
        host = self.new_room()
        code = host["lobby"]["code"]
        self.call(self.host, "ready", {"ready": True})
        self.call(self.host, "start", expected=409)
        member = self.call(self.guest, "join", {"roomCode": code.lower(), "profile": athlete("Guest", 4)})
        guest_id = member["session"]["playerId"]
        host_id = host["session"]["playerId"]
        self.assertNotEqual(self.host.token, self.guest.token)
        self.assertNotIn(self.host.token, json.dumps(member))
        self.assertEqual([(p["id"], p["slot"]) for p in member["lobby"]["players"]], [(host_id, 5), (guest_id, 4)])
        self.call(self.host, "start", expected=409)
        self.call(self.guest, "start", expected=403)
        self.call(self.host, "ready", {"ready": True})
        self.call(self.guest, "ready", {"ready": True})
        running = self.call(self.host, "start")["lobby"]
        match = running["matchId"]
        self.assertEqual(running["phase"], "match")
        self.assertEqual(self.call(self.host, "start")["lobby"]["matchId"], match)
        payload = {"input": {"seq": 0, "x": 0.6, "z": -0.3, "sprint": True,
                             "actions": [{"action": "pass", "aim": {"x": 0, "y": 1.0, "z": 2}}]}}
        guest_sync = self.call(self.guest, "sync", payload)
        self.assertEqual(guest_sync["inputSeq"], 0)
        self.assertEqual(guest_sync["inputs"], [])
        self.call(self.guest, "sync", payload)
        checkpoint = self.call(self.host, "sync")
        self.assertEqual(len(checkpoint["inputs"]), 1)
        first = checkpoint["inputs"][0]
        self.assertEqual((first["playerId"], first["slot"], first["input"]), (guest_id, 4, payload["input"]))
        snapshot = {"matchId": match, "seq": 1, "ball": [0, 2, -1], "possession": 4, "homeScore": 1}
        self.call(self.guest, "sync", {"snapshot": snapshot}, expected=403)
        self.call(self.host, "sync", {"snapshot": snapshot, "after": first["id"]})
        self.assertEqual(self.call(self.guest, "sync")["snapshot"], snapshot)
        self.assertEqual(self.call(self.host, "resume")["inputs"], [])
        self.call(self.host, "sync", {"snapshot": {"seq": 0, "homeScore": 88}})
        self.assertEqual(self.call(self.guest, "sync")["snapshot"], snapshot)

        leave = self.call(self.guest, "leave")
        self.assertTrue(leave["disconnected"])
        self.assertFalse(leave["lobby"]["players"][1]["connected"])
        with sqlite3.connect(self.database) as db:
            stored = str(db.execute("SELECT token_hash FROM members").fetchall())
            self.assertNotIn(self.guest.token, stored)
            self.assertNotIn(self.host.token, stored)

        self.stop()
        self.boot()
        self.host.port = self.guest.port = self.server.server_port
        resumed = self.call(self.guest, "resume")
        self.assertEqual(resumed["session"]["playerId"], guest_id)
        self.assertEqual(resumed["inputSeq"], 0)
        self.assertEqual(resumed["snapshot"], snapshot)
        self.assertTrue(resumed["lobby"]["players"][1]["connected"])
        self.call(self.guest, "sync", {"input": {"seq": 1, "x": 0}})
        self.assertEqual(self.call(self.host, "sync")["inputs"][0]["input"]["seq"], 1)

        result = {"matchId": match, "homeScore": 1, "awayScore": 0,
                  "stats": {host_id: {"assists": 1}, guest_id: {"goals": 1}}}
        self.call(self.guest, "finish", {"result": result}, expected=403)
        self.call(self.host, "finish", {"result": result}, expected=409)
        self.call(self.host, "sync", {"snapshot": {**snapshot, "seq": 2, "phase": "FINAL", "awayScore": 0}})
        self.call(self.host, "finish", {"result": result})
        self.call(self.host, "finish", {"result": result})
        self.call(self.host, "finish", {"result": {**result, "homeScore": 2}}, expected=409)
        self.call(self.host, "leave")
        final = self.call(self.guest, "sync", {"input": {"seq": 2, "x": 0.5}})["lobby"]
        self.assertEqual((final["phase"], final["result"]), ("final", result))

    def test_compatible_slots_room_capacity_and_prototype_limit(self):
        host = self.new_room(4)
        code = host["lobby"]["code"]
        self.call(self.guest, "join", {"roomCode": code, "profile": athlete("Faceoff", 4)}, expected=409)
        clients = [self.host]
        for index, position in enumerate([5, 6, 7, 1, 1, 1, 3, 3, 3]):
            new = Client(self.server.server_port)
            last = self.call(new, "join", {"roomCode": code, "profile": athlete(f"Player{index}", position)})
            clients.append(new)
        self.assertEqual(sorted(player["slot"] for player in last["lobby"]["players"]), list(range(1, 11)))
        self.call(self.guest, "join", {"roomCode": code, "profile": athlete("Late", 2)}, expected=409)
        for client in clients:
            self.call(client, "ready", {"ready": True})
        self.call(self.host, "start", expected=409)
        self.call(self.host, "leave")
        reopened = self.call(clients[1], "resume")["lobby"]
        self.assertEqual(reopened["code"], code)
        self.assertEqual(len(reopened["players"]), 10)
        self.assertFalse(reopened["players"][0]["connected"])
        self.assertFalse(reopened["players"][0]["ready"])

    def test_unique_codes_and_repeat_matches_after_restart(self):
        guest_profile = athlete("Guest", 4)
        with patch("relay.room_code", side_effect=["AAAAAAA2", "AAAAAAA2", "AAAAAAA3"]):
            original = self.new_room()
            other = self.call(Client(self.server.server_port), "create",
                              {"name": "Other Club", "profile": athlete("Other Host", 5)})
        code = original["lobby"]["code"]
        self.assertNotEqual(other["lobby"]["code"], code)
        joined = self.call(self.guest, "join", {"roomCode": code, "profile": guest_profile})
        host_id, guest_id = original["session"]["playerId"], joined["session"]["playerId"]

        first = self.start()
        shot = {"matchId": first, "seq": 7, "phase": "FINAL", "homeScore": 1, "awayScore": 0}
        result = {"matchId": first, "homeScore": 1, "awayScore": 0,
                  "stats": {host_id: {"assists": 1}, guest_id: {"goals": 1}}}
        old_input = {"matchId": first, "input": {"seq": 14, "x": 0.5}}
        self.call(self.guest, "sync", old_input)
        self.call(self.host, "sync", {"matchId": first, "snapshot": shot})
        self.call(self.host, "finish", {"result": result})
        self.call(self.host, "leave")
        self.call(self.guest, "leave")

        host_token, guest_token = self.host.token, self.guest.token
        self.stop()
        self.boot()
        self.host, self.guest = Client(self.server.server_port), Client(self.server.server_port)
        self.host.token, self.guest.token = host_token, guest_token
        final = self.call(self.host, "resume")
        self.assertEqual(final["session"], original["session"])
        self.assertEqual(final["lobby"]["result"], result)
        self.call(self.guest, "reopen", {"matchId": first}, expected=403)
        self.call(self.guest, "finish", {"result": result}, expected=403)
        reentry = self.call(self.host, "reopen", {"matchId": first})["lobby"]
        self.assertEqual({p["id"] for p in reentry["players"]}, {host_id, guest_id})
        self.assertEqual((reentry["code"], reentry["phase"], reentry["revision"]), (code, "lobby", 1))
        self.assertIsNone(reentry["matchId"])
        self.assertIsNone(reentry["result"])
        self.assertTrue(all(not p["ready"] for p in reentry["players"]))
        self.assertEqual(reentry["lastResult"], result)
        self.assertEqual(self.call(self.host, "reopen", {"matchId": first})["lobby"]["revision"], 1)
        reconnect = self.call(self.guest, "resume")
        self.assertEqual(reconnect["session"], joined["session"])
        self.assertNotIn("snapshot", reconnect)
        self.assertEqual(reconnect["inputs"], [])
        self.assertEqual(reconnect["inputSeq"], -1)
        self.assertEqual(reconnect["lobby"]["lastResult"], result)
        self.call(self.guest, "join", {"roomCode": code, "profile": guest_profile}, expected=409)
        self.call(self.guest, "ready", {"ready": True, "revision": 0}, expected=409)
        self.call(self.host, "start", {"revision": 0}, expected=409)

        second = self.start(1)
        self.assertNotEqual(first, second)
        self.call(self.guest, "sync", old_input, expected=409)
        self.call(self.guest, "sync", {"input": old_input["input"]}, expected=409)
        self.call(self.host, "sync", {"snapshot": shot}, expected=409)
        self.call(self.host, "finish", {"result": result}, expected=409)
        self.call(self.host, "reopen", {"matchId": first, "abandon": True}, expected=409)
        self.assertEqual(self.call(self.host, "sync")["inputs"], [])
        tagged = {"matchId": second, "input": {"seq": 0, "x": 0.3}}
        self.assertEqual(self.call(self.guest, "sync", tagged)["inputSeq"], 0)
        self.assertEqual(self.call(self.host, "sync")["inputs"][0]["input"]["seq"], 0)
        self.call(self.host, "reopen", {"matchId": second}, expected=409)
        self.call(self.guest, "reopen", {"matchId": second, "abandon": True}, expected=403)
        second_result = {"matchId": second, "homeScore": 3, "awayScore": 2,
                         "stats": {host_id: {"goals": 3}, guest_id: {"assists": 1}}}
        self.call(self.host, "sync", {"snapshot": {"matchId": second, "seq": 0, "phase": "FINAL",
                                                   "homeScore": 3, "awayScore": 2}})
        for _ in range(2):
            second_final = self.call(self.host, "finish", {"result": second_result})["lobby"]
            self.assertEqual(second_final["lastResult"], second_result)
        self.call(self.host, "reopen", {"matchId": second})
        third = self.start(2)
        next_lobby = self.call(self.host, "reopen", {"matchId": third, "abandon": True})["lobby"]
        self.assertEqual((next_lobby["code"], next_lobby["phase"], next_lobby["lastResult"]),
                         (code, "lobby", second_result))
        self.call(self.host, "leave", {"withdraw": True}, expected=409)
        self.call(self.guest, "leave", {"withdraw": True})
        self.call(self.guest, "resume", expected=401)
        new_guest = self.call(self.guest, "join", {"roomCode": code, "profile": athlete("New Guest", 3)})
        self.assertEqual(new_guest["lobby"]["code"], code)
        self.assertNotEqual(new_guest["session"]["playerId"], guest_id)

    def test_resume_updates_compatible_profile_without_changing_identity(self):
        original = self.new_room(4)
        self.call(self.guest, "join", {"roomCode": original["lobby"]["code"], "profile": athlete("Guest", 3)})
        self.call(self.guest, "ready", {"ready": True})
        updated = {**athlete("Guest", 6), "name": "Updated Athlete"}
        resumed = self.call(self.guest, "resume", {"profile": updated})
        self.assertNotIn("profileError", resumed)
        member = resumed["lobby"]["players"][1]
        self.assertEqual((member["slot"], member["profile"]["name"], member["ready"]), (5, "Updated Athlete", False))
        for profile in (athlete("Guest", 4), athlete("Different Profile", 3)):
            rejected = self.call(self.guest, "resume", {"profile": profile})
            self.assertIn("profileError", rejected)
            self.assertEqual(rejected["lobby"]["players"][1]["profile"], member["profile"])
        self.start()
        in_match = self.call(self.guest, "resume", {"profile": {**updated, "position": 3}})
        self.assertIn("profileError", in_match)
        self.assertEqual(in_match["lobby"]["players"][1]["profile"], member["profile"])

    def test_migrates_existing_final_room_and_tokens(self):
        self.stop()
        self.database.unlink()
        old_schema = SCHEMA.replace(",\n    last_result TEXT,\n    reopened_match_id TEXT,"
                                    "\n    revision INTEGER NOT NULL DEFAULT 0", "")
        code, host, guest, match = "MIGRATE2", "legacy-host", "legacy-guest", "legacy-finished"
        host_token, guest_token = "h" * 43, "g" * 43
        result = {"matchId": match, "homeScore": 2, "awayScore": 0, "stats": {host: {}, guest: {}}}
        with sqlite3.connect(self.database) as db:
            db.executescript(old_schema)
            db.execute("""INSERT INTO rooms(code,name,team,stage,host_id,phase,match_id,result)
                        VALUES(?,?,?,?,?,'final',?,?)""",
                       (code, "Persisted Club", encode("briarbank"), "highSchool", host, match, encode(result)))
            for member, token, profile, slot in ((host, host_token, athlete("Host", 4), 4),
                                                 (guest, guest_token, athlete("Guest", 3), 7)):
                db.execute("""INSERT INTO members(id,room,token_hash,profile,position,slot,last_seen)
                           VALUES(?,?,?,?,?,?,0)""",
                           (member, code, token_hash(token), encode(profile), profile["position"], slot))
        self.boot()
        self.host, self.guest = Client(self.server.server_port), Client(self.server.server_port)
        self.host.token, self.guest.token = host_token, guest_token
        state = self.call(self.host, "resume")
        self.assertEqual(state["session"]["roomCode"], code)
        self.assertEqual(state["lobby"]["lastResult"], result)
        self.call(self.host, "reopen", {"matchId": match})
        state = self.call(self.guest, "resume")
        self.assertEqual(state["lobby"]["lastResult"], result)
        self.assertEqual({p["id"] for p in state["lobby"]["players"]}, {host, guest})

    def test_rejects_missing_auth_invalid_room_and_invalid_motion(self):
        self.call(self.guest, "sync", expected=401)
        self.call(self.guest, "join", {"roomCode": "BAD", "profile": athlete("Guest", 2)}, expected=404)
        self.call(self.host, "create", {"name": "Bad", "profile": {"name": "Bad", "position": True}}, expected=400)
        code = self.new_room()["lobby"]["code"]
        self.call(self.guest, "join", {"roomCode": code, "profile": athlete("Another LSM", 6)}, expected=409)
        self.call(self.guest, "join", {"roomCode": code, "profile": athlete("Guest", 3)})
        self.call(self.host, "ready", {"ready": True})
        self.call(self.guest, "ready", {"ready": True})
        self.call(self.host, "start")
        self.call(self.guest, "sync", {"input": {"seq": 1, "x": 1.1}}, expected=400)
        self.call(self.guest, "sync", {"input": {"seq": 1, "z": "north"}}, expected=400)
        self.call(self.host, "sync", {"snapshot": {"seq": 0, "matchId": "other"}}, expected=409)
