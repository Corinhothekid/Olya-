# PolyLax 2.0.1 helmet fit update

The new helmet follows the supplied XRS Pro reference with a low crown, swept visor and cheek rails, a recessed side opening, and paired front cage supports anchored under the visor. The shell tucks around the ears and nape. The cage and chin cup sit closer to the face with room for the nose and jaw. The helmet uses the existing head joint, materials, kit colors, and finish choices.

The closer creator camera applies to the Helmet view. You can drag to inspect the complete helmet. The software preview uses sample colors and was rendered from the Lua-generated mesh.

## Install

- **Single Main tab.** Back up the project, then replace its Main tab with the complete 2.0.1 Lua file. For a separate test install, use a fresh Codea Legacy Craft project. The last line is `-- End of PolyLax 2.0.1`.
- **Existing multi-tab 2.0 project.** Replace the complete `Character` and `CameraController` tabs with their 2.0.1 versions. The project ZIP has all 31 tabs. Updating the original project retains its local Codea save context.

## Verify

Open the creator, choose Helmet, and rotate through front, side, and rear. Repeat with several head presets, builds, heights, and finishes. Try Hair and return to Helmet to check visibility. Enter Practice or Full Game to confirm uniforms and the animated head joint.

Lua and mocked Craft checks cover shell clearance, the narrower portrait preview, customization, and the existing game flow. The software preview checks the shape from four angles. Native Codea rendering and materials on iPhone still need a device check. The previous release is recoverable from commit `0a1d5f5ce72cbb50434fc44389d876dd0c2dbdda`.
