"""Run using python3 -m unittest -v test_relay from this directory."""

from http.client import HTTPConnection
import json
from pathlib import Path
import sqlite3
from tempfile import TemporaryDirectory
from threading import Thread
from unittest import TestCase

from relay import Server


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
        self.call(clients[1], "resume", expected=401)

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
