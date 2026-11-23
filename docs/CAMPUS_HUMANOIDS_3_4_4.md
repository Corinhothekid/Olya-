# PolyLax 3.4.4 campus humanoids

The Road to Glory player and campus NPCs share one articulated humanoid rig. The torso, neck, head, sleeves, hands, pants, and shoes are shaped indexed meshes with smooth normals. The rig uses a smaller head, narrower shoulder pivots, tapered limbs and separate hips, knees and ankles. Coach Mercer has his own tailored jacket, glasses, and facial features. Ethan, Jace, Maya, Nina, Avery and the background residents use the same architecture with their own silhouettes and equipment.

The player model uses the existing face, hair, beard, size and height settings. The Drip Lab applies colors and patterns to the curved hoodie, joggers, sleeves and backpack surfaces. The equipped match stick uses its actual shaft, head and pocket on a backpack attachment that follows the player's torso. The match rig remains the gameplay and Drip Lab stick/glove/sleeve preview rig.

Campus walk and run cycle timing follows movement after collision handling. The legs solve hip, knee and ankle poses against a planned foot path, and the opposite arm follows the stride. Turning and starting still blend with root movement. Named idle and conversation poses continue through the existing interaction system. Background looks and saved preferences use their existing IDs.

The preview uses actual Lua mesh data rendered offline. With the tested outfit and patterned stick, the player uses 27 mesh render parts, down from 62 in 3.4.3. Individual meshes have more triangles for the new contours. [Player and Coach Mercer comparison](CAMPUS_HUMANOIDS_3_4_4.png)

## Install and test in Codea

Use the existing Legacy Craft project and keep the same Codea project name to retain local saves.

- **One Main tab** — Replace the whole tab with `releases/PolyLax-3.4.4-Main.lua`. Verify that the last line is `-- End of PolyLax 3.4.4`.
- **Multiple tabs** — Add `CampusHumanMeshes.lua` before `CampusCharacter.lua` and update all the changed tabs listed in the commit. Use the project `Info.plist` for the tab order.
- Run **Road to Glory**. Walk at partial joystick input, run at full input, then stop and turn. Check knee bend, arm swing and shoe contact. Rotate the camera around the player and check the stick and straps. Visit **Coach Mercer** and tap **Talk** to inspect face and clothing from the front.
- Open **Drip Lab → Outfit**, cycle the sneaker and backpack options, and preview a pattern. Switch to **Gloves**, return to **Outfit**, then leave. Check that any saved cosmetics still display on campus and in the tryout.
- Visit Ethan, Jace and Maya and try the Clubs entry and return. Check sustained frame rate on the outdoor campus.

## Mesh assets

This build generates the meshes inside Legacy Craft using the existing `craft.model()` position, normal, index, color and UV channels. It requires no imported models, textures or skinning package.

For a future artist-authored model, supply triangulated **OBJ** parts with normals and UVs in the project's local joint coordinates, plus PNG textures if used. Export the head, torso, pelvis, upper/lower arms and legs, shoes and pack as separate objects to mount them on the existing joints. Copy the assets into the Codea project, choose each model key in Codea's asset picker, then bind it with `craft.model(asset.Part_obj)` and assign the imported PNG to the part material's `map` when needed. Legacy Craft documents OBJ, FBX, STL and BLEND model loading. Skeletal clips require separate validation for the installed runtime.

[Legacy Craft model reference](https://www.codea.io/reference/Craft.html)

## Validation

Lua syntax, modular packaging, and the complete Main were checked. Mocked Craft tests cover mesh channels, player and NPC shoe contact, pose transitions, gestures, cosmetics, camera-relative movement, story activities, Clubs, Career and Ultimate Team. Native material appearance and frame rate require an iPhone test.
