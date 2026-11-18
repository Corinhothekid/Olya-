# PolyLax 2.0

The working Build 013 source is the recovery commit `7baa5802c7de77fc76d62e376f58d8783fb6cba8`. PolyLax 2.0 uses the existing portrait Codea Craft match engine, athlete rig, animation controller, field, six-player Practice, and career save path.

## Install on iPhone

Paste the entire single-tab Lua file into **Main** in a fresh Codea Legacy Craft project. Its last line is `-- End of PolyLax 2.0`.

For separate tabs, the project ZIP includes all 31 Lua tabs and `Info.plist` with their order. The clipboard edition starts at `--# Main` for Codea's **Paste Into Project** action. Profiles and saves are local to the Codea project. Back up that project before updating it. The 2.0 code reads the existing Build 013 career save when installed in the same project.

## Changes by milestone

1. **Interface and controller**. `Style.lua`, `UI.lua`, and `Main.lua` add graphite surfaces, front and mode menus, pause/resume, a recessed analog wheel with a dead zone and a smoothly recentering thumb pad, and raised A/B buttons. Directional passing and the four tactical calls use their existing controls.
2. **Career athlete**. `Athlete.lua`, `Character.lua`, `UI.lua`, and `Main.lua` add independent first and last names, jersey number, height and build, position, gear, and home/away kit previews. Choose your starting school in the athlete editor. Established teams change through recruiting or pro entry. The editor uses the original rig and mesh assets.
3. **Development**. `Attributes.lua`, `Development.lua`, Career, the movement engines, and the passing, defense, faceoff, and AI tabs add 17 rated skills, position-specific overall ratings, costed upgrades, match and coach rewards, and a playable training drill. Skill upgrades change the underlying game calculations. Skills cap at 99 and drill rewards are claimed once per scheduled fixture. Career development carries across stages.
4. **Statistics**. `Statistics.lua`, `StatUI.lua`, Main, Career, and both game modes collect player and team events, appearances, time, goalie and faceoff rates, caused and unforced losses, and assessed penalties. The Stats overlay pauses play. Box scores and career, season, and match records use stable identifiers. Assist credit requires a recent received pass that led directly to the shot. Screen credit has its own category.
5. **Schedules and rosters**. `League.lua` and the career season, interface, and match tabs add stable 10-player rosters, venues, balanced schedules, division-specific postseason qualification, and league leaders. Off-screen CPU fixtures use a deterministic simulation. Played games store measured events from the match.
6. **Awards**. `Awards.lua`, `AwardUI.lua`, and the career tabs add the NCAA Division I Tewaaraton race, watchlist, midseason rankings, finalists, and winner. Pro honors include MVP, offensive, defensive, goalie, rookie, and championship MVP. Winners are derived from season records. Florida State's club pathway uses a separate competition.
7. **Game day**. `Presentation.lua`, Main, and FullMatch add same-scene run-ons, lineups, opening faceoff, goal reactions, postgame handshake, Player of the Game, and trophy presentation. Skip restores the staged transforms and sends the camera back to play or opens the final box score.
8. **Career dashboard**. Career shows position, jersey number, overall rating, skill points, next opponent and venue, season record, recent result, honors, recruiting offers, and the career timeline. Seasons carry forward identity, kit, player development, recorded stats, and trophies.

## Codea checklist

- From the front menu, visit the creator, Practice, Full Game, and Career. Pause and resume to check the clock. Use the dead zone, joystick, and both action buttons with two fingers. Check Swing, Clear, Pass Down, and Pick Down.
- In Career, tap the athlete name, position, or school to edit the same preview. Change height, gloves, helmet, and number. Compare home and away kits. Start a career fixture and compare uniform and character identity.
- Finish a drill, buy an attribute upgrade, and return to Development after relaunch. Finish a game and inspect player and team stats. Verify the next fixture, standings, league leaders, and saved box score.
- Watch or skip the run-on, a goal, and the postgame sequence. Use an eligible college or pro career for awards. Verify Florida State remains a club path.
- On iPhone, check safe areas, font sizes, rendering, controller feel, battery/frame rate, and actual local-save persistence.

## Tested and remaining scope

Lua syntax checks, deterministic gameplay, and mocked Craft tests covered the interface, athlete migration, actual attribute effects, passing and tactical calls, shooting, checks, faceoffs, stat events, saved career progression, schedules and replay protection, award eligibility and trophies, and cinematic pose restoration. The repository tests run with Lua 5.4 using `lua tests/polylax20_app.lua` and `lua tests/build013_match.lua`.

Native iPhone Codea runs remain pending. Competition schedules, qualifications, contracts, and penalty time use condensed game rules. Played-game scores and individual stats come from the running match. Unplayed fixture statistics are simulated. The game has fixed 10-player match rosters without substitutions or a full timed man-down system.
