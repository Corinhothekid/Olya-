# PolyLax 2.0.2

The career Development screen could fail before drawing the upgrade controls. The Previous button's font-size expression evaluated to the boolean `true`. Codea requires a number. Previous and Next now both use 17-point labels. Other Development buttons use 12-point labels.

## Install

- **Single Main tab.** Back up the project and replace Main with the complete `PolyLax-2.0.2-Full-Lua-Code.txt`. The final line is `-- End of PolyLax 2.0.2`.
- **Existing multi-tab project.** Replace the complete `Development` tab with `Development.lua`. Keep using the existing project to access its saved career.

## Verify

Open **Career → Development**. Tap Next and Previous. With enough skill points, tap an upgrade and confirm that the rating increases by one and the displayed cost comes out of the balance. Close and reopen the project to confirm that the rating and balance persist.

The crash was reproduced using a Lua mock that enforces the `fontSize` argument type. Lua checks cover Development rendering, paging, upgrades with and without available points, and reloading the saved rating and balance. Device testing still needs to be done in Codea.
