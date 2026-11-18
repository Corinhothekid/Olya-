# PolyLax 🥍

Portrait-oriented 3D lacrosse game prototype for **Codea (Lua + Craft)** on iPhone.

## Repository status
This repository archives available historical PolyLax builds. **These are snapshots, not verified working releases.** Do not assume the newest build contains all earlier animations.

## Source layout
- `archive/`: historical standalone `Main.lua` versions. Preserve unchanged for regression comparisons.
- `docs/CODEX_INSTRUCTIONS.md`: development guidance and priorities.

## Running a historical build
Open Codea on iPhone, create a project, and paste the contents of a selected archived `Main.lua` into its Main tab. Test each build separately.

## Development priorities
1. Restore and preserve animations.
2. Fix creator camera and XRS Pro-inspired helmet fit.
3. Implement robust goal-plane collision and ball settling in the net.
4. Add selectable PLL-inspired team palettes and propagate uniforms to the full roster.
5. Add full-field 10v10 play, goalkeeper/defensive AI, and eventually career mode.

**Important:** The latest Codea source currently running on the user's device may be newer than the archived versions here. Obtain and commit that source before attempting a merge or claiming a feature is restored.
