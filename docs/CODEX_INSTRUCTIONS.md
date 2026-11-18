# Codex instructions for PolyLax

## Mission
Maintain and extend PolyLax, a portrait iPhone lacrosse game written in Lua for Codea and its Craft 3D engine.

## Critical safeguards
- **Do not rewrite from scratch.** Audit the archived builds and any new user-provided source first.
- **Never assume the highest numbered archive is the most complete.** Build 009.4 introduced regressions; animation preservation is a priority.
- Do not claim Codea device testing unless actually performed.
- Preserve existing animations, controls, creator, gameplay, and user assets.
- Create a branch for new work, make small commits, and document regressions and tests.
- The `archive/` files are immutable historical snapshots. Work in a separate active project directory after obtaining the latest source from the user's iPhone.
- The user's actual newest game source has **not** been provided to this repository yet. Ask for it before integrating new features.

## Product targets
- Full-head, properly fitted Cascade XRS Pro-inspired low-poly helmet, attached to the head joint without clipping.
- Accurate goal-plane detection with swept segment collision. A valid goal should register once and stop/settle the ball inside the net, rather than pass through.
- Replace free-form jersey color selection with eight PLL team presets: Utah Archers, New York Atlas, Boston Cannons, Carolina Chaos, Denver Outlaws, California Redwoods, Philadelphia Waterdogs, Maryland Whipsnakes. Apply palettes to all players and the goalkeeper. Verify palette accuracy; official branding requires licensing for commercial distribution.
- Preserve six-player practice mode.
- Build a 10v10 full-field game (3 attack, 3 midfield, 3 defense, 1 goalkeeper per side), with team-aware movement, offensive and defensive AI, transitions, faceoffs, clearing, riding, goalkeepers, scoring and game clock.
- Implement a hold-to-aim shooting guide and physical ball trajectories.
- Long term: career mode with created player, player lock, season schedules, progression, statistics, playoffs, and persistent save data.

## Implementation order
1. Compare historical builds and obtain the latest working Codea source.
2. Establish a runnable baseline, documenting known issues.
3. Fix helmet and net collision with focused tests.
4. Add team selection and verify whole-roster uniform propagation.
5. Add full-field match mode incrementally, keeping practice mode.
6. Expand goalie/defensive AI, match rules, and career systems.

## Codea considerations
- Use Codea/Craft APIs rather than assuming Unity or Love2D equivalents.
- Existing code used `scene:entity()`, `craft.model.cube()`, `craft.material("Materials:Standard")`, and `scene:update(dt)` / `scene:draw()`.
- Check actual camera orientation and viewport obstruction by the portrait UI.
- Deliver complete files or complete Codea tabs with clear installation instructions.
- Record what is statically checked versus device-tested.

## Current source inventory
`archive/PolyLax_Build_005_Main.lua`
`archive/PolyLax_Build_007_Main.lua`
`archive/PolyLax_Build_009_Main.lua`
`archive/PolyLax_Build_009_1_Main.lua`
`archive/PolyLax_Build_009_4_Main.lua`

These files are historical backups and may not represent the current game on the user's phone.
