# PolyLax Build 012

The active `PolyLax.codea` project starts from the workspace's Build 011 Gameplay. GitHub's five historical builds remain under `archive/`. The branch's first commit preserves the workspace baseline.

## Stage 1 · Mobile HUD and camera

Changed `Main.lua`, `UI.lua`, `CameraController.lua`, `Gameplay.lua`, and `FullMatch.lua`. The creator retains its original preview framing and controls. Play modes share a safe-area HUD, touch feedback, contextual buttons, and a hold-to-sprint control.

In Codea Legacy Craft, open Practice. Hold Sprint with one finger while walking with the joystick. Hold Shoot with a second finger, drag, and release. Cycle the camera through Dynamic, Broadcast, and Player Lock and test both zoom buttons. In Broadcast verify both goals and the full field remain visible on a phone in portrait. Start Full Game and play its existing faceoff.

Lua mocks passed three HUD sizes and six camera sizes, plus the creator, simultaneous joystick/sprint, hold-to-aim and mode entry checks. Native Codea rendering and touch response remain to be checked.
