# PolyLax 3.4.3 campus characters

The Road to Glory campus uses articulated low-poly rigs with shaped heads, hair, hands, footwear, and clothing. Faces include secondary details such as brows, ears, and irises. Outfits and optional accessories include jackets, hoodies, lanyards, bags, and Maya's notebook. Meshes use the existing Craft model channels for positions, normals, indices, UVs, and vertex colors.

## Identity and behavior

- Ethan, Jace, Mercer, Maya, Nina, and Avery have authored appearance recipes with stable IDs. Returning through a door or reloading a save reconstructs the same appearance.
- Background students, the assistant coach, and school staff have fixed spawn IDs. Appearance selection uses the zone and spawn ID, and resolves repeated hair and primary outfit color combinations within that zone. It keeps its own random sequence.
- A joint rig animates the torso, head, shoulders, elbows, wrists, hips, knees, and ankles. Motion profiles distinguish walking, idle, listening, and speaking. Actual dialogue starts a profile-specific gesture. Walking paths retain their existing interaction tracking and distant actors are culled.
- Maya appears in the courtyard. Her optional conversation follows the current chapter and reacts to the first game's result.
- Existing Story, Career, Clubs, and Ultimate Team saves need no migration. The named and generated looks are derived from stable data.

## Codea setup

Replace the entire Main tab in your existing single-tab Legacy Craft project using the branch's `releases/PolyLax-3.4.3-Main.lua`. Confirm the last line is `-- End of PolyLax 3.4.3`. For a modular project, add CampusPeople, CampusCharacter, and CampusMotion before FreeRoamWorld and update the changed tabs using `PolyLax.codea/Info.plist`.

Run **Road to Glory**, walk to Ethan and Maya, and press **Talk** to see their gestures. Visit Coach Mercer, Nina at the Drip Lab, and Trainer Avery to see the other named character rigs.

## Source files

- Added `CampusPeople.lua`, `CampusCharacter.lua`, and `CampusMotion.lua`. `CampusPeople.named(id)` returns a fresh authored definition. `CampusCharacter.apply(rig, definition)` swaps mesh and material parts on a reusable rig. Use a complete definition from the catalog as the starting point for a variant.
- Updated `FreeRoamWorld.lua`, `FreeRoam.lua`, `FreeRoamUI.lua`, `Story.lua`, and `StoryChapters.lua` for spawning, proximity, speaking poses, and Maya's dialogue.
- Updated `Main.lua`, `Style.lua`, and `Info.plist` for the new tabs and build. Updated `tests/road_people.lua`, `tests/road_app.lua`, and `tests/road_color.lua`.

## Verification

Lua syntax and mocked Craft tests cover scene entry, named and generated identity, resource reuse, interchangeable geometry, culling, animation profiles, gestures, Maya's conversation, and save isolation. iPhone rendering, material appearance, and frame rate still need a native Codea check.
