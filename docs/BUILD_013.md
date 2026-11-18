# PolyLax Build 013

Build 013 starts from the working Build 012 GitHub tree. The recovery commit is `aad9785863a348d048adca34ec1dbea0ab295cdb`. The character rig, field models, team data, shot/goal physics, faceoffs, and career schedule stay in the same Codea Craft project.

## Install on iPhone

Open the complete Build 013 text file, select all, and paste it into `Main` in a fresh Codea Legacy Craft project with one tab. The final line should read `-- End of PolyLax Build 013`.

The ZIP contains the same code in 21 complete Lua tabs. Its `Info.plist` records the tab order. For installations that use Codea's **Paste Into Project** action, copy the complete clipboard edition starting at `--# Main`. Codea stores profiles and careers per project. Back up the current project and local save before replacing its tabs. Build 013 reads Build 012 career saves.

## Controls

- Move with the left stick. The pass marker shows the receiver inside the directional cone. With the stick centered, the cone follows the passer's facing.
- Tap blue **A** to pass at that target. Hold and drag **A** to choose a different direction while the left stick continues to control movement. Release to throw. A cone with no teammate marks **OPEN SPACE**. The ball can then be recovered. **A** also requests a pass when off ball or scoops a loose ball.
- Hold red **B**, drag, and release to shoot. On defense, **A** pokes and **B** body checks. The compact actions give access to Slap, Switch, Dodge, and Sprint as their contexts permit. At faceoff, **A** counters and **B** clamps.
- Tap **PICK** to queue a plant, or hold it to choose when to release. In Full Game and Career, use it while off ball near the on-ball defender. Stop the joystick to establish your feet. Steer on release to roll toward goal or pop outward. Moving into a defender or making contact before the plant can give the defense the ball.

## Tactical bar

| Call | In-game result |
| --- | --- |
| **SWING** | Advances around the perimeter in the same direction while lanes are open. |
| **CLEAR** | Looks for an open outside outlet and excludes X and central traffic. A covered lane keeps possession with the carrier. |
| **PASS DOWN** | Hits a lower perimeter teammate and sends the passer on a timed cut. Joystick input can override a controlled player's cut. |
| **PICK DOWN** | Sends a teammate to a pick location, establishes a planted stance, and offers a roll or pop. CPU carriers can use established picks and CPU defenders can navigate around them or switch. |

Practice retains six offensive athletes and its goalkeeper. It runs the pick positioning, plant, and release without a field defender. Contact, fouls, and screen credit require Full Game or Career.

## Changed tabs

- `Passing.lua`, `Gameplay.lua`, `FullMatch.lua`, `Defense.lua`, and `AnimationController.lua` share directional selection, release-time ball flight, intercept sampling, and reachable catch targets. The pass and catch clips still supply the events.
- `Tactics.lua`, `Screens.lua`, and `MatchAI.lua` provide tactical routing, legal screen timing, release motion, defender recovery, and screen attribution.
- `Main.lua` and `UI.lua` route independent motion, passing, shooting, and screen touches through the safe-area handheld HUD.
- `Career.lua`, `CareerSeason.lua`, and `CareerUI.lua` save Strength training and screen evaluation. Career tracks legal contact, open shots attributable to a screen, screen-to-goal credit, and illegal screens. Screen-to-goal credit stays separate from standard assists. Coach points can affect evaluation and recruiting by up to 12 points in either direction.
- `Info.plist` registers the three new tabs.

## Verification

Lua syntax and mocked Craft runs exercised both modes, the creator, independent pass input, both outside clearing outlets, safe retention, original shooting and checking, faceoffs, screen contact and foul restarts, AI screen use and recovery, HUD hitboxes, and career save migration. The repository carries a repeatable match regression. Run `lua tests/build013_match.lua` from the repository root with Lua 5.4.

On iPhone, check knob and A/B feel with two fingers, the aiming markers, the four calls, and the pick stance and release. Finish a career game with a screen event, relaunch, and confirm the stats and evaluation. Native Codea rendering, frame rate, touch feel, and persistence remain unverified. Contact and scoring are evaluated under the game's rules.
