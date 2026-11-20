# PolyLax 3.2 cinematic menu

The home screen runs a dedicated looping Craft scene using the existing field, uniforms, character rigs, and action animations. Its camera moves from a wide field view into a player tracking shot. The sequence plays a dodge, releases a shot into the net, and shows a goal celebration before returning to the wide shot. It creates the field, athletes, camera, and ball once per app session and advances them only on the home screen. No showcase result affects Quick Play, Be a Pro, or Clubs.

## Update the existing Codea project

Back up your project, then replace its single Main with the full `PolyLax-3.2-Full-Lua-Code.txt`. Paste through `-- End of PolyLax 3.2`. This keeps your project's imported assets and local saves.

For a multi-tab 3.1 project, replace `Main`, `Style`, and `ClubsUI`. Add `MenuAssets` and `MenuShowcase`. The tabbed ZIP contains the whole project. Imports and saves belong to your current Codea project, so keep using it to access them.

## Logo and theme

The asset picker keys are `asset.PolyLaxLogo` and `asset.PolyLaxTheme` for project imports with those names. Files in **Documents** can resolve from `asset.documents.PolyLaxLogo` and `asset.documents.PolyLaxTheme`. The code uses Codea's resolved asset keys, including their actual extensions when lookup is ambiguous. If the logo is unavailable, the home screen displays the PolyLax wordmark in text. The theme is optional and plays after input while the home screen is open. **Settings → Menu Music** controls the saved mute setting. [Codea asset keys](https://www.codea.io/reference/Graphics.html#assetskey) · [Codea music API](https://www.codea.io/reference/Sounds.html#music)

The imported artwork and audio are stored on your device and are absent from the source repository. If you install a fresh project from the ZIP, import the files there through the Codea asset picker.

## Verify

Let the home screen run through two loops. Confirm the logo and menu cards stay legible, including during the shot and celebration. Open Quick Play, Be a Pro, PolyLax Clubs, and Settings and return from each. Toggle Menu Music, return home, then close and reopen Codea to check the setting. Try without the optional assets to verify the text and silence fallbacks.

Lua 5.4 syntax and mocked Craft tests cover the complete build, the loop, the existing animation releases, menu navigation, optional assets, and unchanged save data. Rendering and the imported files still need a native iPhone check.
