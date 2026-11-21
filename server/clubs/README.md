# PolyLax Clubs relay

The relay gives the two-player Clubs prototype a real private lobby, a ready check, and a match exchange over Codea's asynchronous `http.request`. The host runs the lacrosse simulation. Guests send input and render the host's snapshots. The relay allocates invitation codes, assigns compatible positions, limits a lobby to ten humans, and starts a match when exactly two players are connected and ready. The game's existing AI fills the other eight home roles and the away team.

SQLite keeps each club's permanent invitation code, membership, readiness, input acknowledgements, the latest host checkpoint, and its latest completed result. Each device receives its own random bearer token. The relay stores only the token digest, and Codea saves its credential with the configured relay address. The host alone can start, finalize, or reopen a match. Disconnecting leaves the room code and membership in place.

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

To update an existing relay, stop the service, back up its SQLite database, replace `relay.py`, and restart with the same database path. The relay adds the new fields on startup and keeps existing room codes and authenticated memberships. Install the updated Codea client on both phones before playing a second match in the same room. A code can invite a new member. An existing member needs their saved device credential to resume the same profile and host permissions.

## Test with two iPhones

1. Install the same Clubs-enabled PolyLax build on both phones. In **PolyLax Clubs → My Player**, set distinct athletes. Pick different compatible slots, such as Attack and Midfield.
2. Set the same HTTPS relay address on both phones. On phone A, create a club, then create its online room. Send the issued invitation code to phone B. On phone B, select **Join Club** and enter that code. Both rosters should show both athletes with different slots.
3. Mark both players ready. Use **Start Game** on phone A. Verify that the controls on each phone affect only its assigned athlete. Move both simultaneously. Compare ball possession, faceoff outcome, passes, shots, checks, and score on both screens. Assign someone to Faceoff for a human-controlled draw.
4. Interrupt the guest's connection for a few seconds. Restore internet access and confirm that the guest returns to the same athlete and receives current host state. Quit and relaunch the guest's project, then resume the saved room. Verify that the same code and club membership appear.
5. Finish the match on the host and compare both final scores. Confirm that returning to the result or polling it again does not award duplicate statistics. Open **Be a Pro** separately on both devices and verify that its athlete and progression are intact.
6. Have the host reopen the lobby. Verify that both players remain members, the code stays the same, and both must ready again. Play a second match and check that the new final saves separately. If the host project closed during an unfinished game, resume the room as host and use the confirmation to abandon that game and reopen the lobby. The last completed result remains available.

The Python HTTP tests cover credentials, slot assignment, input de-duplication, checkpoint acknowledgement, relay restart, database migration, and multiple matches on the same code. The Lua integration test runs independent host and guest match instances with mocked Craft against the loopback relay. It covers live controls and result delivery, including the host route through Main. Testing with Codea on two iPhones and the deployed HTTPS endpoint remains pending.

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
| `resume` | Optional `profile` with the same local ID | `lobby`, `session`, `inputSeq`, optional `snapshot` or `profileError` |
| `ready` | `ready` boolean and optional lobby `revision` | `lobby` |
| `start` | Optional lobby `revision` | `lobby` with server-issued `matchId` |
| `sync` | Guest `input`; host `after` and optional `snapshot`; current `matchId` with input or snapshot | `lobby`, `inputSeq`, `snapshot` if available, host input page |
| `finish` | `result` with `matchId`, `homeScore`, `awayScore`, and `stats` keyed by every member | Final `lobby` after a matching `FINAL` snapshot |
| `reopen` | Current `matchId` and optional `abandon` boolean | Host-only return to a fresh lobby with the same code and membership |
| `leave` | Optional `withdraw` boolean for a guest outside an active match | Disconnects presence. Only an explicit guest withdrawal removes membership. |

`profile` contains local `id`, `name`, numeric `position`, jersey `number`, and optional `appearance` and `attributes`. A `session` contains `roomCode`, a separate relay `playerId`, and `token`. Lobby member IDs and server-assigned slots are authoritative for input routing. Input samples contain `seq`, normalized `x` and `z`, a `sprint` flag, and up to 12 small action objects. Snapshot `seq` increases monotonically within a match. The host should submit `after` with a new snapshot once it has applied input events. The checkpoint and input acknowledgement are stored in the same transaction. A retry with the same input sequence or final result is idempotent. Match statistics use the relay member IDs as keys.

Reopening increments `lobby.revision` and clears the current match ID, readiness, checkpoint, queued inputs, and input sequence acknowledgements. `lobby.lastResult` stays available across that transition so a member can receive the latest completed match even when the host has already reopened. Once a room has reopened, match input and checkpoints must identify the active `matchId`. A host can abandon an unfinished match explicitly, which issues no final result.
