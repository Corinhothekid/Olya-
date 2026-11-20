const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const src = fs.readFileSync(path.join(__dirname, "../src/simulation.js"), "utf8");
const LacrosseMatch = vm.runInNewContext(src + "\nLacrosseMatch");

function advance(match, seconds, controls) {
    for (let time = 0; time < seconds; time += 1 / 60) match.update(1 / 60, controls);
}

function give(match, id, x, z) {
    const p = match.players[id];
    p.x = x;
    p.z = z;
    p.yaw = p.team === 0 ? 0 : Math.PI;
    p.vx = p.vz = 0;
    match.phase = "LIVE";
    match.attach(p);
}

test("practice starts with six attackers and a keeper; carrying follows the animated pocket", () => {
    const match = new LacrosseMatch({ mode: "practice" });
    assert.equal(match.phase, "LIVE");
    assert.equal(match.teams[0].length, 6);
    assert.equal(match.teams[1].length, 1);
    assert.equal(match.ball.owner, 0);
    const player = match.players[0];
    advance(match, .45, { x: 1, z: 0 });
    assert.ok(player.x > -3.3);
    assert.equal(match.ball.state, "held");
    const pocket = match.pocket(player);
    assert.equal(pocket.x, match.ball.x);
    assert.equal(pocket.z, match.ball.z);
    assert.ok(match.command("dodge", { x: 0, z: -1 }));
    const previous = player.z;
    advance(match, .25);
    assert.ok(player.z < previous - 1);
});

test("pass releases after windup, reaches intended teammate, and follows possession", () => {
    const match = new LacrosseMatch({ mode: "practice" });
    assert.equal(match.passTarget(1, 0), 1);
    assert.ok(match.command("pass", { x: 1, z: 0 }));
    advance(match, .12);
    assert.equal(match.ball.owner, 0);
    advance(match, .22);
    assert.equal(match.ball.owner, null);
    assert.equal(match.ball.state, "pass");
    advance(match, .7);
    assert.equal(match.ball.owner, 1);
    assert.equal(match.controlled, 1);
    assert.equal(match.players[0].stats.passes, 1);
    assert.equal(match.players[0].stats.completions, 1);
});

test("shot crosses the goal plane, scores, then practice restarts", () => {
    const match = new LacrosseMatch({ mode: "practice", seed: 2 });
    give(match, 0, .1, -10.5);
    assert.ok(match.command("shoot", { aimX: .7, aimY: .36 }));
    advance(match, .40);
    assert.equal(match.ball.state, "shot");
    advance(match, .28);
    assert.equal(match.phase, "GOAL");
    assert.equal(match.ball.state, "net");
    assert.equal(match.scores[0], 1);
    advance(match, 1.9);
    assert.equal(match.phase, "LIVE");
    assert.equal(match.players[match.ball.owner].team, 0);
});

test("keeper can save a central shot and does not strand practice possession", () => {
    const match = new LacrosseMatch({ mode: "practice", seed: 33 });
    give(match, 0, .2, -7.5);
    assert.ok(match.command("shoot", { aimX: 0, aimY: 1.32 }));
    advance(match, .78);
    assert.equal(match.scores[0], 0);
    assert.equal(match.players[6].stats.saves, 1);
    advance(match, 1.3);
    assert.equal(match.players[match.ball.owner].team, 0);
});

test("full match has 10v10, timed faceoffs, legal half counts, and period flow", () => {
    const match = new LacrosseMatch({ seed: 8, periodLength: 5 });
    assert.equal(match.players.length, 20);
    assert.equal(match.teams[0].length, 10);
    assert.equal(match.teams[1].length, 10);
    advance(match, 1.05);
    assert.ok(match.faceoff.progress > match.faceoff.windowStart);
    assert.ok(match.command("faceoff"));
    advance(match, .6);
    assert.equal(match.phase, "LIVE");
    assert.equal(match.players[match.ball.owner].team, 0);
    for (let frame = 0; frame < 900; frame++) {
        match.update(1 / 60, { x: 0, z: frame < 480 ? -1 : 1, sprint: true });
        for (const team of match.teams) {
            const forward = team.filter(p => p.offenseHalf).length;
            assert.ok(forward >= 3 && forward <= 6, "illegal midfield count: " + forward);
        }
    }
    assert.equal(match.period, 2);
    assert.equal(match.phase, "FINAL");
    assert.ok(match.command("reset"));
    assert.equal(match.elapsed, 0);
    assert.equal(match.nextAITick, 0);
});

test("Be a Pro keeps its chosen pole position and can call for a pass", () => {
    const match = new LacrosseMatch({ mode: "career", position: "LSM", name: "River", number: 74 });
    const lock = match.controlled;
    const p = match.players[lock];
    give(match, 0, -8, -10);
    p.x = -10; p.z = -9;
    assert.equal(match.controlled, lock);
    assert.equal(p.specialty, "LSM");
    assert.equal(p.number, 74);
    assert.equal(p.name, "River");
    assert.equal(p.longPole, true);
    assert.equal(match.command("switch"), false);
    assert.ok(match.command("pass"));
    advance(match, .75);
    assert.equal(match.ball.owner, lock);
    assert.equal(match.players[0].stats.completions, 1);
});

test("defensive checking dislodges possession and creates a recoverable ball", () => {
    const match = new LacrosseMatch();
    give(match, 13, 2, -.7);
    match.controlled = 3;
    match.players[3].x = 2;
    match.players[3].z = .1;
    match.players[13].protection = 0;
    assert.ok(match.command("poke"));
    assert.equal(match.ball.state, "loose");
    assert.equal(match.ball.owner, null);
    assert.equal(match.players[3].stats.checks, 1);
});
