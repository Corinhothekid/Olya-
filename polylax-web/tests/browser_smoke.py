"""Run the PolyLax standalone page and Playground bundle in Chromium.

Build with `npm run build` first. Install Python Playwright and either its
Chromium binary or a system Chromium. Mobile runs use emulation.
"""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
from threading import Thread

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
BABYLON = "https://cdn.jsdelivr.net/npm/babylonjs@8.32.0/babylon.js"
PLAYGROUND_HOST = f"""<!doctype html>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>
html,body,#holder {{ width:100%; height:100%; margin:0; overflow:hidden; }}
#holder {{ position:relative; }}
#renderCanvas {{ display:block; width:100%; height:100%; touch-action:none; }}
</style>
<div id="holder"><canvas id="renderCanvas"></canvas></div>
<script src="{BABYLON}"></script>
<script src="/playground.js"></script>
<script>
var canvas = document.getElementById('renderCanvas');
var engine = new BABYLON.Engine(canvas, true);
window.polylaxScene = createScene();
engine.runRenderLoop(() => window.polylaxScene.render());
window.addEventListener('resize', () => engine.resize());
</script>
""".encode("utf-8")


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/playground-host.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(PLAYGROUND_HOST)))
            self.end_headers()
            self.wfile.write(PLAYGROUND_HOST)
            return
        super().do_GET()

    def log_message(self, *_args):
        return


META = "window.polylaxScene.metadata.polylax"


def button(page, action):
    return page.locator(f'.plx-ui [data-action="{action}"]:visible').first


def wait_for_mode(page, mode):
    page.wait_for_function(f"mode => {META}.mode === mode", arg=mode)


def active_player(page):
    return page.evaluate("""() => {
        const {match} = window.polylaxScene.metadata.polylax;
        const {x, z} = match.players.find(p => p.id === match.controlled);
        return { x, z };
    }""")


def inspect_scene(page):
    page.wait_for_function("() => window.polylaxScene?.metadata?.polylax?.match")
    info = page.evaluate("""() => {
        const scene = window.polylaxScene;
        const canvas = scene.getEngine().getRenderingCanvas();
        const bounds = canvas.getBoundingClientRect();
        return {
            webgl: scene.getEngine().webGLVersion,
            meshes: scene.meshes.length,
            inside: bounds.width <= innerWidth + 1 && bounds.height <= innerHeight + 1,
            sceneWidth: bounds.width,
            sceneHeight: bounds.height,
            pointer: navigator.maxTouchPoints
        };
    }""")
    assert info["webgl"] >= 1 and info["meshes"] > 20, info
    assert info["inside"] and info["sceneWidth"] > 300 and info["sceneHeight"] > 450, info
    return info


def capture_errors(page):
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    return errors


def open_page(browser, settings, base, path, babylon):
    context = browser.new_context(**settings)
    if babylon:
        context.route(BABYLON, lambda route: route.fulfill(path=babylon, content_type="application/javascript"))
    page = context.new_page()
    errors = capture_errors(page)
    page.goto(f"{base}/{path}", wait_until="load")
    info = inspect_scene(page)
    wait_for_mode(page, "menu")
    return page, errors, info


def command_on_release(page, action, mobile):
    control = page.locator(f'.plx-ui [data-play="{action}"]')
    if mobile:
        control.tap()
    else:
        control.click()


def start_quick(page, mode, mobile):
    for action in ("quick", "play-" + mode):
        control = button(page, action)
        if mobile:
            control.tap()
        else:
            control.click()
    wait_for_mode(page, mode)


