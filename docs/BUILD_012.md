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
