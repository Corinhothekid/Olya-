# PolyLax Web

This Babylon.js prototype uses PolyLax 3.1 as its source. The baseline is commit [`02a9e9d`](https://github.com/Corinhothekid/Olya-/commit/02a9e9d6e14cd947c564e72c3808971e8d34c0ac) on `codex/polylax-2.0`, with all 37 Codea tabs and its 15,021-line `releases/PolyLax-3.1-Main.lua`. The browser branch changes files inside `polylax-web` only.

## Run in Babylon.js Playground

1. Open the [Babylon.js Playground](https://playground.babylonjs.com/) and select **JavaScript** mode.
2. Open the raw version of [`playground.js`](./playground.js). Copy the entire file through `// End of PolyLax Web`, replace the editor contents, and tap **Run**. The Playground supplies `BABYLON`, the rendering canvas, and `engine`.
3. Give the preview the full width by hiding the editor or opening the preview **Full Screen**. Choose **Quick Play** for a full match or a six-player practice. On desktop, use **WASD** or the arrow keys to move, **E** to pass or poke, **Space** to shoot or clamp, **Q** to dodge, and **Shift** to sprint.

The standalone page uses the same JavaScript. Serve it over HTTP on your development machine.

```sh
cd polylax-web
python3 -m http.server 8080
```

Open `http://localhost:8080/`. The standalone page loads Babylon.js 8.32.0 from a CDN. The Playground uses its installed Babylon version. Geometry, animation, and game data ship in the source with no downloaded models or textures.

## iPhone test

Open the Playground preview full-screen in Safari, or serve `index.html` from a host the phone can reach. In portrait orientation, choose **Quick Play**, take a faceoff, then run while passing or shooting with your second thumb. Hold Shoot and move the target before release. Check that the clock advances, opposing players contest possession, goals update the score, and the field fits above the controls. Then set a player position in **Be a Pro** and confirm that Player Lock stays on that athlete when possession changes. Relaunch the page on the same origin to check the local profile.

Physical iPhone verification is still required. Browser emulation checks screen dimensions and touch input. Running in Linux WebGL does not verify Safari's device GPU, power use, or browser UI.

## Source map and scope

| Browser module | PolyLax 3.1 source used |
|---|---|
| `simulation.js` | FullMatch, Gameplay, Passing, MatchAI, Midfield, GoalPhysics and Faceoff |
| `renderer.js` | Field, Character, AnimationController, TeamUniform and CameraController |
| `interface.js` | Main, Style and UI |
| `career.js` | Career's separate athlete identity and completed-match records |

The prototype ports the on-field loop. It uses procedural Babylon models, local match physics, and streamlined tactical AI. Its browser **Be a Pro** mode is a local Player Lock scrimmage with a saved profile and result history. Full Codea season saves, recruiting, awards, substitutions, and relay-backed **PolyLax Clubs** are outside this milestone. The Clubs card displays the browser feature status. Codea saves remain independent of browser storage.

## Build and check

```sh
npm run build
npm run check
npm test
```

`npm run build` combines the JavaScript source modules into the complete Playground file. `npm run check` verifies that it matches the modules and parses as JavaScript.

The automated checks covered the on-field simulation, Player Lock saves, desktop WebGL2, and 390 × 664 and 390 × 844 touch layouts in Chromium. The browser smoke test uses both the standalone page and a harness with the Playground's `engine` and `createScene` entry points.

```sh
python3 -m pip install playwright
python3 tests/browser_smoke.py --chromium /path/to/chromium
```
