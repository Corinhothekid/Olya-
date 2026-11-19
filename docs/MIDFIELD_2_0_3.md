# PolyLax 2.0.3 midfield positioning

Full Match and career fixtures use the same midfield rule. Each team keeps at least three players toward the goal it attacks and at least four toward the goal it defends, including its goalie. A player on the line counts on the side they came from. A defender and a midfielder can exchange halves on the same frame, and either team's defensive half can legally contain seven players.

The match checks both teams' proposed movement before moving and animating players. When the controlled player approaches a blocked crossing, a midfield notice explains how much cover must stay. Attempting the crossing stops the player at midfield and displays **OFFSIDES**. PolyLax keeps the current possession on a blocked crossing.

The AI sends three attackmen and three midfielders into settled offense and keeps its defense and goalie back. When defending it leaves the attackmen up and brings midfield help back. When a user-controlled outfielder needs to change halves, it can send a midfielder in the opposite direction to cover. Long-stick and short-stick defensive midfielder roles use the same midfield coverage rules.

Career entry uses the existing shared match engine. The rule module also validates projected counts for a proposed substitution. There is currently no bench substitution interface in this project.

## Install

- **Single Main tab.** Back up the project and replace Main with the complete `PolyLax-2.0.3-Full-Lua-Code.txt`. The final line is `-- End of PolyLax 2.0.3`.
- **Existing multi-tab project.** Add the `Midfield` tab and replace `Main`, `FullMatch`, `MatchAI`, `Field`, and `UI` with their complete 2.0.3 files. The Codea ZIP includes all tabs. Update the existing project to retain access to its local save.

## Verify

1. Start a Full Match and play through a faceoff, a clear, and a turnover. Watch the midfield line and each team's movement across it.
2. When six teammates are already in attack, sprint a seventh player toward midfield. Check that the notice appears and the player waits for cover. Repeat when only three players are up and one of them attempts to return.
3. Open a career fixture as an attackman, midfielder, or defender. Try a legal midfield exchange, then return to the career menu and check season progress.

The Lua checks use a mocked Craft runtime. Native rendering and controls on iPhone still need a device check.
