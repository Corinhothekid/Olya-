# PolyLax 3.0 rules milestone

Full Match and Career share one rules module and the same midfield resolver. The resolver keeps at least three players in attack and four in defense, including the goalie. Opposite-direction exchanges are evaluated together. In the competition profiles, an attempted offensive offsides crossing with possession awards the ball to the opposing team. Other blocked crossings display a positioning notice.

Career applies the appropriate league profile and keeps the existing two short periods. Exhibition keeps the arcade timing unless a caller selects `profile` in `FullMatch.new`. The rules module accepts `arcade`, `highSchool`, `ncaa`, `collegeClub`, and `professional`, with per-match timing and field overrides.

| Profile | Default quarters | Possession clock | Clear clock |
|---|---:|---|---:|
| High school | 4 × 12 min | Optional state 70-second clock with `stateShotClock=true` | 20 s under the 2027 rule |
| NCAA men’s | 4 × 15 min | 80 s, qualifying in-zone recovery 60 s | 20 s |
| MCLA club | 4 × 15 min | NCAA 80/60 procedure | 20 s |
| Professional | 4 × 12 min | 52 s, 32 s after a faceoff | 20 s |

Competition profiles also count time with possession in the defending crease, detect over and back, and award shots out of bounds by the closest inbounds player at the boundary. Rules violations use the existing possession and statistics paths. The pro field uses the published 100-yard length.

The Codea build still uses its existing game clock and period transitions. It has simplified defensive offsides, crease contact, and foul handling. It does not yet implement full league penalty service, man-down lineups, live substitutions, or league overtime and stoppage schedules.

Rule references [NFHS 2027](https://www.nfhs.org/sports/lacrosse-boys/rules) · [NCAA men’s rulebook](https://ncaaorg.s3.amazonaws.com/championships/sports/lacrosse/rules/men/PRMLA_RulesBook.pdf) · [MCLA rule adoption](https://mcla.us/articles/2025-summer-meeting-recap) · [PLL 2024 rulebook](https://premierlacrosseleague.com/wp-content/uploads/2024/03/2024-PLL-Rulebook.pdf) · [2026 USA Lacrosse comparisons](https://www.usalacrosse.com/sites/default/files/documents/Rules/Mens-Rule-Comparisons-2026.pdf)

Lua checks with mocked Craft cover profile configuration, the shot and clear clocks, the crease count, over and back, live restarts, midfield counts, existing tactics, and the career menu and save flow. Native Codea verification is pending.
