# PolyLax 3.0.1 Main recovery

The reported copy ended inside `openBracketRound` after `local byeCount = capacity - #remaining`. Cutting the previous 3.0 Main at that point reproduces a Lua end-of-file syntax error. It omits 346 lines, including playoff matchups and byes, fixture and result handling, standings, recruiting, and development. The 33 canonical Codea tabs contain the full source. The recovery build packages those tabs without gameplay or career source changes.

## Update Codea

- **Single Main tab** — Back up your existing project. Replace all of Main with `releases/PolyLax-3.0.1-Main.lua` from GitHub Raw or use the matching plain-text download. The file has 13,289 lines and ends with `-- End of PolyLax 3.0.1`.
- **Short recovery paste** — If you still have the original all-in-one 3.0 Main up to the cutoff, replace from the standalone `-- CareerSeason` line through the end of Main with `PolyLax-3.0.1-CareerSeason-Recovery.txt`. This restores the whole wrapped tab and removes any extra `end` statements added while troubleshooting.
- **Separate Codea tabs** — If `CareerSeason` itself is cut short, replace that entire tab with `PolyLax.codea/CareerSeason.lua`. If the tab list or installed version is uncertain, use the complete tabbed project ZIP. Updating inside the current project keeps access to its local save.

## Verify the release

```sh
python3 tools/package_codea.py --version 3.0.1 --check-main releases/PolyLax-3.0.1-Main.lua
luac -p releases/PolyLax-3.0.1-Main.lua
lua tests/career_playoffs.lua
POLYLAX_TEST_DELIVERABLE=releases/PolyLax-3.0.1-Main.lua lua tests/career_playoffs.lua
```

All 33 Lua tabs and the entire single-file recovery Main passed the Lua 5.4 syntax check. The postseason regression covers six-team seeding and byes, elimination, a tied semifinal replay, save and reload, a title, contract progression, and a legacy save. Native Codea testing is pending.
