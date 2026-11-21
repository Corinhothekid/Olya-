# PolyLax Ultimate | Development preview

Initial foundation for PolyLax Ultimate, with a source-backed 2026 PLL sample, original preview jersey palettes, and collection/squad operations.

## Status
- Implemented: `PolyLax.codea/Ultimate.lua` player records, kit catalog, collection, lineup assignment.
- Not implemented: main-menu integration, card UI, pack animations, full MLL/NLL historical datasets, automated updates, persistence integration, online Ultimate matches.
- No official player photographs, likenesses, team marks, official uniform artwork, or league assets are included.
- Player ratings are deliberately **not** invented. Future ratings must be editorially derived from validated, dated season data, with position-specific models.
- PLL records: 2026 regular-season source https://stats.premierlacrosseleague.com/player-table (retrieved Nov 2026). The source includes 277 players; this is an 8-player initial sample.
- NLL source candidate: https://www.nll.com/stats/ . No NLL player statistics have been imported yet.
- MLL: historical research and season-by-season verification needed before importing.
- Uniforms are original, inspired by field, throwback, and indoor lacrosse aesthetics, **not** faithful replicas.

## Codea setup
Add `Ultimate.lua` as a Codea tab to access `PolyLax.Ultimate`. No existing UI navigation or gameplay is changed by this module.

## Release safeguards
Do not distribute this data module as a publicly marketed official/endorsed PLL, MLL, or NLL product without legal review. Real-world player names and factual statistics are distinct from player likenesses, photos, official logos, team trade dress, jersey artwork, and other protected branding. Secure necessary permissions for commercial uses. No real-money packs are implemented.

## Next implementation
1. Codea Ultimate home, card collection, squad builder and kit preview.
2. Save collection locally; integrate cards with existing Athlete and TeamUniform models.
3. Validate historical MLL and NLL datasets from primary sources.
4. Add offline matches and then online friendlies using the Clubs relay.

## Economy implementation (Nov 2026)
- `PolyLax.codea/UltimateEconomy.lua` adds five-player starter grants (once per collection), five-player earned packs, 3,500-gold pack purchases, and 1,200-gold single-card wheel spins.
- Proposed **per-card** rarity weights: elite 90+ 20%, high 85–89 35%, core 75–84 45%. Ratings are deterministic **fictional placeholders** for development and are not verified player ratings. The pool currently contains only eight verified-season PLL entries; MLL and NLL research candidates are excluded.
- Starter pack fifth slot guarantees 85+; other four slots use the normal odds. Packs and wheel consume only in-game earned gold.
- Local testing: set `PolyLax.Ultimate.devMode=true` in a development build and call `PolyLax.Ultimate.Economy.grantTestGold(collection)` to grant 1,000,000 gold once per collection. Do not enable this for a production account. No user account has been remotely credited.
- `Economy.recordMatch(collection,"win"|"draw"|"loss")` supports reward payouts of 450/250/150 gold, but it must be called by a real completed match. It is **not yet connected** to FullMatch or online gameplay.
- Economy functions are **backend logic only**: no pack-opening screen, animated wheel, live inventory persistence, or Ultimate match entry point has been wired into Main.lua.
- Use `Ultimate.lua` before `UltimateEconomy.lua` in Codea. For SBC, load `UltimateSBC.lua` before `UltimateSBCUI.lua`.
- Before public release: independently validate pack probabilities against the final eligible card pool, disclose odds, and review gambling/loot-box laws and platform requirements even if no real-money purchases are offered.
