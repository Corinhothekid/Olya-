# PolyLax 3.3.1

## Update and launch on iPhone

1. Back up your current project or export its source before editing. Open the existing PolyLax project in Codea's Legacy Craft runtime so your imported logo, menu music, and local saves stay with it.
2. For a single-tab project, replace all of `Main` with `releases/PolyLax-3.3.1-Main.lua`. Copy the complete file through `-- End of PolyLax 3.3.1`. For a tabbed project, use `PolyLax.codea/` at the release commit and follow the tab order in `Info.plist`, including the new `SpecialistShift` tab.
3. Run the project, then open **Be a Pro → My Player** or **PolyLax Clubs → My Player** for position selection. Existing numeric positions keep their meaning. In Ultimate Team, claim the free Starter Pack and assign cards under My Squad. The midfield slot labeled FO is the opening draw assignment.

Do not mix the combined Main with active modular copies of the same tabs. Return to the existing project when upgrading a current save. A separately imported project starts with its own local storage.

## Gameplay and Ultimate Team

- Attack, Midfield, D-Pole, FOGO, Goalie, LSM, and SSDM have position presets and equipment in the existing creator. The 10v10 goalkeeper uses a wider pocket for saves. Career FOGOs and LSMs use the existing midfield substitution checks at the sideline. A FOGO returns for the next draw. An LSM can return on defense. Clubs retains the assigned human athlete throughout the match.
- Club Record opens saved box scores, including player and team stats. Older results retain their score and payout. Ultimate matches use the existing lacrosse engine with real goals and four 45-second periods. Gold and the new box score save together at the final whistle.
- Pack and wheel reveals show the player's league, position, rarity, and game rating. Reviewed league-season cards use factual player names, published performance evidence, and fictional PolyLax ratings. The research queue remains outside the draw pool. Edition artwork and uniform designs are original. Sources and the rating method are in [the catalog notes](ULTIMATE_CATALOG_3_3.md).
- All six SBCs retain their IDs, rewards, and completion history. Challenge boards explain their role, league, overall, and chemistry constraints. Separate owned copies can fill separate slots and the exchange commits only after confirmation and full validation.
- For private economy testing, set the source-local `developerBuild` flag in `Ultimate.lua` to `true` and reload. Use **Ultimate Team → Developer Testing** for the one-time grant or the confirmed private-save reset. Resetting retains the one-time grant flag. The public build uses a separate save and does not offer these actions.

## Upgrade an existing Clubs relay

Treat the Codea client and relay as a paired upgrade. Stop the relay, back up its SQLite file, deploy the updated `server/clubs/relay.py`, and restart using the **same database path**. Keep both iPhones pointed at the same HTTPS relay in Settings. The relay migrates existing room codes and credentials in place. Back up the SQLite database before switching back to an earlier server build.

On the host phone, open the saved room. On the guest phone, use the saved room or enter the invitation code for a first join. Ready both players and play a match. After the final, choose **Reopen Lobby** on the host to play again using the same code and roster. Both players ready again. The saved device credential controls membership and host access. The code alone permits invitations. Recovery after an interrupted host session requires explicit confirmation before discarding the unfinished match. See the [relay deployment and phone test guide](../server/clubs/README.md).

Earlier clients held room credentials in memory. A legacy host whose credential was already lost needs a newly authenticated room. The updated client saves its authenticated room on first connection and reuses it on later launches.

## Verification

Automated checks cover Lua syntax and both delivery formats, economy odds and rollback, the private developer controls, all six SBCs, the full-match goal and reward pipeline, Career and Quick Play gameplay, and persistent-room lifecycle tests. The Clubs relay is tested on loopback. Real iPhone Craft presentation and touch, the deployed HTTPS endpoint, and a two-iPhone session still require device testing.

## Source files

- **Positions and match engine** — Added `SpecialistShift.lua`. Updated `AnimationController.lua`, `Attributes.lua`, `Career.lua`, `Character.lua`, `FullMatch.lua`, `Gameplay.lua`, `MatchAI.lua`, `Passing.lua`, `Statistics.lua`, and `UI.lua`.
- **Ultimate Team** — Updated `Ultimate.lua`, `UltimateCatalog.lua`, `UltimateEconomy.lua`, `UltimateMatch.lua`, `UltimateSBC.lua`, `UltimateSBCUI.lua`, and `UltimateUI.lua`.
- **Clubs** — Updated `Clubs.lua`, `ClubsNet.lua`, and `ClubsUI.lua`. Updated `relay.py`, `test_relay.py`, and `README.md` under `server/clubs/`.
- **App and delivery** — Updated `Main.lua`, `Style.lua`, and `Info.plist`. Added `releases/PolyLax-3.3.1-Main.lua` and this release guide. Updated the Ultimate catalog notes.
- **Regression tests** — Added `tests/positions_integration.lua` and `tests/clubs_persistent.lua`. Updated `tests/clubs_loopback.lua`, `tests/equipment_integration.lua`, `tests/ultimate_app.lua`, `tests/ultimate_catalog.lua`, `tests/ultimate_economy.lua`, and `tests/ultimate_sbc.lua`.
