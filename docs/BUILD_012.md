# PolyLax Build 012

The active `PolyLax.codea` project starts from the workspace's Build 011 Gameplay. GitHub's five historical builds remain under `archive/`. The branch's first commit preserves the workspace baseline.

## Stage 1 · Mobile HUD and camera

Changed `Main.lua`, `UI.lua`, `CameraController.lua`, `Gameplay.lua`, and `FullMatch.lua`. The creator retains its original preview framing and controls. Play modes share a safe-area HUD, touch feedback, contextual buttons, and a hold-to-sprint control.

In Codea Legacy Craft, open Practice. Hold Sprint with one finger while walking with the joystick. Hold Shoot with a second finger, drag, and release. Cycle the camera through Dynamic, Broadcast, and Player Lock and test both zoom buttons. In Broadcast verify both goals and the full field remain visible on a phone in portrait. Start Full Game and play its existing faceoff.

Lua mocks passed three HUD sizes and six camera sizes, plus the creator, simultaneous joystick/sprint, hold-to-aim and mode entry checks. Native Codea rendering and touch response remain to be checked.

## Stage 2 · Checks, interceptions, and loose balls

Added `Defense.lua` and updated `FullMatch.lua`, `MatchAI.lua`, and the tab order. Poke, Slap, and Body start distinct checks that resolve on their animation events. They account for the players' orientation, distance, pocket position, defensive ratings, ball security, and recovery. A successful check can create a live loose ball. An illegal check briefly stops play and awards possession to the victim. Faceoff interaction remains the baseline at this stage.

In Full Game, approach a carrier and try each check, then chase and scoop a dislodged ball. Change `ageGroup` to `"U12"` in the FullMatch rules options for a body-contact foul test. Cross a pass lane to attempt an interception. The age/rules gates use an arcade subset of contact rules.

Lua mocks passed timed check hits and misses, rear/underage body fouls, restarts, scoop recovery, swept interceptions, and a complete shortened match. iPhone input and the new check animations await device testing.

## Stage 3 · Interactive faceoffs

Added `Faceoff.lua` and updated `FullMatch.lua` and the tab order. At the whistle, time Clamp or Counter as the meter crosses its highlighted window. A clean clamp enables a joystick exit. A close contest releases a ground ball to the wings. CPU difficulty, move choice, fatigue, ratings, and input timing affect the outcome.

In Codea, try early, ideal, and late inputs, and try each move against different CPU choices. Steer the exit after a clean win. Confirm wing players pursue a contested ball and that goals and period breaks return to the same faceoff sequence.

Deterministic Lua and Craft mocks passed timed choices, early calls, rating/fatigue effects, directional exits, contested wing recovery, animation contact, game clock, and both restart paths.

## Stage 4 · Career profile and game entry

Added `Career.lua` and `CareerUI.lua`. Updated `Main.lua`, `UI.lua`, `FullMatch.lua`, and the tab order. The Road to the Pros menu stores a name, position, ratings, XP, and personal stats in Codea's local project data. It launches a playable evaluation game in the shared 10v10 engine with Player Lock. The career player keeps control even when another athlete gains possession.

In Codea, open Career from the creator, choose a position, play a career game through the final horn, then return to the menu. Relaunch Codea and confirm the personal stats and result survived. A new character customization affects the same career athlete while ordinary Full Game and Practice remain separate.

Craft mocks passed menu and match entry, all five positions, Player Lock, complete-result saving, and duplicate result protection. Persistence uses Codea's documented JSON and project-local storage.

## Stage 5 · Teams and venues

Added `SchoolTeams.lua` and updated `TeamUniform.lua`, `Field.lua`, `FullMatch.lua`, `Main.lua`, `Career.lua`, `CareerUI.lua`, and the tab order. Six fictional high schools, nine NCAA Division I programs, Florida State's MCLA club, and PLL teams share kits and field configurations. Endline, sideline, and midfield lettering is original game geometry. School color sources are recorded in `SchoolTeams.lua`. Brand and kit combinations are designed for the game. [NCAA Division I men's lacrosse](https://www.ncaa.com/rankings/lacrosse-men/d1/ncaa-mens-lacrosse-rpi) · [Florida State Campus Recreation](https://campusrec.fsu.edu/activities/club-lacrosse-men/)

In Codea, choose a fictional high school before starting Career and inspect the field in Broadcast. Test standard Full Game with different PLL teams. For a direct venue test, pass `"florida-state"` as the first team ID to `FullMatch.new` and inspect its garnet and gold theme.

Lua mocks checked kit contrast, existing PLL IDs, all school theme mesh bounds, and configurable field metrics. The final visual palette, lettering, and frame rate remain to be checked on iPhone.

## Stage 6 · Schedule and progression

Added `CareerSeason.lua` and updated `Career.lua`, `CareerUI.lua`, `Main.lua`, `FullMatch.lua`, `UI.lua`, `CameraController.lua`, `SchoolTeams.lua`, `TeamUniform.lua`, `Field.lua`, and the tab order. Career fixtures have a balanced home and away schedule, venue themes, standings, playoffs, and saved results. Evaluation players take control on their first shift. Performance earns control from the opening whistle and XP to improve position-specific attributes. Personal and season records cover goals, assists, ground balls, caused turnovers, interceptions, saves, faceoff wins, and other events.

A completed high-school season generates recruiting offers. Florida State is a club option with a separate fictional club schedule. College or club performance feeds the pro entry offers. Pro seasons track in-game contracts, playoffs, and championships. Player Lock provides a direction marker when the ball leaves the portrait play area.

### Install and play

Open the complete Build 012 `Main.lua` in a fresh Codea Legacy Craft project with one tab, or import the organized `PolyLax.codea` folder and its `Info.plist`. In an existing project, keep a copy of its original tabs and save data before installing. Codea profiles and career saves are local to the installed project.

1. From the creator, confirm the player renders and the view, rotate gesture, gear and team selections still work.
2. Open Practice and confirm six offensive players plus the goalie. Try passes, a dodge, simultaneous sprint and joystick, hold-to-aim shots, a missed shot, an in-net hold, and a scoop.
3. Open Full Game. Cycle all three cameras. Broadcast should show both goals and the field in portrait. Use Poke, Slap, and Body, recover a loose ball, attempt an interception, and try Clamp and Counter at the meter.
4. Open Career, name your athlete, select a position and fictional school, and finish a game. Relaunch Codea and confirm the result, stats and next fixture appear. Open Schedule and Standings, try training when you have enough XP, and play through a postseason or recruiting offer.
5. Test on a physical iPhone with safe-area insets. Inspect the camera, uniforms and paint, and check touch input and frame rate.

### Verification and scope

Lua syntax checks, deterministic gameplay tests, and Craft mocks cover the HUD, camera projection, both match modes, checks, interceptions, faceoffs, school paint and kits, career save/restore, balanced scheduling, training, playoffs, and high-school-to-pro progression. One shortened career match ran through the match engine. Multi-season progression tests applied simulated final scores. iPhone Codea rendering, frame rate, touch feel, and persistence still need device verification.

Career opponents, schedules, recruiting thresholds, and contract values are game simulations. Campus and pro palettes use original field lettering and no team logos. CPU schedule results are simulated. The contact rules and shortened periods are arcade rules. Evaluation shifts hand off the same roster slot, and the build has no substitution management, official league scheduling, or licensing integration. An unfinished game resumes while the project is running. On relaunch, the scheduled fixture restarts and completed results persist.
