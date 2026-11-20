# PolyLax 3.1 Clubs

## Update Codea

Back up the current project. In a single-tab project, replace Main with the complete 3.1 Main. The last line is `-- End of PolyLax 3.1`. For a tabbed project, use the complete Codea ZIP and keep all tabs in its buffer order. Update the same project to retain its local data.

## Local play

The front menu has Quick Play, Be a Pro, PolyLax Clubs, and Settings. Quick Play includes Practice and Full Match. Settings still links to the regular Player Creator. Be a Pro retains its existing athlete, save, and season controls.

Open **PolyLax Clubs → My Player** to customize an independent athlete, then use **Player Development** to spend starter points. **Create Club** sets up a local high-school, college, or professional club and its roster and schedule previews. Club colors use the selected team's existing uniform. A local club has no invitation code until its host opens a real room.

## Prepare the online prototype

Run `server/clubs/relay.py` on a reachable host behind HTTPS. The [deployment and two-iPhone checklist](https://github.com/Corinhothekid/Olya-/blob/codex/polylax-2.0/server/clubs/README.md) gives the Python, Caddy, DNS, and health-check steps. The client uses Codea's documented [Legacy `http.request` API](https://codea.io/reference/Network.html).

1. Enter the same relay HTTPS address on both phones under **Settings → Clubs relay server**.
2. Make separate Clubs players. Select compatible roles, such as Attack on the host and Faceoff on the guest.
3. On the host, choose **Create Club → Save Club → Host Online**. Give the guest the relay-issued code. On the guest choose **Join Club**, enter the code, and join. Both players mark **Ready**. The host taps **Start Game**.
4. Move both athletes at the same time. Compare faceoffs, possession, passes, checks, shots, and the score. Briefly interrupt the guest's connection while keeping the project open. Check that it reconnects to the same athlete and receives current play.
5. Let the host finish. Compare the final score and each player's XP and statistics, then check that Be a Pro retained its own data. Confirm that reopening the result does not award points twice.

## Prototype limits

The lobby can hold up to ten people. Match start currently requires exactly two ready humans, with the existing AI filling the remaining positions. The host runs the match, and the guest interpolates snapshots. An authenticated host result can be recorded once in each player's separate Clubs save. The relay stores one completed match per room. Shared season advancement, league standings and awards, live substitution requests, and host migration are pending. A guest can recover from a lost connection during the same Codea session. App restarts require a fresh room.

The complete build passed Lua 5.4 parsing and the Quick Play and Be a Pro regressions. Two Lua clients with mocked Craft ran through lobby, independent controls, gameplay, reconnect, and final results over real loopback HTTP. The main-menu match route also passed against that relay. Public relay deployment and native testing on two iPhones are pending.
