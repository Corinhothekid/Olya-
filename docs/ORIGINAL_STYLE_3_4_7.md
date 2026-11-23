# PolyLax 3.4.7 | Original character style

Road to Glory uses the main game's faceted head, face details, hairstyles and beard meshes. The campus player uses the same saved character choices and body proportions as the creator and match player. NPCs use the same model family with their authored complexion, clothing and accessories.

The campus hoodie and sleeves reuse the main game's geometry. Named tops use its jersey contour. Joggers, hands, shoes and backpacks follow the same faceted style. The campus rig is scaled for existing doors and camera framing, and the stowed stick follows that scale. Drip Lab colors and patterns still use working material maps. Career saves need no migration.

[Offline comparison of the match and campus models](ORIGINAL_STYLE_3_4_7.png)

## Install and test in Codea

For a single-tab project, replace the entire `Main` tab with `releases/PolyLax-3.4.7-Main.lua`. Confirm the last line reads `-- End of PolyLax 3.4.7`. Use the same Codea project to keep its assets and saves. For a modular project, update the modified Lua tabs in the commit.

1. Compare your face, haircut, beard and body shape in the creator and Road to Glory.
2. Revisit Trainer Avery or Nina. Walk, turn and talk nearby to inspect the shared style with their own outfits.
3. Open **Drip Lab → Outfit** to check your saved colors, patterns, and backpack stick. Check an imported pattern in **Texture Test**.

Geometry, visibility, placement and material tints were compared against the previous match rig across 304 render parts. Mocked checks cover the shared appearance, waist, foot placement, equipment, saved data and campus navigation. The comparison image is an offline render of the actual game meshes. Native lighting and animation still need an iPhone check.
