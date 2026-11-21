# PolyLax 3.2.1 cinematic menu assets

The front menu uses your imported `asset.logo` over the live Craft showcase. It loads the image once and fits it above the menu cards. The existing camera sequence cycles through running, a dodge, a shot, and the goal celebration.

The soundtrack uses `music(asset.Main_Menu_Melody, true, .48)` through the confirmed project key. It starts when the unmuted front menu opens. The loop runs through Codea's music player. On leaving the front menu, PolyLax stops its own track and remembers its playback position for the return. **Settings → Menu Music** keeps its existing saved mute preference. The menu falls back to text and silence if the corresponding media fails to load. [Codea music reference](https://www.codea.io/reference/Sounds.html#music) · [Codea image loading](https://www.codea.io/reference/Storage.html#readImage)

## Install in your existing Codea project

- For a single-tab project, back up Main and replace its entire contents with `PolyLax-3.2.1-Full-Lua-Code.txt`. Paste through `-- End of PolyLax 3.2.1`.
- For an existing multi-tab **3.2 cinematic** project, replace `Main`, `MenuAssets`, `ClubsUI`, and `Style` with the corresponding tabs in the complete 3.2.1 ZIP. If your project predates the cinematic update, use all 39 tabs in the ZIP, including `MenuShowcase`.

Make the update in the same Codea project to keep access to your imported logo, soundtrack, and career saves. The ZIP supplies the Lua project files. Your media already lives on the device.

## Check in Codea

Run the existing project with Menu Music on. The soundtrack should start before a tap, and the logo should appear above the menu cards. Watch the showcase repeat, then open Quick Play, Be a Pro, PolyLax Clubs, and Settings. Start Practice, return home, and toggle Menu Music to verify stop, resume, and mute. In a backup project, test playback with the optional files unavailable to confirm the fallback.

All Lua tabs and the complete Main were syntax-checked with Lua 5.4. The regression uses mocked Craft and Codea media APIs to check the exact keys, menu entry, looping arguments, stop/resume, errors, and existing navigation. The imported files and installed Codea runtime still need a device check.
