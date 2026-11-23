# PolyLax Road to Glory 3.4.2

**Brothers in Arms, Act I · The Freshmen** runs from the first day at Briarbank through the tryout, placement decision, and the first team game.

## Install and play

1. Back up your installed project. Keep the original project in Codea so its imported logo, soundtrack, and saves remain available.
2. In a single-tab Legacy Craft project, replace all of Main with `releases/PolyLax-3.4.2-Main.lua` through `-- End of PolyLax 3.4.2`. For a modular project, update the `PolyLax.codea/` source using `Info.plist` for tab order. If you already have every 3.4.1 tab, update FreeRoam, FreeRoamUI, FreeRoamWorld, Story, Main, and Style. Use one installation format for your project.
3. Run PolyLax and tap **Road to Glory**. The **Career** button in the campus HUD opens the journal and existing athlete editor. Edit the athlete before the tryout to choose a name, appearance, team, and one of the seven positions.
4. Follow the objective tracker from Ethan in the courtyard to Mercer inside the school, Jace at the practice field, and Nina in the Drip Lab. Preview and equip cosmetics at the shop. Go to the locker room, complete first practice, and return to the bench to start the tryout.
5. Close the match box score to return. Seek Mercer for your placement, then find Ethan. Play the first game when directed. Enter the clubhouse and choose **Enter Pro Clubs** to use the existing online Clubs menu. **Return to Campus** resumes your exploration in the clubhouse.

## Controls

The left stick walks or runs based on displacement. Drag the right side of the screen or use the arrow controls to orbit the camera. Use **−** and **+** to zoom. Your zoom carries through doors and saves with your camera angle. **Interact** shows the nearest door, person, or station. **Equipment** opens the lab menu when inside Drip Lab. Pause offers resume, settings, and main-menu navigation. The existing practice and match controls are active during lacrosse.

## Saves and developer testing

Road to Glory owns an independent versioned local save. It uses the usual athlete, uniform, attributes, and statistics systems without replacing Be a Pro, Quick Play, Ultimate Team, or Clubs saves. A room visit, dialogue choice, equipment transaction, or activity result is saved in the story profile. The game records campus checkpoints after movement and on transitions. Active matches restart from the last saved campus objective after a cold launch. Match results and story progression commit after the activity.

The release sets `developerBuild` to `false`. The packaging tool rejects an enabled flag in public packages. For a private source copy, switch the existing flag locally and use **Ultimate Team → Developer Testing** to access the one-time gold grant and isolated `.Dev` save.

## Scope

The campus, six interiors, first-day storyline, first practice, tryout, placement, friendship decision, first game, and Clubs portal form the first playable milestone. The story focuses on freshman check-in and early team selection. Later high-school seasons, recruiting visits, college and pro hubs, NIL negotiations, agents, the draft, and legacy outcomes remain future chapters. Native Codea rendering and on-device performance require an iPhone check. Clubs uses the existing relay configuration.

Drip Lab includes the 13 pattern families, five approximated chrome finishes, individual sleeve controls, a rotating preview, ownership, and loadout presets. A cached procedural pattern mesh provides the color layouts. Pocket and shaft selections are cosmetic. The player's position still controls stick reach and save behavior.

## Changed files

The 3.4.2 update gives campus NPCs distinct human features and outfits, corrects left and right movement and facade lettering, and adds saved camera zoom. Existing saves open at the standard zoom until you adjust it.

The 3.4.1 patch fixes the touch crash caused by blending shoe or backpack trim with values read back from Craft materials. Color calculations now use the same numeric palette across campus, Drip Lab, and the playing kit. The save formats and equipment choices stay compatible.

- New Codea tabs: `FreeRoam.lua`, `FreeRoamUI.lua`, `FreeRoamWorld.lua`, `Story.lua`, `StoryChapters.lua`, `RoadEquipment.lua`, `RoadEquipmentUI.lua`, and `RoadToGlory.lua`.
- Updated Codea files: `AnimationController.lua`, `Character.lua`, `ClubsUI.lua`, `FullMatch.lua`, `Info.plist`, `Main.lua`, `Statistics.lua`, `Style.lua`, and `Ultimate.lua`.
- New tests: `tests/road_app.lua`, `tests/road_story.lua`, and `tests/road_equipment.lua`. Updated the public packaging check in `tools/package_codea.py`.
- Release files: `docs/ROAD_TO_GLORY_3_4.md` and `releases/PolyLax-3.4-Main.lua`. The packaging tool also generates a ZIP with every tab.

## Validation

From the repository root, run the Lua tests with Lua 5.4 and the shared Craft test harness:

```sh
lua tests/road_story.lua
lua tests/road_equipment.lua
lua tests/road_color.lua
lua tests/road_people.lua
lua tests/road_app.lua
POLYLAX_TEST_WIDTH=320 POLYLAX_TEST_HEIGHT=568 lua tests/road_app.lua
python3 tools/package_codea.py --version 3.4.2 --check-main releases/PolyLax-3.4.2-Main.lua
```

The app tests use real game code and mocked Codea graphics, touch events, and local storage. They reach the practice field and match engine, record both game outcomes, reopen the Clubs menu, and verify a saved return to the same campus location and camera angle. For device validation, repeat that route on an iPhone and check camera framing, outfit materials, performance during zone transitions, and the Clubs return after an online session.
