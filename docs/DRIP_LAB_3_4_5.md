# PolyLax 3.4.5 | Drip Lab imported textures

Drip Lab reads the project images `asset.camo`, `asset.ducky`, `asset.galaxy`, and `asset.zebra` with `readImage` and binds decoded images to Legacy Craft Standard material maps.

- **Stick** includes the four imported choices for shaft and grip, plus **Head Pattern** and **Pocket Pattern**. The shaft repeats the image in separate UV bands with a full turn across each band. Head and pocket mapping keeps the original molded frame, individual strands, and open holes between strings.
- **Gloves** includes the four choices in **Glove Pattern**. The image maps to the glove shell and follows the wrist. **Sleeves** includes the four choices under **Left Pattern** and **Right Pattern**. The configured sleeve coverage still determines which leg segments use the image.
- The equipped images travel with the Road to Glory athlete from the preview to the hub and into training and matches. The hub displays imported-pattern gloves on the athlete's hands. Texture choices use the existing credits, ownership, equipment and preset saves. The original pattern IDs are preserved.

The campus hem now overlaps the shaped trouser seat. The match jersey and hoodie overlap the shorts waistband through athletic poses.

## Install in Codea

In your existing Legacy Craft project, replace the whole `Main` tab with `releases/PolyLax-3.4.5-Main.lua` if you're using the single-tab build. Confirm the last line reads `-- End of PolyLax 3.4.5`. Use the same project to retain your imported textures and local saves. For the modular build, update the changed tabs and add `EquipmentTextures.lua` ahead of `RoadEquipment.lua` using `PolyLax.codea/Info.plist`.

## iPhone check

1. Open **Road to Glory → Drip Lab → Texture Test**. Check that the four shafts marked **asset.camo**, **asset.ducky**, **asset.galaxy** and **asset.zebra** show distinct images. Drag horizontally and check that the image wraps around each shaft and repeats along its length.
2. Tap **Back** to return to the selected Drip Lab option. Select an **Imported** pattern for the shaft, head, pocket, gloves and one sleeve. Set the sleeve coverage to **Lower Leg** or **Full**. Rotate each preview and confirm the pocket remains open between the strands.
3. Buy and equip your selected options, exit to campus, and view the stowed stick, gloves and sleeve. Start a practice or match and inspect the same equipment. Close and reopen the project to check the save.
4. Walk and run in the hub, then inspect the waist while dodging or shooting in a match. The hem should continue over the waistband.

The Texture Test reports missing references, image load failures, and Craft map binding errors by asset. An unavailable image blocks its new purchase. Existing saved choices are retained, and the equipment shows its underlying finish until the image is available.

Lua syntax, mocked texture assignment, UV seams, shaft rotation and layout, the open pocket, save/reload, story gameplay and waist coverage were checked in the development environment. The four imported images live in the iPhone project. Their actual appearance requires the native check above.

[Legacy Craft material and model reference](https://www.codea.io/reference/Craft.html)