def mobile_play(browser, phone, base, path, babylon):
    page, errors, info = open_page(browser, phone, base, path, babylon)
    assert info["pointer"] > 0, info
    start_quick(page, "practice", mobile=True)
    assert page.evaluate(f"() => {META}.match.players.length") == 7
    assert page.evaluate(f"() => {META}.match.ball.owner === {META}.match.controlled")

    joystick = page.locator('.plx-ui [data-ui="joystick"]')
    box = joystick.bounding_box()
    assert box is not None and box["width"] >= 60, box
    x, y = box["x"] + box["width"] * .5, box["y"] + box["height"] * .5
    before = active_player(page)
    touch = page.context.new_cdp_session(page)
    touch.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": x, "y": y, "id": 1}]})
    held = {"x": x + 27, "y": y - 27, "id": 1}
    touch.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [held]})
    page.wait_for_function(f"() => {META}.controls.x < -.25 && {META}.controls.z < -.25")
    page.wait_for_function(f"start => {{ const m = {META}.match; const p = m.players.find(p => p.id === m.controlled); return p.x < start.x - .2 && p.z < start.z - .2; }}", arg=before)
    sprint = page.locator('.plx-ui [data-hold="sprint"]').bounding_box()
    assert sprint is not None
    second = {"x": sprint["x"] + sprint["width"] * .5, "y": sprint["y"] + sprint["height"] * .5, "id": 2}
    touch.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [held, second]})
    page.wait_for_function(f"() => {META}.controls.sprint && {META}.controls.z < -.25")
    touch.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
    page.wait_for_function(f"() => {META}.controls.x === 0 && {META}.controls.z === 0 && !{META}.controls.sprint")

    command_on_release(page, "pass", mobile=True)
    page.wait_for_function(f"() => {META}.match.ball.state === 'pass'")
    button(page, "pause").tap()
    paused_clock = page.evaluate(f"() => {META}.match.clock")
    page.wait_for_timeout(150)
    assert page.evaluate(f"() => {META}.match.clock") == paused_clock
    button(page, "restart").tap()
    assert page.evaluate(f"() => {META}.match.ball.owner === {META}.match.controlled")
    command_on_release(page, "shoot", mobile=True)
    page.wait_for_function(f"() => {META}.match.ball.state === 'shot'")
    button(page, "pause").tap()
    button(page, "exit").tap()
    wait_for_mode(page, "menu")
    assert not errors, errors
    print(f"{path}: mobile {info['sceneWidth']:.0f}×{info['sceneHeight']:.0f} WebGL{info['webgl']}, practice move, multitouch, pass, shot, and pause passed")
    page.context.close()


def desktop_play(browser, base, babylon):
    page, errors, info = open_page(browser, {"viewport": {"width": 1280, "height": 800}}, base, "index.html", babylon)
    start_quick(page, "quick", mobile=False)
    assert page.evaluate(f"() => {META}.match.players.length") == 20
    page.wait_for_function(f"() => ['FACEOFF', 'LIVE'].includes({META}.match.phase)")
    if page.evaluate(f"() => {META}.match.phase") == "FACEOFF":
        command_on_release(page,"shoot",mobile=False)
    page.wait_for_function(f"() => {META}.match.phase === 'LIVE'")
    before = active_player(page)
    page.keyboard.down("W")
    page.wait_for_function(f"start => {{ const m = {META}.match; return m.players.find(p => p.id === m.controlled).z < start.z - .2; }}", arg=before)
    page.keyboard.up("W")
    button(page, "camera").click()
    button(page, "pause").click()
    button(page, "exit").click()

    button(page, "career").click()
    page.locator('.plx-ui [data-ui="name"]').fill("Browser Athlete")
    page.locator('.plx-ui [data-ui="number"]').fill("27")
    page.locator('.plx-ui [data-ui="position"]').select_option("D")
    button(page, "play-career").click()
    wait_for_mode(page, "career")
    assert page.evaluate(f"() => {META}.profile") == {"name": "Browser Athlete", "number": 27, "position": "D"}
    assert page.evaluate(f"() => {{const m={META}.match; return m.players.find(p => p.id === m.controlled).name;}}") == "Browser Athlete"
    page.wait_for_function('document.querySelector(\'.plx-ui [data-direct="switch"]\').disabled')
    button(page, "pause").click()
    button(page, "exit").click()
    button(page, "clubs").click()
    assert "pending" in page.locator('.plx-ui [data-page="clubs"]').inner_text().lower()
    page.reload(wait_until="load")
    inspect_scene(page)
    assert page.evaluate(f"() => {META}.profile.name") == "Browser Athlete"
    assert not errors, errors
    print(f"index.html: desktop WebGL{info['webgl']}, 10v10, keyboard/camera, Player Lock/profile persistence, and Clubs status passed")
    page.context.close()


def run(browser, device, base, babylon):
    for path, height in (("index.html", 664), ("playground-host.html", 844)):
        phone = {**device, "viewport": {"width": 390, "height": height}}
        mobile_play(browser, phone, base, path, babylon)
    desktop_play(browser, base, babylon)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--babylon", type=Path, help="Use a local copy of the exact Babylon CDN script")
    parser.add_argument("--chromium", default=shutil.which("chromium"), help="Chromium executable path")
    args = parser.parse_args()
    if args.babylon and not args.babylon.is_file():
        parser.error("--babylon must point to the downloaded browser JavaScript")
    if not (ROOT / "playground.js").is_file():
        parser.error("Missing playground.js. Run npm run build first.")

    with ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(ROOT))) as server:
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(executable_path=args.chromium, headless=True, args=[
                    "--disable-breakpad", "--disable-crash-reporter", "--use-gl=angle",
                    "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                ])
                try:
                    run(browser, p.devices["iPhone 13"], base, args.babylon)
                finally:
                    browser.close()
        finally:
            server.shutdown()
            thread.join()


if __name__ == "__main__":
    main()
