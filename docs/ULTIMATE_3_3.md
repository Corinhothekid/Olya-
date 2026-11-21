# PolyLax Ultimate Team 3.3

Ultimate Team is available from the cinematic front menu. Its dashboard opens Play Match, My Squad, Player Packs, Gold Wheel, Squad Building Challenges, My Collection, and Jersey Vault.

## Install in Codea

Keep a backup of your current source. Update the existing project to retain its imported `asset.logo`, `asset.Main_Menu_Melody`, and local saves.

- **Single-tab project** — Replace the entire Main tab with `releases/PolyLax-3.3-Main.lua`. Copy through the last line, `-- End of PolyLax 3.3`.
- **Multi-tab project** — Use the full `PolyLax.codea/` source from this build. For an incremental update from the previous branch head, replace `Main`, `Style`, `FullMatch`, and `Statistics`. Add or update the seven Ultimate tabs in the order listed in `Info.plist`: `UltimateCatalog`, `Ultimate`, `UltimateEconomy`, `UltimateSBC`, `UltimateSBCUI`, `UltimateUI`, then `UltimateMatch`.

Run in Legacy Craft. A missing-tab message names the dependency if the project is incomplete. The complete build archive includes the Lua tabs and Codea project metadata.

## Play Ultimate Team

- Open the free starter pack to get five cards. Its first four slots use the standard odds, and the fifth guarantees 85+. In that guaranteed slot the conditional odds are 36.36% Elite and 63.64% High.
- A standard pack costs 3,500 earned gold and contains five cards. A Gold Wheel spin costs 1,200 gold and awards one card. Standard draws use 20% Elite (90+), 35% High (85–89), and 45% Core (75–84) per card. Gold and cards are saved before the reveal animation so they survive interruptions.
- Tap slots in My Squad to assign owned players. Put your best faceoff specialist in the FO slot. Temporary reserves fill open slots. The Jersey Vault kit applies to the whole Ultimate squad at kickoff.
- Play Match runs the existing 20-player simulation against the CPU with four 45-second quarters. Match rewards are 450 gold for a win, 250 for a draw, or 150 for a loss. Results save once at the final whistle and retain the team record and 20 recent results. The existing box score opens after the postgame presentation.
- An SBC shows its requirements and reward before you confirm the exchange. Submitting removes the exact copies selected, including any equipped copies, and grants the listed gold and unopened packs in the same save. All six challenges are one-time exchanges.

Ultimate Team uses its own local save. Existing Ultimate data migrates on the next successful save. Playable cards are original athletes with development ratings. The editorial catalog separately records sourced PLL, MLL, and NLL players. Six original kit designs ship without official logos, photos, likenesses, or replica jerseys. See [catalog notes and sources](ULTIMATE_CATALOG_3_3.md).

## Private developer build

In a private test copy only, set the source-local `developerBuild` flag in `Ultimate.lua` to `true`, then restart Codea. Open **Ultimate Team → Player Packs → Grant Developer Gold** to grant 1,000,000 once. This private build reads and writes a separate `.Dev` save. The published source defaults to `false`. Its normal build has no grant button and refuses the grant function.

## Test in Codea

1. Open the front menu and verify its logo, music, and Quick Play, Be a Pro, PolyLax Clubs, Settings, and Ultimate Team routes.
2. Open the starter pack, assign a player, equip a Jersey Vault kit, and restart. Check that the pack cannot be claimed again and all changes are retained.
3. Verify the pack and wheel prices and animated reveals with a funded private test copy. Review an SBC, cancel once, then submit and verify inventory and the reward.
4. Start an Ultimate match. Check your owned player, team kit, temporary reserves, faceoff, movement, passing, shooting, pause, and resume. Finish the match and confirm the gold and record update only once.

Automated Lua tests exercise the economy, catalog, SBC confirmation and rollback, touch routes, squad-to-match integration, and rewards. Craft rendering, motion feel, and media playback still require an iPhone check.
