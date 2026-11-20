# PolyLax Clubs relay

The relay gives the two-player Clubs prototype a real private lobby, a ready check, and a match exchange over Codea's asynchronous `http.request`. The host runs the lacrosse simulation. Guests send input and render the host's snapshots. The relay allocates invitation codes, assigns compatible positions, limits a lobby to ten humans, and starts a match when exactly two players are connected and ready. The game's existing AI fills the other eight home roles and the away team.

SQLite keeps room membership, readiness, input acknowledgements, the latest host checkpoint, and one final result per match. Each device receives its own random bearer token. The database stores only the token digest. Room codes are for invitations. The Codea client keeps its room token in memory while the project runs.

## Run the relay

1. On a VPS with Python 3.10 or newer, put `relay.py` in a directory owned by a dedicated service account. Keep the SQLite file in a private directory writable by that account. Start the relay on loopback. Restart it with the same database path to retain rooms.

   ```sh
   umask 077
   python3 relay.py --listen 127.0.0.1 --port 8765 --database "$PWD/clubs.sqlite3"
   ```

2. Give the VPS a public DNS name and point its DNS record at the VPS. Set up an HTTPS reverse proxy with a publicly trusted certificate. This minimal Caddy site forwards requests on port 443. Replace `clubs.example.com` with your own host and allow Caddy to obtain its certificate. Expose the HTTPS proxy and its certificate challenge ports. Keep port 8765 on loopback.

   ```caddyfile
   clubs.example.com {
       reverse_proxy 127.0.0.1:8765
   }
   ```

3. Confirm the public URL from another network. The response should be `{"ok":true,"protocol":1}`. Enter the relay's base HTTPS URL in **Settings → Clubs relay server** on both iPhones.

   ```sh
   curl --fail --silent https://clubs.example.com/health
   ```

Use a service manager to keep the Python process running on the VPS. Retain the SQLite file across deployments and keep both the database and device session tokens private. The service accepts only JSON request bodies up to 64 KiB. Its basic create/join rate limit is shared by clients arriving through a common reverse proxy. This relay is designed for a private prototype. Production internet use would require operational limits, monitoring, and a plan for stored room data and session revocation.

## Test with two iPhones

1. Install the same Clubs-enabled PolyLax build on both phones. In **PolyLax Clubs → My Player**, set distinct athletes. Pick different compatible slots, such as Attack and Midfield.
2. Set the same HTTPS relay address on both phones. On phone A, create a club, then create its online room. Send the issued invitation code to phone B. On phone B, select **Join Club** and enter that code. Both rosters should show both athletes with different slots.
3. Mark both players ready. Use **Start Game** on phone A. Verify that the controls on each phone affect only its assigned athlete. Move both simultaneously. Compare ball possession, faceoff outcome, passes, shots, checks, and score on both screens. Assign someone to Faceoff for a human-controlled draw.
4. Keep the guest's project open in the room and interrupt its connection for a few seconds. Restore internet access and confirm that the guest returns to the same athlete and receives current host state. Closing the project clears its in-memory room token, so start a fresh room after an app restart.
5. Finish the match on the host and compare both final scores. Confirm that returning to the result or polling it again does not award duplicate statistics. Open **Be a Pro** separately on both devices and verify that its athlete and progression are intact.

The Python HTTP tests cover credentials, slots, input de-duplication, checkpoint acknowledgement, relay restart, guest reconnect, and result idempotency. The Lua integration test runs independent host and guest match instances with mocked Craft against the actual loopback relay. It covers live controls and result delivery, including the host route through Main. No public relay has been deployed or tested on two iPhones here. Restarting the relay preserves its latest snapshot. A host app restart requires a new room.

```sh
python3 -m unittest discover -s server/clubs -p test_relay.py
python3 tests/clubs_loopback.py
```

## Protocol 1

All gameplay endpoints are JSON `POST /v1/<operation>`. `GET /health` is unauthenticated. Use `Authorization: Bearer <token>` for authenticated operations.

| Operation | Body | Response |
|---|---|---|
| `create` | `name`, `stage`, `team`, `profile` | `lobby`, `session`, `inputSeq` |
| `join` | `roomCode`, `profile` | `lobby`, `session`, `inputSeq` |
| `resume` | `{}` | `lobby`, `session`, `inputSeq`, `snapshot` if available |
| `ready` | `ready` boolean | `lobby` |
| `start` | `{}` | `lobby` with server-issued `matchId` |
| `sync` | Guest `input`; host `after` and optional `snapshot` | `lobby`, `inputSeq`, `snapshot` if available, host input page |
| `finish` | `result` with `matchId`, `homeScore`, `awayScore`, and `stats` keyed by every member | Final `lobby` after a matching `FINAL` snapshot |
| `leave` | `{}` | `left` or temporary `disconnected` |

`profile` contains local `id`, `name`, numeric `position`, jersey `number`, and optional `appearance` and `attributes`. A `session` contains `roomCode`, a separate relay `playerId`, and `token`. Lobby member IDs and server-assigned slots are authoritative for input routing. Input samples contain `seq`, normalized `x` and `z`, a `sprint` flag, and up to 12 small action objects. Snapshot `seq` increases monotonically. The host should submit `after` with a new snapshot once it has applied input events. The checkpoint and input acknowledgement are stored in the same transaction. A retry with the same input sequence or final result is idempotent. Match statistics use the relay member IDs as keys.
