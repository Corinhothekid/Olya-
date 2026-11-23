# PolyLax 3.4.6 | Campus material repair

The player and Nina rendered white on the iPhone because their authored colors lived in vertex data that Legacy Craft Standard can ignore. The campus rig now binds solid colors as Standard material tints. Multicolor faces, outfits, shoes and accessories use a generated palette image sampled by the mesh UVs. If Craft rejects the palette image, each part falls back to its dominant diffuse color. Materials are assigned after their models. This also applies to the existing procedural equipment patterns. Imported Drip Lab images retain their individual texture mappings.

[Offline comparison of the player and Nina](DRIP_LAB_COLORS_3_4_6.png)

For a single-tab Codea project, replace the entire Main tab with `releases/PolyLax-3.4.6-Main.lua`. Confirm the last line reads `-- End of PolyLax 3.4.6`. Use the existing project to keep your assets and saves. For the modular project, add `CraftPalette.lua` using `PolyLax.codea/Info.plist` and update the modified tabs in this commit.

Open **Road to Glory** and return to the Drip Lab. Check the player and Nina for distinct skin, hair and outfit colors. Open **Browse Gear → Outfit** and rotate the casual preview. Then check that imported patterns still appear under **Texture Test**.

The Lua regression reads actual material colors and samples the baked maps using the mesh UVs. It reproduces the missing character colors against 3.4.5 and passes with 3.4.6. The comparison is a desktop simulation of those material inputs. Native iPhone rendering still needs confirmation.

[Legacy Craft material reference](https://codea.io/reference/Craft.html#craft.material)
