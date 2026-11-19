# PolyLax 3.0 rules and long poles

## Install in Codea

Back up your current Codea project. To retain its local career save, update it in place.

- For a single-tab project, replace Main with the complete `PolyLax-3.0-Full-Lua-Code.txt`. Paste through `-- End of PolyLax 3.0`.
- For a multi-tab project, use all the tabs from the complete 3.0 Codea ZIP. The ZIP contains the project's tab order and both new tabs, `Midfield` and `MatchRules`.
- For a separate test install, use a Legacy Craft project. A separate Codea project has a separate local save.

## Test on iPhone

1. Start Full Match and play the opening draw. Cross midfield as a midfielder, then try a crossing that would leave too few teammates behind. Check the warning and try again when a teammate rotates to cover.
2. Start a Career fixture and check the `SHOT`, `CLEAR`, or `CREASE` count for your league. On a timed violation, verify that the opponent gets the ball. Career fixtures keep the existing shorter periods.
3. In a new career, pick **Long-Stick Mid** or **Short-Stick Def Mid** in the creator. Check the stick preview, then enter a fixture. Existing careers retain their saved position and attributes.
4. Compare a close defenseman's poke or slap to a short stick's reach. Check that the hands, stick, and pocket stay together as players run, cradle, pass, and scoop. Try a swipe that misses the carrier's stick and a well-placed legal check.
5. Play through a match, reopen Career, and verify fixture results, statistics, and skill points.

## Scope and verification

Full Match and Career share legal midfield movement for both teams. The Arcade profile blocks illegal crossings and warns. The competition profiles also award a turnover for a blocked offensive crossing with possession. The rules milestone adds competition clocks and boundary restarts. See `docs/RULES_3_0.md` in the source repository for rules references and remaining differences.

Close defense and LSMs use a long pole when the ruleset allows it. SSDMs and other midfielders use a short stick. The default cap is four long poles per team, with the goalie counted separately. The geometry reuses existing materials, head meshes, and hand joints. Long-pole carry and checking poses follow the same event system as the existing clips.

Lua tests used mocked Craft. They cover shot, clear, and crease violations, midfield counts on both teams, blocked and legal crossings, legal boundary restarts, both specialist loadouts, simulated equipment and hand alignment, and existing match and career paths.

Live substitutions, full penalty service and man-down play, the new dodge and contextual controls, and Clubs are pending. This milestone has no online match or two-device test. Native iPhone testing is still pending.
