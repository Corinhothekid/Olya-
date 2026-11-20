// PolyLax Web | Paste this entire file into the Babylon.js Playground JavaScript editor.
// Source modules are in polylax-web/src. Run npm run build after editing them.

var createScene = function () {
'use strict';

// The match model is independent of Babylon, DOM input, and frame rendering.
// Ported behavior follows FullMatch, Gameplay, Passing, Midfield, Faceoff and GoalPhysics.
const laxClamp = (value, min, max) => Math.max(min, Math.min(max, value));
const laxSide = team => team === 0 ? -1 : 1;
const laxHypot = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const laxClock = (value, fallback) => Number.isFinite(value) ? value : fallback;
const laxRoles = ["A", "A", "A", "M", "M", "M", "D", "D", "D", "G"];
const laxPositions = { A: 0, M: 4, D: 6, F: 3, G: 9, LSM: 4, SSDM: 5 };
const laxNumbers = [8, 12, 19, 24, 4, 17, 31, 9, 42, 1];
const laxNames = ["Reed", "Hayes", "Brooks", "Cross", "Bennett", "Price", "Rowan", "Hart", "Dean", "Cole"];
const laxBallRadius = .09;
const laxGravity = 9.8;
const laxAngleError = (target, current) => Math.atan2(Math.sin(target - current), Math.cos(target - current));

function laxInput(value) {
    const x = laxClock(value.x, 0);
    const z = laxClock(value.z, 0);
    const magnitude = Math.hypot(x, z);
    return { x: x / Math.max(1, magnitude), z: z / Math.max(1, magnitude), magnitude: Math.min(1, magnitude) };
}

function laxClosestOnSegment(start, end, p) {
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const dz = end.z - start.z;
    const t = laxClamp(((p.x - start.x) * dx + (p.y - start.y) * dy +
        (p.z - start.z) * dz) / Math.max(.00001, dx * dx + dy * dy + dz * dz), 0, 1);
    return Math.hypot(start.x + dx * t - p.x, start.y + dy * t - p.y, start.z + dz * t - p.z);
}

function laxDepthIntersection(start, end, z) {
    const advance = end.z - start.z;
    if (Math.abs(advance) < .000001) return null;
    const time = (z - start.z) / advance;
    if (time < 0 || time > 1) return null;
    return { x: start.x + (end.x - start.x) * time, y: start.y + (end.y - start.y) * time, z };
}

function laxStats() {
    return { goals: 0, assists: 0, passes: 0, completions: 0, shots: 0, shotsOnGoal: 0, saves: 0,
        checks: 0, interceptions: 0, turnovers: 0, groundBalls: 0, faceoffs: 0 };
}

class LacrosseMatch {
    constructor(options = {}) {
        this.options = { ...options };
        this.mode = ["practice", "career"].includes(options.mode) ? options.mode : "quick";
        this.practice = this.mode === "practice";
        this.playerLock = this.mode === "career";
        this.halfWidth = this.practice ? 9 : 27.432;
        this.halfLength = this.practice ? 17 : 50.292;
        this.goalZ = this.practice ? 13 : 36.576;
        this.goalHalfWidth = .9144;
        this.goalTop = 1.8288;
        this.creaseRadius = this.practice ? 1.8 : 2.7432;
        this.periods = this.practice ? 1 : 2;
        this.periodLength = laxClamp(laxClock(options.periodLength, this.practice ? 120 : 60), 5, 300);
        this.teamNames = options.teamNames || ["Harbor", "Forge"];
        this.teamShorts = options.teamShorts || ["HBR", "FRG"];
        this.homeName = this.teamNames[0];
        this.awayName = this.teamNames[1];
        this.reset();
    }

    reset() {
        this.players = [];
        this.teams = [[], []];
        this.scores = [0, 0];
        this.stats = [laxStats(), laxStats()];
        this.clock = this.periodLength;
        this.period = 1;
        this.elapsed = 0;
        this.rng = Math.trunc(laxClock(this.options.seed, 33)) >>> 0;
        this.ball = { x: 0, y: laxBallRadius, z: 0, owner: null, team: null, state: "dead", vx: 0, vy: 0, vz: 0 };
        this.pending = this.flight = this.assist = null;
        this.lastTeam = 0;
        this.lastTouch = null;
        this.noticeTime = 0;
        this.announcement = "";
        this.nextDecision = this.nextAITick = 0;
        this.practiceRestart = null;
        this.shotClock = null;
        this.pressers = [null, null];
        this.chasers = [null, null];
        if (this.practice) {
            const drill = [[-4.6, -1.2, "M", "M1"], [4.6, -1.2, "M", "M2"],
                [0, -9.8, "M", "M3"], [-6.3, -8.2, "A", "A1"], [6.3, -8.2, "A", "A2"], [0, -16, "A", "X"]];
            for (const [slot, [x, z, role, name]] of drill.entries()) this.addPlayer(0, slot, role, x, z, name);
            this.addPlayer(1, 9, "G", 0, -11.8);
            this.controlled = 0;
            this.careerPlayer = null;
            this.phase = "LIVE";
            this.phaseTime = 0;
            this.faceoff = null;
            this.attach(this.players[0]);
            this.announce("Practice · move, pass, or take a shot", 2.8);
            return;
        }
        const shape = [[-13, 29], [13, 29], [0, 43], [0, -.64],
            [-18.288, 3], [18.288, 3], [-12, -24], [12, -24], [0, -29], [0, -(this.goalZ - 1.18)]];
        const position = this.options.position || "M";
        this.careerPlayer = this.playerLock ? laxPositions[position] ?? 4 : null;
        for (const team of [0, 1]) {
            const side = laxSide(team);
            for (const [slot, [x, z]] of shape.entries()) {
                const user = team === 0 && slot === this.careerPlayer;
                const player = this.addPlayer(team, slot, laxRoles[slot], -side * x, side * z,
                    user && this.options.name ? this.options.name : null);
                if (user) {
                    player.specialty = position;
                    player.longPole = player.longPole || position === "LSM";
                    if (Number.isInteger(this.options.number)) player.number = laxClamp(this.options.number, 0, 99);
                }
            }
        }
        this.startFaceoff();
    }

    addPlayer(team, slot, role, x, z, name) {
        const player = {
            id: this.players.length, team, slot, role, name: name || laxNames[(slot + team * 4) % laxNames.length],
            number: laxNumbers[slot], longPole: role === "D", homeX: x, homeZ: z, x, z, yaw: team * Math.PI,
            vx: 0, vz: 0, speed: 0, stamina: 1, running: false, action: "idle", actionTime: 0, actionDuration: 0,
            protection: 0, checkCooldown: 0, dodgeTime: 0, dodgeX: 0, dodgeZ: 0, screenTime: 0,
            offenseHalf: z * laxSide(team) > 0, stats: laxStats()
        };
        this.players.push(player);
        this.teams[team].push(player);
        return player;
    }

    random() {
        this.rng = (Math.imul(this.rng, 1664525) + 1013904223) >>> 0;
        return this.rng / 4294967296;
    }

    announce(message, duration = 1.45) {
        this.announcement = message;
        this.noticeTime = duration;
    }

    record(player, name) {
        player.stats[name]++;
        this.stats[player.team][name]++;
    }

    startFaceoff() {
        this.phase = "FACEOFF";
        this.phaseTime = 0;
        this.controlled = this.careerPlayer ?? 3;
        this.pending = this.flight = this.assist = null;
        this.nextDecision = 0;
        this.shotClock = null;
        this.ball = { x: 0, y: laxBallRadius, z: 0, owner: null, team: null, state: "dead", vx: 0, vy: 0, vz: 0 };
        this.faceoff = {
            age: 0, progress: 0, windowStart: .23, windowEnd: .69, sweetSpot: .46,
            phase: "SET", action: null, timing: null, player: this.controlled === 3
        };
        for (const p of this.players) {
            p.x = p.homeX; p.z = p.homeZ;
            p.yaw = p.role === "G" ? (1 - p.team) * Math.PI : p.team * Math.PI;
            p.speed = p.vx = p.vz = p.dodgeTime = p.screenTime = p.actionTime = p.actionDuration = 0;
            p.running = false;
            if (p.slot === 3) this.setAction(p, "faceoff", 1.54);
            else p.action = "idle";
            p.offenseHalf = p.z * laxSide(p.team) > 0;
        }
        this.announce("Faceoff · get set", .72);
    }

    updateFaceoff(dt) {
        const draw = this.faceoff;
        draw.age += dt;
        this.players[3].actionTime = draw.age;
        this.players[13].actionTime = draw.age;
        draw.progress = laxClamp((draw.age - .64) / .9, 0, 1);
        if (draw.phase === "SET" && draw.age >= .64) {
            draw.phase = "DRAW";
            this.announce(draw.player ? "Faceoff · tap in the green" : "Faceoff", .9);
        }
        if (draw.age < 1.54) return;
        const user = draw.player ? draw.timing : .40 + this.random() * .26;
        const homeQuality = user === null || user < 0 ? 0 : 1 - Math.abs(user - .46) * 1.7;
        const awayQuality = 1 - Math.abs((.39 + this.random() * .31) - .46) * 1.7;
        const homeBonus = draw.action === "counter" ? .035 : 0;
        const margin = homeQuality + homeBonus - awayQuality;
        const homeWin = homeQuality + homeBonus >= awayQuality;
        const center = this.players[homeWin ? 3 : 13];
        this.phase = "LIVE";
        this.phaseTime = 0;
        this.faceoff = null;
        if (Math.abs(margin) < .055) {
            this.lastTouch = center.team;
            this.freeBall({ x: 0, y: laxBallRadius, z: 0 }, 2.6, 1.15, .58);
            this.announce("Contested draw · loose ball");
            return;
        }
        this.record(center, "faceoffs");
        this.setAction(center, "catch", .35);
        this.attach(center);
        this.announce((homeWin ? this.homeName : this.awayName) + " wins the draw");
    }

    pocket(player) {
        const lateral = player.longPole ? .78 : .64;
        const front = player.longPole ? .82 : .59;
        const c = Math.cos(player.yaw);
        const s = Math.sin(player.yaw);
        return { x: player.x + lateral * c - front * s, y: player.longPole ? 2.55 : 2.25,
            z: player.z - lateral * s - front * c };
    }

    setAction(player, action, duration) {
        player.action = action;
        player.actionTime = 0;
        player.actionDuration = duration;
    }

    attach(player, follow = true) {
        const change = this.ball.team !== player.team;
        this.pending = this.flight = null;
        this.lastTeam = this.lastTouch = player.team;
        if (change) {
            this.assist = null;
            this.shotClock = this.practice ? null : 80;
        }
        Object.assign(this.ball, this.pocket(player), {
            owner: player.id, team: player.team, state: "held", vx: 0, vy: 0, vz: 0
        });
        player.protection = .48;
        this.nextDecision = this.elapsed + (player.role === "G" ? .65 : .55);
        this.practiceRestart = this.practice && player.team === 1 ? this.elapsed + .95 : null;
        if (follow && !this.playerLock && player.team === 0) this.controlled = player.id;
    }

    freeBall(point, vx, vy, vz, shot = false) {
        this.pending = this.flight = null;
        Object.assign(this.ball, point, { owner: null, state: "loose", vx, vy, vz, rebound: shot });
    }

    nearbyOpponents(player) {
        return this.teams[1 - player.team];
    }

    nearest(players, point, filter = () => true) {
        let target = null;
        let best = Infinity;
        for (const p of players) {
            if (!filter(p)) continue;
            const distance = laxHypot(p, point);
            if (distance < best) { best = distance; target = p; }
        }
        return target;
    }

    laneClear(from, to) {
        const a = { x: from.x, y: 1.7, z: from.z };
        const b = { x: to.x, y: 1.7, z: to.z };
        return !this.nearbyOpponents(from).some(p =>
            laxClosestOnSegment(a, b, { x: p.x, y: 1.7, z: p.z }) < 1.15);
    }

    safePass(from, call) {
        let best = null;
        let bestValue = -Infinity;
        const side = laxSide(from.team);
        for (const to of this.teams[from.team]) {
            if (to.id === from.id || to.role === "G") continue;
            const range = laxHypot(from, to);
            if (range < 1.7 || range > (this.practice ? 21 : 35)) continue;
            const depth = (to.z - from.z) * side;
            if (call === "clear" && (to.name === "X" || to.slot === 2 && !this.practice ||
                Math.abs(to.x) < Math.min(2.5, this.halfWidth * .25) || depth < -4)) continue;
            if (call === "swing" && Math.sign(to.x) === Math.sign(from.x) && Math.abs(to.x - from.x) < 3) continue;
            if (call === "passdown" && depth < .25) continue;
            const nearest = this.nearest(this.nearbyOpponents(from), to);
            const open = nearest ? Math.min(6, laxHypot(nearest, to)) : 6;
            const visible = this.laneClear(from, to);
            if (call && (!visible || open < 1.4)) continue;
            const value = (visible ? 3 : -3) + open * .66 + depth * .065 - range * .087
                + (call === "swing" ? Math.abs(to.x - from.x) * .18 : 0);
            if (value > bestValue) { bestValue = value; best = to; }
        }
        return best;
    }

    passPlan(from, x, z) {
        const input = laxInput({ x, z });
        if (input.magnitude < .14) {
            const help = this.safePass(from);
            if (help) return { target: help.id, point: this.pocket(help) };
        }
        const dx = input.magnitude >= .14 ? input.x / input.magnitude : -Math.sin(from.yaw);
        const dz = input.magnitude >= .14 ? input.z / input.magnitude : -Math.cos(from.yaw);
        let chosen = null;
        let rank = Math.cos(34 * Math.PI / 180);
        for (const player of this.teams[from.team]) {
            if (player.id === from.id || player.role === "G" || laxHypot(player, from) > 38) continue;
            const distance = laxHypot(player, from);
            if (distance < 1.4) continue;
            const alignment = ((player.x - from.x) * dx + (player.z - from.z) * dz) / distance - distance * .0002;
            if (alignment > rank) { rank = alignment; chosen = player; }
        }
        if (chosen) return { target: chosen.id, point: this.pocket(chosen) };
        const range = 7 + (this.practice ? 9 : 19) * input.magnitude;
        return { target: null, point: { x: from.x + dx * range, y: laxBallRadius, z: from.z + dz * range } };
    }

    passTarget(x = 0, z = 0) {
        const p = this.players[this.controlled];
        return p && this.ball.owner === p.id && !this.pending ? this.passPlan(p, x, z).target : null;
    }

    canAim() {
        return this.phase === "LIVE" && this.ball.owner === this.controlled && !this.pending;
    }

    startThrow(player, kind, payload = {}, call = null) {
        if (!player || this.ball.owner !== player.id || this.pending || player.dodgeTime > 0) return false;
        if (kind === "pass") {
            let plan;
            if (payload.target !== undefined && payload.target !== null) {
                const to = this.players[payload.target];
                if (!to || to.team !== player.team || to.id === player.id) return false;
                plan = { target: to.id, point: this.pocket(to) };
            } else {
                plan = this.passPlan(player, payload.x, payload.z);
            }
            this.pending = { kind, player: player.id, ...plan, release: .24, call };
            this.setAction(player, "pass", .55);
            return true;
        }
        const goal = laxSide(player.team) * this.goalZ;
        if (this.practice && player.team === 1 || (player.z - goal) * laxSide(player.team) > .4) {
            if (player.id === this.controlled) this.announce("Bring the ball in front of goal");
            return false;
        }
        const aimX = laxClamp(laxClock(payload.aimX, player.x > 0 ? -.56 : .56), -2.7, 2.7);
        const aimY = laxClamp(laxClock(payload.aimY, 1.2), .08, 2.75);
        this.pending = { kind, player: player.id, aimX, aimY, release: .34 };
        this.setAction(player, "shoot", .68);
        return true;
    }

    command(action, payload = {}) {
        if (action === "reset") { this.reset(); return true; }
        if (this.phase === "FACEOFF") {
            if (!this.faceoff.player || this.faceoff.action || !["pass", "shoot", "faceoff", "clamp", "counter"].includes(action)) return false;
            this.faceoff.action = action === "counter" ? "counter" : "clamp";
            this.faceoff.timing = (this.faceoff.age - .64) / .9;
            if (this.faceoff.timing < 0) this.announce("Early clamp");
            return true;
        }
        if (this.phase !== "LIVE") return false;
        const player = this.players[this.controlled];
        const holder = this.players[this.ball.owner];
        if (action === "switch") {
            if (this.playerLock) return false;
            const target = holder?.team === 0 && holder.id !== player.id ? holder :
                this.nearest(this.teams[0], this.ball, p => p.id !== player.id);
            if (!target) return false;
            this.controlled = target.id;
            return true;
        }
        if (["swing", "clear", "passdown"].includes(action)) {
            if (holder?.team !== 0) return false;
            const target = this.safePass(holder, action);
            const text = { clear: "Clear", swing: "Swing", passdown: "Pass down" }[action];
            if (!target) { this.announce(text + " · lane covered"); return false; }
            const started = this.startThrow(holder, "pass", { target: target.id }, action);
            if (started) this.announce(text);
            return started;
        }
        if (action === "pass") {
            if (holder === player) return this.startThrow(player, "pass", payload);
            if (holder?.team === 0 && laxHypot(player, holder) < 34) return this.startThrow(holder, "pass", { target: player.id });
            if (holder?.team === 1) return this.check(player, holder);
            return this.scoop(player);
        }
        if (action === "shoot") return this.startThrow(player, "shot", payload);
        if (action === "poke" || action === "check" || action === "slap") return this.check(player, holder);
        if (action === "scoop") return this.scoop(player);
        if (action === "setpick" || action === "pickdown") {
            const screener = action === "setpick" ? player : this.nearest(this.teams[0], this.ball,
                p => p.id !== this.ball.owner && p.role !== "G");
            if (holder?.team !== 0 || !screener || holder === screener || laxHypot(holder, screener) > 5) return false;
            screener.screenTime = .8;
            this.setAction(screener, "setpick", .8);
            this.announce("Pick set");
            return true;
        }
        if (action === "releasepick") { player.screenTime = 0; return true; }
        if (action === "dodge") {
            if (holder?.team === 1) return this.check(player, holder);
            if (player.dodgeTime > 0 || player.stamina < .17 || this.pending?.player === player.id) return false;
            const move = laxInput(payload);
            player.dodgeX = move.magnitude > .12 ? move.x / move.magnitude : Math.cos(player.yaw);
            player.dodgeZ = move.magnitude > .12 ? move.z / move.magnitude : -Math.sin(player.yaw);
            player.dodgeTime = .28;
            player.protection = .4;
            player.stamina -= .16;
            this.setAction(player, "dodge", .38);
            return true;
        }
        return false;
    }

    check(player, holder) {
        if (!holder || holder.team === player.team || player.role === "G" || player.checkCooldown > 0) return false;
        if (laxHypot(player, holder) > (player.longPole ? 2.2 : 1.63)) return false;
        player.checkCooldown = .85;
        this.setAction(player, "check", .36);
        player.yaw = Math.atan2(player.x - holder.x, player.z - holder.z);
        if (holder.protection > 0 || holder.role === "G") return true;
        this.record(player, "checks");
        this.record(holder, "turnovers");
        const gap = Math.max(.1, laxHypot(player, holder));
        this.freeBall(this.pocket(holder), (holder.x - player.x) * 3 / gap, .6, (holder.z - player.z) * 3 / gap);
        this.lastTouch = player.team;
        this.assist = null;
        this.announce("Check · loose ball");
        return true;
    }

    scoop(player) {
        const ball = this.ball;
        if (ball.state !== "loose" || ball.y > .32 || laxHypot(player, ball) > 1.25) return false;
        this.attach(player);
        this.setAction(player, "scoop", .37);
        this.record(player, "groundBalls");
        this.announce(player.name + " scoops the ground ball", .9);
        return true;
    }

    aiThink() {
        const holder = this.players[this.ball.owner];
        for (const team of [0, 1]) {
            this.pressers[team] = holder && holder.team !== team ? this.nearest(this.teams[team], holder,
                p => p.role !== "G" && laxHypot(p, holder) < 18) : null;
            this.chasers[team] = this.ball.state === "loose" ? this.nearest(this.teams[team], this.ball,
                p => p.role !== "G" || laxHypot(p, this.ball) < 3) : null;
            const checker = this.pressers[team];
            if (checker && checker.id !== this.controlled && this.elapsed > .45) this.check(checker, holder);
        }
        if (!holder || holder.id === this.controlled || this.pending || this.elapsed < this.nextDecision) return;
        this.nextDecision = this.elapsed + .45;
        const attacking = laxSide(holder.team);
        const goal = { x: 0, z: attacking * this.goalZ };
        const depth = (goal.z - holder.z) * attacking;
        const pressure = this.nearest(this.nearbyOpponents(holder), holder);
        const range = pressure ? laxHypot(pressure, holder) : 40;
        if (!this.practice && holder.role !== "G" && depth > 1.1 && depth < 20 &&
            Math.abs(holder.x) < 10 && (range > 1.9 || depth < 6)) {
            const keeper = this.teams[1 - holder.team].find(p => p.role === "G");
            this.startThrow(holder, "shot", { aimX: keeper?.x > 0 ? -.61 : .61, aimY: .62 + this.random() * .81 });
            return;
        }
        const receiver = this.safePass(holder);
        if (receiver && (holder.role === "G" || range < 3.6 ||
            this.playerLock && receiver.id === this.controlled || this.random() < .21)) {
            this.startThrow(holder, "pass", { target: receiver.id });
        }
    }

    moveTarget(player) {
        const ownSide = laxSide(player.team);
        const ball = this.ball;
        const holder = this.players[ball.owner];
        const attacking = (holder?.team ?? this.lastTeam) === player.team;
        if (player.screenTime > 0) return player;
        if (player.role === "G") {
            const goal = this.practice ? -this.goalZ : -ownSide * this.goalZ;
            const towardField = Math.sign(-goal);
            const depth = Math.max(3.2, (ball.z - goal) * towardField);
            const target = this.flight?.kind === "shot" && this.flight.team !== player.team && this.flight.age > .18 ?
                this.flight.target : null;
            const tracking = target ? target.x * .57 : ball.x / depth;
            return { x: laxClamp(tracking, -.7, .7), z: goal + towardField * 1.17 };
        }
        if (this.flight?.kind === "pass" && this.flight.receiver === player.id) {
            return { x: this.flight.receiverPoint.x, z: this.flight.receiverPoint.z };
        }
        if (holder === player) {
            const goal = ownSide * this.goalZ;
            return { x: Math.abs(player.x) > 3.3 ? player.x * .44 : (player.x >= 0 ? 2.2 : -2.2),
                z: goal - ownSide * 3.25 };
        }
        if (this.chasers[player.team] === player && ball.state === "loose") {
            return { x: ball.x + ball.vx * .13, z: ball.z + ball.vz * .13 };
        }
        if (this.pressers[player.team] === player && holder?.team !== player.team && holder) {
            const screen = this.teams[holder.team].find(p => p.screenTime > 0 && laxHypot(p, player) < 1.35);
            if (screen) return { x: screen.x + (player.x < screen.x ? -1.4 : 1.4), z: holder.z - ownSide * .6 };
            return { x: holder.x, z: holder.z - ownSide * 1.15 };
        }
        if (this.practice) {
            return { x: player.homeX + laxClamp(ball.x * .19, -1.4, 1.4),
                z: player.homeZ + laxClamp((ball.z - player.homeZ) * .15, -1.75, 1.75) };
        }
        if (player.role === "A") {
            const depth = laxClamp(ball.z * ownSide + (attacking ? 8 : 11), 17, 37);
            return { x: player.homeX + laxClamp(ball.x * .15, -2, 2), z: ownSide * (player.slot === 2 ? depth + 4.4 : depth) };
        }
        if (player.role === "D") {
            const depth = -laxClamp(-ball.z * ownSide + 4, 14, 31);
            return { x: player.homeX + laxClamp(ball.x * .37, -6, 6), z: ownSide * depth };
        }
        const depth = attacking ? laxClamp(ball.z * ownSide - 4, 8, 22) :
            laxClamp(ball.z * ownSide - 3, -23, 5);
        const lateral = [0, -10.7, 10.7][player.slot - 3];
        return { x: lateral + laxClamp(ball.x * .25, -3.8, 3.8), z: ownSide * depth };
    }

    balanceMidfield(proposals) {
        if (this.practice) return;
        for (const team of [0, 1]) {
            const players = this.teams[team];
            const side = laxSide(team);
            const offense = p => Math.abs(p.z) <= .02 ? p.player.offenseHalf : p.z * side > 0;
            let forward = 0;
            for (const player of players) {
                const p = proposals[player.id];
                if (player.role === "G" && p.z * side > -.04) p.z = -side * .04;
                if (offense(p)) forward++;
            }
            if (forward >= 3 && forward <= 6) continue;
            const restoreOffense = forward < 3;
            const excess = restoreOffense ? 3 - forward : forward - 6;
            const candidates = players.map(p => proposals[p.id])
                .filter(p => offense(p) !== restoreOffense && p.player.offenseHalf === restoreOffense)
                .sort((a, b) => Number(a.player.id === this.controlled) - Number(b.player.id === this.controlled));
            for (const p of candidates.slice(0, excess)) {
                p.z = -side * (restoreOffense ? -.035 : .035);
                if (p.player.id === this.controlled && this.noticeTime <= .2) this.announce("Offside · hold midfield", 1.0);
            }
        }
    }

    movePlayers(dt, controls) {
        const move = laxInput(controls);
        const proposals = [];
        const receiver = this.flight?.kind === "pass" && this.players[this.flight.receiver];
        if (receiver && this.flight.age + .28 >= this.flight.duration &&
            (receiver.id !== this.controlled || move.magnitude < .14) && receiver.action !== "catch") {
            this.setAction(receiver, "catch", .46);
        }
        for (const player of this.players) {
            const manual = player.id === this.controlled && !(player === receiver && move.magnitude < .14);
            let dx = 0;
            let dz = 0;
            if (manual) {
                const sprint = !!controls.sprint && move.magnitude > .1 && player.stamina > .13;
                const pace = player.role === "G" ? 5.8 : this.ball.owner === player.id ? 7.1 : 8.0;
                const gain = sprint ? 1.19 : 1;
                dx = move.x * pace * gain;
                dz = move.z * pace * gain;
                player.stamina = laxClamp(player.stamina + dt * (sprint ? -.33 : .19), 0, 1);
            } else {
                const target = this.moveTarget(player);
                const x = target.x - player.x;
                const z = target.z - player.z;
                const length = Math.max(.07, Math.hypot(x, z));
                const speed = Math.min(player.role === "G" ? 5.1 : 6.7, length * 3.3);
                dx = x / length * speed;
                dz = z / length * speed;
                player.stamina = Math.min(1, player.stamina + dt * .18);
            }
            if (player.dodgeTime > 0) {
                dx = player.dodgeX * 11.5;
                dz = player.dodgeZ * 11.5;
                player.dodgeTime -= dt;
            }
            if (player.screenTime > 0) {
                player.screenTime = Math.max(0, player.screenTime - dt);
                dx = dz = 0;
            }

            // The goalie arc remains free. Field players stop at the other crease.
            const useFastStop = player.screenTime > 0;
            const blend = 1 - Math.exp(-(useFastStop ? 24 : manual ? 11 : 8) * dt);
            let x = laxClamp(player.x + (player.vx + (dx - player.vx) * blend) * dt, -this.halfWidth + .6, this.halfWidth - .6);
            let z = laxClamp(player.z + (player.vz + (dz - player.vz) * blend) * dt, -this.halfLength + .45, this.halfLength - .45);
            const goal = laxSide(player.team) * this.goalZ;
            const goalDist = Math.hypot(x, z - goal);
            if (player.role !== "G" && goalDist < this.creaseRadius && goalDist > .0001) {
                x *= this.creaseRadius / goalDist;
                z = goal + (z - goal) * this.creaseRadius / goalDist;
            }
            proposals.push({ x, z, player });
        }
        this.balanceMidfield(proposals);
        for (const p of proposals) {
            const player = p.player;
            player.vx = (p.x - player.x) / dt;
            player.vz = (p.z - player.z) / dt;
            player.x = p.x;
            player.z = p.z;
            if (Math.abs(p.z) > .02) player.offenseHalf = p.z * laxSide(player.team) > 0;
            player.speed = Math.hypot(player.vx, player.vz);
            player.running = player.speed > .32;
            let lookX = player.vx;
            let lookZ = player.vz;
            const pending = this.pending?.player === player.id ? this.pending : null;
            const target = pending?.kind === "pass" ? this.players[pending.target] || pending.point :
                pending?.kind === "shot" ? { x: pending.aimX, z: laxSide(player.team) * this.goalZ } :
                player === receiver || player.role === "G" && this.ball.owner !== player.id ? this.ball : null;
            if (target) { lookX = target.x - player.x; lookZ = target.z - player.z; }
            if (Math.hypot(lookX, lookZ) > .19) {
                const yaw = Math.atan2(-lookX, -lookZ);
                player.yaw += laxAngleError(yaw, player.yaw) * Math.min(1, dt * 13);
            }
            if (player.actionDuration > 0) {
                player.actionTime += dt;
                if (player.actionTime >= player.actionDuration) player.actionDuration = 0;
            }
            if (player.actionDuration <= 0) player.action = player.running ? "run" : "idle";
            player.protection = Math.max(0, player.protection - dt);
            player.checkCooldown = Math.max(0, player.checkCooldown - dt);
        }
    }

    releaseThrow() {
        const throwData = this.pending;
        const player = this.players[throwData.player];
        if (this.ball.owner !== player.id) { this.pending = null; return; }
        const origin = this.pocket(player);
        if (throwData.kind === "pass") {
            const to = this.players[throwData.target];
            const range = laxHypot(origin, to || throwData.point);
            const duration = laxClamp(range / (this.practice ? 18 : 23), .34, this.practice ? 1.25 : 2.4);
            let target = throwData.point;
            let receiverPoint = null;
            if (to) {
                const lead = Math.min(.29, duration * .38);
                receiverPoint = { x: to.x + to.vx * lead, z: to.z + to.vz * lead };
                target = { x: receiverPoint.x, y: to.longPole ? 2.42 : 2.16, z: receiverPoint.z };
            }
            this.flight = { kind: "pass", team: player.team, player: player.id, origin, target, age: 0, duration,
                arc: laxClamp(range * .06, .19, 1.25), receiver: to?.id ?? null, receiverPoint };
            this.record(player, "passes");
        } else {
            const goal = laxSide(player.team) * this.goalZ;
            const span = Math.hypot(throwData.aimX - origin.x, goal - origin.z);
            const duration = laxClamp(span / 33, .13, 2.5);
            const blur = Math.min(.18, span * .006) * (player.speed > 5.5 ? 1.4 : 1);
            const target = { x: throwData.aimX + (this.random() - .5) * blur,
                y: throwData.aimY + (this.random() - .5) * blur * .7, z: goal };
            this.flight = { kind: "shot", team: player.team, player: player.id, origin, target, age: 0,
                duration: duration + .36, vx: (target.x - origin.x) / duration,
                vy: (target.y - origin.y) / duration + .5 * laxGravity * duration, vz: (goal - origin.z) / duration,
                onTarget: Math.abs(target.x) < this.goalHalfWidth - laxBallRadius &&
                    target.y > laxBallRadius && target.y < this.goalTop - laxBallRadius };
            this.record(player, "shots");
        }
        this.pending = null;
        this.lastTouch = player.team;
        Object.assign(this.ball, origin, { owner: null, team: player.team, state: this.flight.kind, rebound: false });
    }

    awardGoal(flight, crossing) {
        const scorer = this.players[flight.player];
        this.record(scorer, "goals");
        this.record(scorer, "shotsOnGoal");
        if (this.assist?.to === scorer.id && this.elapsed - this.assist.at < 5) {
            this.record(this.players[this.assist.from], "assists");
        }
        this.assist = this.flight = null;
        this.scores[flight.team]++;
        this.phase = "GOAL";
        this.phaseTime = 0;
        Object.assign(this.ball, crossing, { z: crossing.z + laxSide(flight.team) * .46, state: "net" });
        this.announce(this.teamNames[flight.team] + " goal · " + scorer.name, 1.8);
    }

    updatePass(flight, previous) {
        const t = laxClamp(flight.age / flight.duration, 0, 1);
        const point = {
            x: flight.origin.x + (flight.target.x - flight.origin.x) * t,
            y: flight.origin.y + (flight.target.y - flight.origin.y) * t + 4 * flight.arc * t * (1 - t),
            z: flight.origin.z + (flight.target.z - flight.origin.z) * t
        };
        Object.assign(this.ball, point);
        if (t > .22 && t < .93 && point.y < 2.73) {
            for (const p of this.teams[1 - flight.team]) {
                const shoulder = { x: p.x, y: p.longPole ? 2.23 : 2.03, z: p.z };
                if (laxClosestOnSegment(previous, point, shoulder) < (p.longPole ? .79 : .62)) {
                    this.attach(p, p.team === 0);
                    this.setAction(p, "catch", .45);
                    this.record(p, "interceptions");
                    this.record(this.players[flight.player], "turnovers");
                    this.announce("Intercepted · " + p.name);
                    return;
                }
            }
        }
        if (t >= 1) {
            const receiver = this.players[flight.receiver];
            const span = laxHypot(point, flight.origin);
            if (receiver && laxHypot(receiver, point) < 1.65) {
                this.attach(receiver, this.controlled === flight.player);
                this.setAction(receiver, "catch", .37);
                this.record(this.players[flight.player], "completions");
                this.assist = { from: flight.player, to: receiver.id, at: this.elapsed };
            } else {
                this.freeBall(point, (point.x - flight.origin.x) / Math.max(1, span) * 2.6,
                    .8, (point.z - flight.origin.z) / Math.max(1, span) * 2.6);
                if (receiver) this.announce("Pass dropped");
            }
        }
    }

    updateShot(flight, previous) {
        const t = flight.age;
        const point = { x: flight.origin.x + flight.vx * t,
            y: flight.origin.y + flight.vy * t - .5 * laxGravity * t * t, z: flight.origin.z + flight.vz * t };
        const keeper = this.teams[1 - flight.team].find(p => p.role === "G");
        if (keeper && Math.abs(keeper.z - flight.target.z) < this.creaseRadius + .1 &&
            Math.sign(flight.target.z - keeper.z) === Math.sign(flight.vz)) {
            const save = laxDepthIntersection(previous, point, keeper.z);
            const width = save ? Math.abs(save.x - keeper.x) : 5;
            const reach = save && (save.y < .55 ? .27 : save.y < .94 ? .4 : .47);
            if (save && save.y > laxBallRadius && save.y < this.goalTop + .15 && width < reach) {
                if (flight.onTarget) {
                    this.record(keeper, "saves");
                    this.record(this.players[flight.player], "shotsOnGoal");
                }
                if (width < .25 && save.y > .8) this.attach(keeper, false);
                else {
                    this.freeBall(save, (save.x - keeper.x) * 5, 1.65, -flight.vz * .15, true);
                    this.lastTouch = keeper.team;
                }
                this.setAction(keeper, "save", .55);
                this.announce((flight.onTarget ? "Saved · " : "Blocked · ") + keeper.name);
                return;
            }
        }
        const crossing = laxDepthIntersection(previous, point, flight.target.z);
        if (crossing && crossing.y > laxBallRadius) {
            const x = Math.abs(crossing.x);
            const padding = laxBallRadius + .055;
            const pipe = Math.abs(x - this.goalHalfWidth) <= padding && crossing.y <= this.goalTop + padding;
            const crossbar = x <= this.goalHalfWidth + padding && Math.abs(crossing.y - this.goalTop) <= padding;
            if (pipe || crossbar) {
                this.freeBall(crossing, flight.vx * .28, 1.25, -flight.vz * .25, true);
                this.announce("Off the pipe");
                return;
            }
            if (x < this.goalHalfWidth - laxBallRadius && crossing.y < this.goalTop - laxBallRadius) {
                this.awardGoal(flight, crossing);
                return;
            }
            this.announce("Shot wide");
        }
        if (point.y <= laxBallRadius || t >= flight.duration) {
            point.y = Math.max(laxBallRadius, point.y);
            this.freeBall(point, flight.vx * .30, 1.1, flight.vz * .30, true);
        } else {
            Object.assign(this.ball, point);
        }
    }

    restartPossession(team, position, note) {
        if (this.practice) team = 0;
        const restart = { x: laxClamp(position.x, -this.halfWidth + .9, this.halfWidth - .9),
            z: laxClamp(position.z, -this.halfLength + .9, this.halfLength - .9) };
        const half = restart.z * laxSide(team) > 0;
        const squad = this.teams[team];
        const selected = this.nearest(squad, restart, p => p.role !== "G" && (this.practice || p.offenseHalf === half))
            || this.nearest(squad, restart, p => p.role !== "G");
        if (!selected) return;
        const distance = laxHypot(selected, restart);
        if (distance > 1.2 && (this.practice || selected.offenseHalf === half)) {
            const d = Math.hypot(restart.x, restart.z - laxSide(team) * this.goalZ);
            if (d > this.creaseRadius + .1) { selected.x = restart.x; selected.z = restart.z; }
        }
        this.attach(selected);
        this.shotClock = this.practice ? null : 80;
        this.assist = null;
        this.announce(note);
    }

    updateBall(dt) {
        const ball = this.ball;
        if (this.pending) {
            this.pending.release -= dt;
            if (this.pending.release <= 0) this.releaseThrow();
        }
        if (ball.owner !== null) {
            const p = this.players[ball.owner];
            Object.assign(ball, this.pocket(p));
            return;
        }
        const previous = { x: ball.x, y: ball.y, z: ball.z };
        if (this.flight) {
            const flight = this.flight;
            flight.age += dt;
            if (flight.kind === "pass") this.updatePass(flight, previous);
            else this.updateShot(flight, previous);
        } else if (ball.state === "loose") {
            ball.x += ball.vx * dt;
            ball.y += ball.vy * dt;
            ball.z += ball.vz * dt;
            ball.vy -= laxGravity * dt;
            if (ball.y < laxBallRadius) {
                ball.y = laxBallRadius;
                ball.vy = Math.abs(ball.vy) > .8 ? -ball.vy * .32 : 0;
                ball.vx *= Math.exp(-3.1 * dt);
                ball.vz *= Math.exp(-3.1 * dt);
            }
            if (ball.y <= .22 && Math.abs(ball.x) <= this.halfWidth && Math.abs(ball.z) <= this.halfLength) {
                const candidate = this.nearest(this.players, ball);
                if (candidate && laxHypot(candidate, ball) < .74) this.scoop(candidate);
            }
        }
        if (this.phase !== "LIVE" || ball.owner !== null) return;
        if (Math.abs(ball.x) > this.halfWidth || Math.abs(ball.z) > this.halfLength) {
            const xTime = Math.abs(ball.x) > this.halfWidth && ball.x !== previous.x ?
                (Math.sign(ball.x) * this.halfWidth - previous.x) / (ball.x - previous.x) : 1;
            const zTime = Math.abs(ball.z) > this.halfLength && ball.z !== previous.z ?
                (Math.sign(ball.z) * this.halfLength - previous.z) / (ball.z - previous.z) : 1;
            const time = laxClamp(Math.min(xTime, zTime), 0, 1);
            const crossing = { x: previous.x + (ball.x - previous.x) * time, z: previous.z + (ball.z - previous.z) * time };
            const closest = (ball.state === "shot" || ball.rebound) ? this.nearest(this.players, crossing) : null;
            this.restartPossession(closest?.team ?? 1 - (this.lastTouch ?? 0), crossing, "Out of bounds");
        }
    }

    update(dt, controls = {}) {
        dt = laxClamp(laxClock(dt, 0), 0, .05);
        if (!dt) return;
        this.noticeTime = Math.max(0, this.noticeTime - dt);
        if (this.noticeTime === 0) this.announcement = "";
        if (this.phase === "FINAL") return;
        if (this.phase === "FACEOFF") { this.updateFaceoff(dt); return; }
        if (this.phase === "GOAL" || this.phase === "INTERMISSION") {
            this.phaseTime += dt;
            if (this.phaseTime < 1.65) return;
            if (this.practice && this.clock > 0) {
                this.phase = "LIVE";
                this.restartPossession(0, this.players[0], "Practice · next possession");
            } else if (this.clock > 0 || this.phase === "INTERMISSION") {
                if (this.phase === "INTERMISSION") { this.clock = this.periodLength; this.period++; }
                this.startFaceoff();
            } else {
                this.endPeriod();
            }
            return;
        }
        this.elapsed += dt;
        this.clock = Math.max(0, this.clock - dt);
        if (this.practiceRestart !== null && this.elapsed >= this.practiceRestart) {
            this.restartPossession(0, { x: this.players[0].homeX, z: this.players[0].homeZ }, "Practice · keeper clear");
        }
        if (this.shotClock !== null && this.ball.team !== null) {
            this.shotClock = Math.max(0, this.shotClock - dt);
            if (!this.shotClock && this.ball.state !== "shot") {
                this.restartPossession(1 - this.ball.team, this.ball, "Shot clock violation");
            }
        }
        if (this.elapsed >= (this.nextAITick ?? 0)) {
            this.aiThink();
            this.nextAITick = this.elapsed + .12;
        }
        this.movePlayers(dt, controls);
        this.updateBall(dt);
        if (!this.clock && this.phase === "LIVE") this.endPeriod();
    }

    endPeriod() {
        this.phaseTime = 0;
        this.phase = this.period >= this.periods ? "FINAL" : "INTERMISSION";
        if (this.phase === "FINAL") this.announce(this.practice ? "Practice complete" : "Final score", 5);
        else this.announce("End of period " + this.period, 1.65);
    }
}

const WEB_CAREER_KEY = 'PolyLax.Web.Career.1';
const WEB_POSITIONS = new Set(['A', 'M', 'D', 'F', 'G', 'LSM', 'SSDM']);

function browserProfile(value = {}) {
    const jersey = Number(value?.number ?? 3);
    return {
        name: (String(value?.name ?? '').replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, 24) || 'New Player'),
        number: Math.max(0, Math.min(99, Number.isFinite(jersey) ? Math.round(jersey) : 3)),
        position: WEB_POSITIONS.has(value?.position) ? value.position : 'M'
    };
}

class BrowserCareer {
    constructor(storage) {
        this.storage = storage;
        this.data = {version: 1, profile: browserProfile(), games: 0, wins: 0, xp: 0, history: []};
        try {
            const saved = JSON.parse(storage?.getItem(WEB_CAREER_KEY) ?? 'null');
            if (saved?.version === 1) {
                this.data = {
                    version: 1,
                    profile: browserProfile(saved.profile),
                    games: Math.max(0, Number(saved.games) || 0),
                    wins: Math.max(0, Number(saved.wins) || 0),
                    xp: Math.max(0, Number(saved.xp) || 0),
                    history: Array.isArray(saved.history) ? saved.history.slice(0, 12) : []
                };
            }
        } catch (_) {
            // A sandboxed Playground iframe can still play without storage.
        }
    }

    save() {
        try { this.storage?.setItem(WEB_CAREER_KEY, JSON.stringify(this.data)); } catch (_) { /* Play in memory. */ }
    }

    select(profile) {
        this.data.profile = browserProfile({...this.data.profile, ...profile});
        this.save();
        return this.data.profile;
    }

    record(matchId, match) {
        if (match.phase !== 'FINAL' || this.data.history.some(entry => entry?.id === matchId)) return;
        const [home, away] = match.scores;
        const athlete = match.players.find(player => player.id === match.controlled);
        const line = athlete?.stats ?? {};
        const goals = line.goals ?? 0;
        const assists = line.assists ?? 0;
        const earned = 12 + (home > away ? 8 : 0) + goals * 4 + assists * 3;
        this.data.games += 1;
        this.data.wins += Number(home > away);
        this.data.xp += earned;
        this.data.history.unshift({id: matchId, home, away, goals, assists, earned, position: this.data.profile.position});
        this.data.history.length = Math.min(this.data.history.length, 12);
        this.save();
    }
}

// Procedural Babylon rig derived from the PolyLax Craft player's proportions and kit.
const LacrosseView = (() => {
    const V = (x = 0, y = 0, z = 0) => new BABYLON.Vector3(x, y, z);
    const C = hex => BABYLON.Color3.FromHexString(hex);
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const lerp = (a, b, t) => a + (b - a) * t;
    const white = "#e8f2f1";
    const dark = "#0d1625";
    const silver = "#a1afbb";
    const palettes = [
        { jersey: "#7653b4", trim: "#c5b0fc", shorts: "#342457", helmet: "#271a43", number: "#fff9fe" },
        { jersey: "#ee7739", trim: "#fbc58a", shorts: "#302840", helmet: "#2b253f", number: "#fff4df" }
    ];
    const skins = ["#d89e77", "#ac7153", "#e3b793", "#805043", "#b98365"];

    class Geometry {
        constructor() {
            this.positions = [];
            this.normals = [];
            this.colors = [];
            this.indices = [];
            this.tints = new Map();
        }

        color(name) {
            if (!this.tints.has(name)) this.tints.set(name, C(name));
            return this.tints.get(name);
        }

        tri(a, b, c, tint) {
            const start = this.positions.length / 3;
            const normal = BABYLON.Vector3.Cross(b.subtract(a), c.subtract(a)).normalize();
            const { r, g, b: blue } = this.color(tint);
            for (const point of [a, b, c]) {
                this.positions.push(point.x, point.y, point.z);
                this.normals.push(normal.x, normal.y, normal.z);
                this.colors.push(r, g, blue, 1);
            }
            this.indices.push(start, start + 1, start + 2);
        }

        quad(a, b, c, d, tint) {
            this.tri(a, b, c, tint);
            this.tri(a, c, d, tint);
        }

        loft(rings, sides, tint) {
            const rows = rings.map(([y, rx, rz, z = 0, x = 0]) => Array.from({ length: sides }, (_, i) => {
                const angle = (i + .5) * Math.PI * 2 / sides;
                return V(x + Math.cos(angle) * rx, y, z + Math.sin(angle) * rz);
            }));
            for (let i = 0; i < sides; i++) {
                const j = (i + 1) % sides;
                for (let k = 1; k < rows.length; k++) {
                    this.quad(rows[k - 1][i], rows[k][i], rows[k][j], rows[k - 1][j], tint);
                }
                const first = rings[0], last = rings.at(-1);
                this.tri(V(first[4] || 0, first[0], first[3] || 0), rows[0][i], rows[0][j], tint);
                this.tri(V(last[4] || 0, last[0], last[3] || 0), rows.at(-1)[j], rows.at(-1)[i], tint);
            }
        }

        box(x, y, z, width, height, depth, tint) {
            this.loft([[y - height / 2, width / Math.SQRT2, depth / Math.SQRT2, z, x],
                [y + height / 2, width / Math.SQRT2, depth / Math.SQRT2, z, x]], 4, tint);
        }

        rail(points, radius, tint, sides = 5) {
            for (let k = 1; k < points.length; k++) {
                const a = points[k - 1], b = points[k];
                const direction = b.subtract(a).normalize();
                const tangent = BABYLON.Vector3.Cross(direction, Math.abs(direction.y) > .9 ? V(1) : V(0, 1)).normalize();
                const bitangent = BABYLON.Vector3.Cross(direction, tangent);
                const ring = Array.from({ length: sides }, (_, i) => {
                    const angle = i * 2 * Math.PI / sides;
                    return tangent.scale(Math.cos(angle) * radius).add(bitangent.scale(Math.sin(angle) * radius));
                });
                for (let i = 0; i < sides; i++) {
                    const j = (i + 1) % sides;
                    this.quad(a.add(ring[i]), a.add(ring[j]), b.add(ring[j]), b.add(ring[i]), tint);
                }
            }
        }

        paint(x1, z1, x2, z2, width, tint, y = .017) {
            const dx = x2 - x1, dz = z2 - z1;
            const len = Math.hypot(dx, dz);
            if (!len) return;
            const ox = -dz * width / (len * 2), oz = dx * width / (len * 2);
            this.quad(V(x1 - ox, y, z1 - oz), V(x1 + ox, y, z1 + oz),
                V(x2 + ox, y, z2 + oz), V(x2 - ox, y, z2 - oz), tint);
        }

        ground(x1, z1, x2, z2, tint, y = 0) {
            this.quad(V(x1, y, z1), V(x1, y, z2), V(x2, y, z2), V(x2, y, z1), tint);
        }

        circle(x, z, radius, width, tint, sides = 60) {
            for (let i = 0; i < sides; i++) {
                const a = i * Math.PI * 2 / sides, b = (i + 1) * Math.PI * 2 / sides;
                this.paint(x + radius * Math.sin(a), z + radius * Math.cos(a),
                    x + radius * Math.sin(b), z + radius * Math.cos(b), width, tint);
            }
        }

        mesh(name, scene, parent, material) {
            const mesh = new BABYLON.Mesh(name, scene);
            const data = new BABYLON.VertexData();
            data.positions = this.positions;
            data.normals = this.normals;
            data.colors = this.colors;
            data.indices = this.indices;
            data.applyToMesh(mesh);
            mesh.material = material;
            mesh.parent = parent;
            mesh.isPickable = false;
            return mesh;
        }
    }

    const helmetLower = [
        [0, .203, -.393], [.102, .208, -.372], [.197, .224, -.327], [.267, .241, -.265],
        [.310, .211, -.189], [.338, .100, -.116], [.350, -.044, -.047], [.326, -.119, .077],
        [.285, -.166, .158], [.228, -.192, .218], [.155, -.209, .254], [.079, -.217, .276],
        [0, -.221, .286]
    ];
    const helmetBrow = [
        [0, .249, -.413], [.107, .254, -.392], [.205, .266, -.340], [.277, .284, -.270],
        [.322, .287, -.190], [.347, .244, -.111], [.363, .189, -.026], [.343, .157, .085],
        [.306, .132, .168], [.252, .118, .240], [.177, .112, .282], [.091, .112, .310],
        [0, .119, .324]
    ];
    const cage = [
        [[.341, .077, -.109], [.322, .067, -.231], [.239, .051, -.348], [.110, .041, -.422]],
        [[.333, -.023, -.116], [.306, -.039, -.234], [.225, -.065, -.342], [.103, -.072, -.408]],
        [[.315, -.109, -.144], [.284, -.129, -.232], [.199, -.161, -.311], [.091, -.175, -.376]]
    ];

    function kitHelmet(mesh, kit, skin) {
        mesh.loft([[-.267,.117,.127,-.055], [-.21,.208,.191,-.038], [-.079,.265,.240,-.024],
            [.116,.283,.251,-.015], [.261,.262,.246], [.338,.206,.171,.016], [.369,.094,.10,.021]], 10, skin);
        mesh.loft([[.03,.036,.028,-.25], [.14,.046,.039,-.251], [.182,.031,.020,-.243]], 6, skin);
        const crown = [
            [.314,.355,.294,.016,.013,.006], [.386,.297,.253,.024,.022,.014],
            [.437,.216,.186,.045,.022,.036], [.463,.119,.108,.069,.010,.017]
        ];
        const sides = 24;
        const rim = contour => Array.from({ length: sides }, (_, i) => {
            const row = contour[i > 12 ? 24 - i : i];
            return V(row[0] * (i > 12 ? -1 : 1), row[1], row[2]);
        });
        const rows = [rim(helmetLower), rim(helmetBrow), ...crown.map(row => Array.from({ length: sides }, (_, i) => {
            const angle = i * 2 * Math.PI / sides, cos = Math.cos(angle);
            const rear = Math.max(0, -cos) ** 5 * row[5];
            return V(row[1] * Math.sin(angle), row[0] - row[4] * cos + rear * .38, row[3] - row[2] * cos + rear);
        }))];
        const helmetHighlight = kit.helmet;
        for (let i = 0; i < sides; i++) {
            const side = Math.min(i + 1, sides - i), next = (i + 1) % sides;
            for (let j = 1; j < rows.length; j++) {
                const a = rows[j - 1][i], b = rows[j][i], c = rows[j][next], d = rows[j - 1][next];
                const brow = j === 1 && side < 5;
                mesh.quad(a, b, c, d, brow ? kit.trim : helmetHighlight);
                if (j === 3 && side >= 6 && side <= 8) {
                    const normal = BABYLON.Vector3.Cross(b.subtract(a), d.subtract(a)).normalize();
                    const point = (u, v) => BABYLON.Vector3.Lerp(BABYLON.Vector3.Lerp(a, d, u),
                        BABYLON.Vector3.Lerp(b, c, u), v).add(normal.scale(.004));
                    mesh.quad(point(.12,.50), point(.15,.72), point(.83,.69), point(.79,.44), dark);
                }
            }
            mesh.tri(rows.at(-1)[i], V(0, .483, .088), rows.at(-1)[next], helmetHighlight);
        }
        for (const row of cage) {
            const path = [...row.map(([x, y, z]) => V(-x, y, z)), ...[...row].reverse().map(p => V(...p))];
            mesh.rail(path, .021, "#b5c5d3", 5);
        }
        for (const side of [-1, 1]) {
            mesh.rail([V(side * .115, .263, -.380), V(side * .112, .13, -.414), V(side * .107, .04, -.421),
                V(side * .102, -.072, -.409), V(side * .088, -.224, -.349)], .018, "#c9d9e5", 5);
            mesh.rail([V(side * .346, -.013, -.064), V(side * .320, -.116, -.172),
                V(side * .266, -.207, -.294), V(side * .196, -.234, -.321)], .034, kit.trim, 5);
            mesh.box(side * .137, .107, -.249, .043, .020, .016, dark);
        }
        mesh.rail([V(-.196,-.234,-.321), V(-.105,-.246,-.348), V(.105,-.246,-.348), V(.196,-.234,-.321)], .025, kit.trim);
    }

    function stickShape(mesh, kit, pole) {
        const extension = pole ? .46 : 0, butt = pole ? -1.36 : -.923;
        const path = points => points.map(([x, y, z]) => V(x, y + extension, z));
        mesh.rail([V(0, butt, 0), V(0, .42 + extension, 0)], .023, "#cfd6db", 6);
        mesh.rail([V(0, -.53, 0), V(0, .145, 0)], .026, dark, 6);
        mesh.rail([V(0, butt, 0), V(0, butt + .11, 0)], .028, "#2d3647", 6);
        for (const sign of [-1, 1]) {
            mesh.rail(path([[sign * .039,.413,0], [sign * .105,.553,-.028], [sign * .172,.671,-.049],
                [sign * .221,.809,-.066], [sign * .214,.923,-.116], [sign * .169,.967,-.135]]),
            .022, kit.trim);
        }
        mesh.rail(path([[-.171,.966,-.135], [-.09,.994,-.149], [0,1.005,-.153],
            [.09,.994,-.149], [.171,.966,-.135]]), .027, white);
        const netRows = [[.48,.062,-.025], [.59,.123,0], [.70,.168,.029], [.81,.205,.001], [.921,.19,-.073], [.979,.123,-.136]];
        for (let row = 1; row < netRows.length; row++) {
            const [y1, w1, z1] = netRows[row - 1], [y2, w2, z2] = netRows[row];
            for (let k = -3; k <= 3; k++) {
                for (const step of [-1, 1]) {
                    if (Math.abs(k + step) > 3) continue;
                    mesh.rail(path([[k * w1 / 3, y1, z1], [(k + step) * w2 / 3, y2, z2]]), .006, "#d2e3e5", 3);
                }
            }
        }
    }

    const glyphs = [[0,1,2,3,4,5], [1,2], [0,1,6,4,3], [0,1,2,3,6], [5,6,1,2], [0,5,6,2,3],
        [0,5,4,6,2,3], [0,1,2], [0,1,2,3,4,5,6], [0,1,2,3,5,6]];
    const digitSegments = [
        [-.052,.121,.052,.121], [.068,.103,.068,.018], [.068,-.018,.068,-.102],
        [-.052,-.122,.052,-.122], [-.068,-.018,-.068,-.102], [-.068,.103,-.068,.018], [-.050,0,.050,0]
    ];

    function numberShape(mesh, number, tint) {
        const text = String(Math.abs(Number(number) || 0) % 100);
        const digits = [...text].filter(digit => glyphs[Number(digit)]);
        for (const front of [-1, 1]) {
            digits.forEach((digit, i) => {
                const offset = (i - (digits.length - 1) / 2) * .186;
                for (const segment of glyphs[Number(digit)]) {
                    const [x1, y1, x2, y2] = digitSegments[segment];
                    const flip = front > 0 ? -1 : 1;
                    mesh.rail([V((x1 + offset) * flip, .57 + y1, front * .238),
                        V((x2 + offset) * flip, .57 + y2, front * .238)], .016, tint, 4);
                }
            });
        }
    }

    class PlayerRig {
        constructor(view, player) {
            this.node = new BABYLON.TransformNode("athlete-" + player.id, view.scene);
            this.node.parent = view.root;
            this.body = new BABYLON.TransformNode("torso-joint", view.scene);
            this.body.parent = this.node;
            this.kit = view.kits[player.team] || view.kits[0];
            const skin = skins[Math.abs((player.slot || 0) + player.team * 2) % skins.length];
            const boneKey = player.team + ":" + skin;
            const part = (key, build, parent = this.node) => view.instance(boneKey + ":" + key, build, parent);
            this.torso = part("jersey", mesh => {
                const kit = this.kit;
                mesh.loft([[.18,.31,.188], [.31,.361,.221], [.65,.396,.226],
                    [.77,.403,.207], [.86,.254,.15]], 10, kit.jersey);
                mesh.loft([[.86,.136,.137], [1.08,.114,.12]], 8, skin);
                mesh.rail([V(-.167,.84,-.15), V(0,.765,-.21), V(.167,.84,-.15)], .021, kit.trim);
                mesh.loft([[.198,.317,.19], [.23,.333,.201]], 10, kit.trim);
            }, this.body);
            // Number art follows the torso and uses the kit's contrast color.
            this.number = view.instance("numbers:" + player.team + ":" + player.number,
                mesh => numberShape(mesh, player.number, this.kit.number), this.body);
            this.head = part("helmet", mesh => kitHelmet(mesh, this.kit, skin), this.body);
            this.head.position.y = 1.18;
            this.hips = part("waist", mesh => mesh.loft([[-.064,.307,.195], [.09,.346,.226],
                [.225,.330,.195]], 10, this.kit.shorts), this.body);

            this.long = player.role === "D" || player.role === "LSM" || player.longPole === true;
            this.stick = view.instance("stick:" + player.team + ":" + this.long,
                mesh => stickShape(mesh, this.kit, this.long), this.node);
            this.stick.rotationQuaternion = BABYLON.Quaternion.Identity();
            this.pocket = V();
            this.stickAxis = V(.63, .69, -.35).normalize();
            this.shadow = view.instance("ground shadow", mesh => {
                const rings = 24;
                for (let i = 0; i < rings; i++) {
                    const a = i * 2 * Math.PI / rings, b = (i + 1) * 2 * Math.PI / rings;
                    mesh.tri(V(0,.006), V(Math.sin(a)*.77,.006,Math.cos(a)*.61),
                        V(Math.sin(b)*.77,.006,Math.cos(b)*.61), "#16413d");
                }
            });

            this.limbs = [-1, 1].map(sign => {
                const upper = part("sleeve", mesh => {
                    mesh.loft([[-.51,.101,.109], [.08,.112,.128], [.48,.106,.113]], 8, skin);
                    mesh.loft([[.035,.134,.149], [.34,.149,.167], [.53,.121,.140]], 8, this.kit.jersey);
                    mesh.loft([[.045,.137,.151], [.108,.141,.154]], 8, this.kit.trim);
                });
                const lower = part("glove", mesh => {
                    mesh.loft([[.02,.084,.092], [.43,.114,.120], [.52,.101,.112]], 8, skin);
                    mesh.loft([[-.57,.089,.104], [-.46,.132,.138], [-.12,.135,.144], [.05,.095,.114]], 8, this.kit.trim);
                    mesh.loft([[-.44,.136,.141], [-.35,.14,.148]], 8, this.kit.helmet);
                });
                const upperLeg = part("shorts leg", mesh => {
                    mesh.loft([[-.52,.094,.110], [.0,.143,.142], [.50,.155,.160]], 8, skin);
                    mesh.loft([[-.22,.151,.157], [.04,.17,.166], [.52,.167,.178]], 8, this.kit.shorts);
                    mesh.loft([[-.237,.156,.162], [-.16,.16,.165]], 8, this.kit.trim);
                });
                const lowerLeg = part("lower leg", mesh => {
                    mesh.loft([[-.46,.091,.109], [.02,.105,.121], [.44,.108,.121], [.53,.095,.104]], 8, skin);
                    mesh.loft([[-.53,.101,.107], [-.32,.105,.117]], 8, white);
                });
                const boot = part("boot", mesh => {
                    mesh.loft([[-.12,.130,.221,-.079], [-.073,.144,.212,-.074], [.008,.138,.195,-.06],
                        [.098,.112,.112,.011]], 8, "#1a2440");
                    mesh.loft([[-.119,.139,.220,-.08], [-.086,.145,.225,-.08]], 8, white);
                    for (let i = 0; i < 3; i++) {
                        mesh.rail([V(-.052,.018+i*.019,-.16+i*.04), V(.052,.018+i*.019,-.16+i*.04)], .009, "#b7c6d2", 4);
                    }
                });
                return { sign, upper, lower, upperLeg, lowerLeg, boot };
            });
            this.gait = (player.slot || 0) * .8;
            this.bob = 0;
        }

        pose(player, dt) {
            this.node.position.set(player.x, 0, player.z);
            this.node.rotation.y = Number.isFinite(player.yaw) ? player.yaw : 0;
            this.shadow.position.set(player.x, 0, player.z);
            const speed = player.speed || 0;
            const effort = clamp(speed / 6.5, 0, 1);
            this.gait += dt * speed * 2.8;
            const p = clamp((player.actionTime || 0) / Math.max(.12, player.actionDuration || .45), 0, 1);
            const profile = Math.sin(p * Math.PI);
            const winding = (player.action === "shoot" || player.action === "pass") ? profile : 0;
            const checking = player.action === "check" ? profile : 0;
            const scooping = player.action === "scoop" ? profile : 0;
            const dodging = player.action === "dodge" ? profile : 0;
            const drawing = player.action === "faceoff" ? profile : 0;
            const crouch = .24 * Math.max(scooping, drawing, dodging * .6);
            const bob = effort * (1 - Math.cos(this.gait * 2)) * .025;
            this.body.position.set(0, 1.03 + bob - crouch, 0);
            this.body.rotation.set(-.16 * effort - .26 * scooping, winding * (.6 - 1.25 * p) + .12 * dodging,
                Math.sin(this.gait) * effort * .025 - .19 * dodging);
            this.head.rotation.y = -.18 * winding;
            const h = this.long ? .33 : 0;
            const stickVector = V(.63 - .22 * winding, .69 - .32 * checking - .43 * scooping,
                -.35 - .43 * winding - .54 * checking - .62 * scooping).normalize();
            const pocketDesired = V(.64 + h * .42 + .13 * dodging,
                2.26 + h + bob + .42 * winding - .93 * scooping - .59 * drawing,
                -.59 - h * .72 - .42 * winding * (2 * p - .85) - .38 * checking);
            this.stick.rotationQuaternion.copyFrom(orientation(stickVector));
            const pivot = V(0, .70 + (this.long ? .46 : 0), -.1);
            const offset = V();
            pivot.rotateByQuaternionToRef(this.stick.rotationQuaternion, offset);
            this.stick.position.copyFrom(pocketDesired.subtract(offset));

            for (const limb of this.limbs) {
                const { sign } = limb;
                const phase = this.gait + (sign < 0 ? Math.PI : 0);
                const stride = Math.cos(phase) * effort * .39;
                const lift = Math.max(0, Math.sin(phase)) * effort * .26;
                const foot = V(sign * (.20 + .10 * dodging), .12 + lift, stride - .04);
                const hip = V(sign * .203, 1.12 + bob - crouch * .75, .012);
                const knee = joint(hip, foot, .53, .50, V(0, 0, -1));
                aimBone(limb.upperLeg, hip, knee);
                aimBone(limb.lowerLeg, knee, foot);
                limb.boot.position.copyFrom(foot);
                limb.boot.rotation.x = lift * 1.06;

                const shoulder = V(sign * .46, 1.74 + bob - crouch, .01 + sign * winding * .14);
                const gripDistance = sign === 1 ? 0 : this.long ? -.48 : -.37;
                const wrist = this.stick.position.add(stickVector.scale(gripDistance));
                const elbow = joint(shoulder, wrist, .35, .34, V(sign * .62, -.91, .22));
                aimBone(limb.upper, shoulder, elbow);
                aimBone(limb.lower, elbow, wrist);
            }
            this.pocket.copyFrom(BABYLON.Vector3.TransformCoordinates(pocketDesired, this.node.computeWorldMatrix(true)));
        }
    }

    function joint(a, b, upper, lower, guide) {
        const delta = b.subtract(a), length = delta.length();
        const axis = length > 0 ? delta.scale(1 / length) : V(0, -1, 0);
        const t = clamp(length, .015, upper + lower - .003);
        const along = (upper * upper - lower * lower + t * t) / (2 * t);
        const normal = guide.subtract(axis.scale(BABYLON.Vector3.Dot(guide, axis))).normalize();
        return a.add(axis.scale(along)).add(normal.scale(Math.sqrt(Math.max(0, upper * upper - along * along))));
    }

    function orientation(axis) {
        const up = V(0, 1, 0);
        const dot = clamp(axis.y, -1, 1);
        if (dot > .9999) return BABYLON.Quaternion.Identity();
        if (dot < -.9999) return BABYLON.Quaternion.RotationAxis(V(1), Math.PI);
        const cross = BABYLON.Vector3.Cross(up, axis);
        return BABYLON.Quaternion.RotationAxis(cross.normalize(), Math.acos(dot));
    }

    function aimBone(mesh, top, bottom) {
        const direction = top.subtract(bottom);
        const length = direction.length();
        mesh.position.copyFrom(top.add(bottom).scale(.5));
        mesh.scaling.y = length;
        mesh.rotationQuaternion = orientation(length > 0 ? direction.scale(1 / length) : V(0, 1, 0));
    }

    function material(scene, name, tint, specular = "#222838", emissive) {
        const m = new BABYLON.StandardMaterial(name, scene);
        m.diffuseColor = C(tint);
        m.specularColor = C(specular);
        if (emissive) m.emissiveColor = C(emissive);
        // Vertex colors distinguish kit pieces without splitting a shared bone into submeshes.
        m.backFaceCulling = false;
        return m;
    }

    function fieldSetup(view) {
        const match = view.match;
        const wide = match.halfWidth || 27.43, length = match.halfLength || 50.29;
        const goalZ = match.goalZ || 36.58, h = match.goalTop || 1.83, g = match.goalHalfWidth || .9144;
        const goalLength = view.practice() ? [-(Math.abs(goalZ))] : [-Math.abs(goalZ), Math.abs(goalZ)];
        const turf = new Geometry();
        turf.ground(-wide - 45, -length - 45, wide + 45, length + 45, "#182f3b", -.08);
        for (let i = 0, start = -length; start < length - .001; i++, start += 5.029) {
            turf.ground(-wide, start, wide, Math.min(length, start + 5.029), i % 2 ? "#306b61" : "#37776a");
        }
        const lines = new Geometry(), structures = new Geometry(), crowd = new Geometry();
        const chalk = "#d5ede2";
        for (const side of [-1, 1]) {
            const x = side * wide, z = side * length;
            lines.paint(-wide, z, wide, z, .14, chalk);
            lines.paint(x, -length, x, length, .14, chalk);
            lines.paint(-wide, side * length * .363, wide, side * length * .363, .12, chalk);
            lines.paint(side * wide * .667, -length*.183, side * wide * .667, length*.183, .13, chalk);
            turf.ground(Math.min(x, x + side * 2.7), -length, Math.max(x, x + side * 2.7), length, "#233f4a", -.04);
            for (let at = -length + 2; at < length - 1; at += 2.2) {
                lines.paint(x + side * .90, at, x + side * .90, at + 1.1, .08, "#589c98", -.02);
            }
            for (let row = 0; row < 6; row++) {
                const standX = side * (wide + 4.4 + row * 1.3);
                const level = .63 + row * .45;
                structures.box(standX, level / 2, 0, 1.35, level, length * 2 + 4.0,
                    row % 2 ? "#25364c" : "#2e4257");
                structures.box(standX + side * .58, level + .018, 0, .055, .032, length * 2 + 4.1, "#576d7c");
                for (let p = -length; p < length; p += .8) {
                    const sample = Math.abs(Math.sin(p * 49.73 + row * 25.78 + side));
                    if (sample < .27 || Math.abs(p % 15) < .9) continue;
                    const index = Math.floor(sample * 5) % 5;
                    const tint = ["#525376", "#637687", "#655771", "#785d72", "#84979c"][index];
                    crowd.box(standX - side * .11, level + .238, p + sample * .2, .24, .48, .29, tint);
                    crowd.box(standX - side * .13, level + .52, p + sample * .2, .19, .185, .19, tint);
                }
            }
            structures.box(x + side * 3.3, .46, 0, .15, .92, length * 2 + 4, "#202b42");
            structures.box(x + side * 3.2, .88, 0, .11, .08, length * 2 + 4, "#62abaa");
            structures.box(0, .65, z + side * 2.8, wide * 2 + 5, 1.3, .32, "#1e2540");
            structures.box(0, 1.3, z + side * 2.8, wide * 2 + 5, .11, .44, "#5e6589");
        }
        lines.paint(-wide, 0, wide, 0, .24, "#e7ffef");
        lines.circle(0, 0, match.creaseRadius || 2.743, .085, "#79a59b", 48);
        lines.paint(-.35, 0, .35, 0, .24, "#f2b26b", .023);

        const goals = new Geometry();
        const netLines = [];
        for (const z of goalLength) {
            const sign = Math.sign(z);
            const back = z + sign * 1.24;
            lines.circle(0, z, match.creaseRadius || 2.743, .13, chalk);
            lines.paint(-g, z, g, z, .11, "#f5e6cf");
            goals.rail([V(-g, .03, z), V(-g, h, z), V(g, h, z), V(g, .03, z)], .064, "#ed763b", 8);
            goals.rail([V(-g, .022, z), V(-.69, .022, back), V(.69, .022, back), V(g, .022, z)], .032, silver);
            goals.rail([V(-g, h, z), V(-.69, .03, back)], .023, silver);
            goals.rail([V(g, h, z), V(.69, .03, back)], .023, silver);
            for (let i = 0; i <= 12; i++) {
                const u = i / 12;
                netLines.push([V(lerp(-g, g, u), h, z), V(lerp(-.69, .69, u), .06, back)]);
                if (i === 12) continue;
                for (const beam of [-1, 1]) {
                    netLines.push([V(beam * g, h * u, z), V(beam * .69, .045, back)]);
                }
            }
            for (let i = 1; i < 13; i++) {
                const u = i / 13, span = lerp(g, .69, u);
                netLines.push([V(-span, lerp(h, .06, u), lerp(z, back, u)), V(span, lerp(h, .06, u), lerp(z, back, u))]);
            }
        }
        turf.mesh("striped field", view.scene, view.root, view.flat).freezeWorldMatrix();
        lines.mesh("paint and creases", view.scene, view.root, view.flat).freezeWorldMatrix();
        structures.mesh("stadium terraces", view.scene, view.root, view.flat).freezeWorldMatrix();
        crowd.mesh("terrace spectators", view.scene, view.root, view.flat).freezeWorldMatrix();
        goals.mesh("lacrosse goals", view.scene, view.root, view.flat).freezeWorldMatrix();
        const net = BABYLON.MeshBuilder.CreateLineSystem("lacrosse goal mesh", { lines: netLines }, view.scene);
        net.parent = view.root;
        net.color = C("#d2e4e7");
        net.alpha = .52;
        net.isPickable = false;
        net.freezeWorldMatrix();
        return { wide, length };
    }

    function lightPoles(view, wide, length) {
        const body = new Geometry(), lamps = new Geometry();
        for (const x of [-wide - 5, wide + 5]) {
            for (const z of [-length * .8, length * .8]) {
                body.rail([V(x,.1,z), V(x,13.1,z)], .13, "#314458", 6);
                body.box(x, 13.1, z, .26, 1.08, 4.08, "#314458");
                for (const side of [-1, 1]) {
                    for (let column = 0; column < 6; column++) {
                        const pos = z + (column - 2.5) * .63;
                        lamps.box(x - Math.sign(x)*.15, 13.12+side*.245, pos, .035, .34, .50, "#d0f5ff");
                    }
                }
            }
        }
        body.mesh("light pylons", view.scene, view.root, view.flat).freezeWorldMatrix();
        const m = material(view.scene, "light tower lamps", "#fcfcff", "#000000", "#8793a3");
        lamps.mesh("floodlight heads", view.scene, view.root, m).freezeWorldMatrix();
    }

    return class LacrosseView {
        constructor(scene, match, options = {}) {
            this.scene = scene;
            this.match = match;
            this.root = new BABYLON.TransformNode("PolyLax arena", scene);
            this.kits = options.kits || palettes;
            this.templates = new Map();
            this.rigs = new Map();
            this.playing = null;
            this.cameraMode = 0;
            this.flat = material(scene, "PolyLax vertex materials", "#eceef1", "#161c25", "#293043");
            this.ambient = new BABYLON.HemisphericLight("arena fill", V(.2, 1, .2), scene);
            this.ambient.intensity = .92;
            this.ambient.groundColor = C("#73869a");
            this.ambient.diffuse = C("#e2eafa");
            this.key = new BABYLON.DirectionalLight("evening key", V(-.63, -1, .45), scene);
            this.key.intensity = .92;
            this.key.diffuse = C("#ffd6b3");
            this.ambient.parent = this.root;
            this.key.parent = this.root;
            scene.clearColor = BABYLON.Color4.FromHexString("#242947ff");
            scene.fogMode = BABYLON.Scene.FOGMODE_LINEAR;
            scene.fogColor = C("#454666");
            scene.fogStart = 38;
            scene.fogEnd = 132;

            this.camera = new BABYLON.FreeCamera("sidelined broadcast", V(0, 16, 18), scene);
            this.camera.inputs.clear();
            this.camera.minZ = .22;
            this.camera.maxZ = 185;
            this.camera.fov = .77;
            scene.activeCamera = this.camera;
            this.target = V();
            this.time = 0;
            const { wide, length } = fieldSetup(this);
            lightPoles(this, wide, length);
            this.marker = BABYLON.MeshBuilder.CreateTorus("controlled player ring",
                { diameter: 1.60, thickness: .066, tessellation: 30 }, scene);
            this.marker.parent = this.root;
            this.marker.material = material(scene, "control marker", "#23c9d6", "#000000", "#107481");
            this.marker.isPickable = false;
            this.ball = BABYLON.MeshBuilder.CreateIcoSphere("game ball", { radius: .145, subdivisions: 1 }, scene);
            this.ball.parent = this.root;
            this.ball.isPickable = false;
            this.ball.material = material(scene, "ball glow", "#fbf1aa", "#473632", "#c39c3c");
            this.aimLine = BABYLON.MeshBuilder.CreateLines("shot aim line", { points: [V(), V(.01)], updatable: true }, scene);
            this.aimLine.parent = this.root;
            this.aimLine.color = C("#fcea91");
            this.aimLine.isPickable = false;
            this.aimLine.setEnabled(false);
            this.retarget();
            this.render(0, false);
        }

        practice() {
            return this.match.mode === "practice" || this.match.halfWidth < 15;
        }

        instance(key, build, parent = this.root) {
            let template = this.templates.get(key);
            if (!template) {
                const geometry = new Geometry();
                build(geometry);
                template = geometry.mesh("base " + key, this.scene, this.root, this.flat);
                template.isVisible = false;
                this.templates.set(key, template);
            }
            const instance = template.createInstance("rig " + key);
            instance.parent = parent;
            instance.isVisible = true;
            instance.isPickable = false;
            return instance;
        }

        retarget() {
            for (const player of this.match.players) {
                if (!this.rigs.has(player.id)) this.rigs.set(player.id, new PlayerRig(this, player));
            }
        }

        setAim(aim) {
            this.aim = aim && Number.isFinite(aim.x) && Number.isFinite(aim.y) && Number.isFinite(aim.z) ? aim : null;
            this.aimLine.setEnabled(!!this.aim);
        }

        cycleCamera() {
            this.cameraMode = (this.cameraMode + 1) % 2;
            return this.cameraMode;
        }

        render(dt, playing = true) {
            const match = this.match;
            const controlled = match.players.find(p => p.id === match.controlled) || match.players[0];
            if (!controlled) return;
            this.time += dt;
            this.retarget();
            for (const player of match.players) this.rigs.get(player.id).pose(player, dt);
            const ball = match.ball;
            const owner = this.rigs.get(ball.owner);
            this.ball.position.copyFrom(owner ? owner.pocket : V(ball.x, Math.max(.105, ball.y), ball.z));
            if (this.aim) {
                const p = this.rigs.get(controlled.id).pocket;
                BABYLON.MeshBuilder.CreateLines("shot aim line",
                    { points: [p, V(this.aim.x, this.aim.y, this.aim.z)], instance: this.aimLine });
            }
            this.marker.position.set(controlled.x, .061, controlled.z);
            this.marker.setEnabled(playing);

            const wide = match.halfWidth, length = match.halfLength;
            const goal = -Math.abs(match.goalZ);
            const baseX = clamp(controlled.x + clamp((ball.x - controlled.x) * .16, -3, 3), -wide + 2, wide - 2);
            let pos, target;
            if (!playing) {
                const drift = Math.sin(this.time * .45) * 1.1;
                const z = this.practice() ? 7 : Math.min(19, length * .36);
                pos = V(-6.7 + drift, 7.7, z);
                target = V(2.2, 1.2, z - 17);
            } else {
                const wideView = this.cameraMode === 1;
                const focusZ = controlled.z - (wideView ? 4.8 : 3.2);
                const followBall = clamp((ball.z - focusZ) * .15, -3.5, 2.0);
                const goalClose = Math.abs(goal - controlled.z) < 14;
                const depth = (wideView ? 18 : 11.0) + (goalClose ? -.7 : 0);
                pos = V(baseX + clamp(controlled.x * -.07, -2.0, 2.0), wideView ? 23 : 9.9, controlled.z + depth);
                target = V(baseX, wideView ? .9 : 1.12, clamp(focusZ + followBall, -length + 1, length - 1));
                if (this.aim) target.z = lerp(target.z, this.aim.z + 4, .30);
            }
            const snap = this.playing === null || (this.playing !== playing && dt === 0);
            const blend = snap ? 1 : 1 - Math.exp(-Math.max(0, dt) * (playing ? 7.5 : 3.1));
            BABYLON.Vector3.LerpToRef(this.camera.position, pos, blend, this.camera.position);
            BABYLON.Vector3.LerpToRef(this.target, target, blend, this.target);
            this.camera.setTarget(this.target);
            this.playing = playing;
        }

        dispose() {
            this.camera.dispose();
            this.root.dispose(false, true);
        }
    };
})();

// The browser UI stays inside the canvas bounds in both the web app and Playground.
const interfaceCSS = `
.plx-ui,.plx-ui *{box-sizing:border-box}
.plx-ui{--ink:#0c1822;--dark:#08151eea;--cream:#f8f6e9;--chalk:#eef7f2;--muted:#a1b4ba;--lime:#dafa6d;--line:#a9c0c22c;--pad:22px;position:fixed;z-index:20;overflow:hidden;isolation:isolate;color:var(--chalk);font:500 14px/1.35 "Avenir Next",system-ui,sans-serif;pointer-events:none;user-select:none;-webkit-user-select:none;-webkit-tap-highlight-color:transparent}
.plx-ui [hidden]{display:none!important}
.plx-ui button,.plx-ui input,.plx-ui select{font:inherit}
.plx-ui button{border:0;cursor:pointer;color:inherit;touch-action:manipulation}
.plx-ui button:focus-visible,.plx-ui input:focus-visible,.plx-ui select:focus-visible{outline:2px solid var(--lime);outline-offset:3px}
.plx-ui input,.plx-ui select{min-width:0}
.plx-ui button:disabled{cursor:default;opacity:.42}
.plx-ui .plx-menu{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:flex-end;padding:max(18px,env(safe-area-inset-top)) var(--pad) max(24px,env(safe-area-inset-bottom));background:linear-gradient(0deg,#06101afc 1%,#06101ae8 26%,#0a182368 56%,#08111812 78%);pointer-events:auto}
.plx-ui .plx-brand{position:absolute;inset:max(21px,env(safe-area-inset-top)) var(--pad) auto;display:flex;align-items:center;justify-content:space-between;pointer-events:none;color:var(--cream);letter-spacing:.16em;font-size:9px;font-weight:850}
.plx-ui .plx-brand span:first-child{display:flex;align-items:center;gap:9px}
.plx-ui .plx-brand span:first-child::before{content:"";width:16px;height:10px;display:inline-block;transform:skewX(-22deg);border:1px solid var(--lime);border-left:5px solid var(--lime)}
.plx-ui .plx-card-stack{width:min(100%,408px);margin:0 auto;position:relative;max-height:100%;overflow:auto;overscroll-behavior:contain;scrollbar-width:thin;padding:3px}
.plx-ui .plx-title{margin:0 0 7px;color:var(--cream);font:950 italic clamp(56px,15.7vw,100px)/.85 "Avenir Next Condensed","Arial Narrow",Impact,sans-serif;letter-spacing:-.075em;white-space:nowrap}
.plx-ui .plx-title i{color:var(--lime);font-style:inherit}
.plx-ui .plx-subhead{margin:15px 0 21px;color:#d6e5e3;font-size:10px;font-weight:810;letter-spacing:.19em;text-transform:uppercase;display:flex;align-items:center;gap:11px}
.plx-ui .plx-subhead::before{content:"";width:21px;height:2px;background:var(--lime)}
.plx-ui .plx-menu-button{width:100%;display:grid;grid-template-columns:40px 1fr 19px;align-items:center;gap:12px;text-align:left;margin:0 0 8px;padding:12px 15px;min-height:66px;border:1px solid var(--line);border-radius:14px;background:linear-gradient(125deg,#172b36f5,#0d1c28fa);box-shadow:0 5px 16px #030b1246;transition:transform .12s,background .12s}
.plx-ui .plx-menu-button:last-child{margin-bottom:0}
.plx-ui .plx-menu-button.is-primary{background:var(--lime);color:var(--ink);border-color:#e9ffad}
.plx-ui .plx-menu-button:active,.plx-ui .plx-aux:active,.plx-ui .plx-action:active{transform:scale(.97)}
.plx-ui .plx-menu-button strong{display:block;font-weight:850;letter-spacing:-.035em;font-size:20px;line-height:1.1}
.plx-ui .plx-menu-button small{display:block;color:#aec2c6;font-size:11px;margin-top:4px}
.plx-ui .plx-menu-button.is-primary small{color:#344d2a}
.plx-ui .plx-arrow{justify-self:end;font-weight:850;font-size:20px;line-height:1;transform:translateY(-2px)}
.plx-ui .plx-icon{position:relative;width:38px;height:38px;border:1px solid currentColor;border-radius:11px;opacity:.86}
.plx-ui .plx-icon::before,.plx-ui .plx-icon::after{content:"";position:absolute;display:block}
.plx-ui .plx-icon.match::before{inset:7px 9px;border:1px solid currentColor;border-radius:3px}
.plx-ui .plx-icon.match::after{height:1px;left:9px;right:9px;top:17px;background:currentColor}
.plx-ui .plx-icon.player::before{width:8px;height:8px;background:currentColor;border-radius:50%;top:8px;left:14px}
.plx-ui .plx-icon.player::after{width:16px;height:8px;background:currentColor;border-radius:8px 8px 3px 3px;top:19px;left:10px}
.plx-ui .plx-icon.clubs::before{width:13px;height:13px;top:10px;left:8px;border:1px solid currentColor;transform:rotate(45deg);border-radius:2px}
.plx-ui .plx-icon.clubs::after{width:13px;height:13px;top:10px;left:15px;border:1px solid currentColor;transform:rotate(45deg);border-radius:2px}
.plx-ui .plx-detail{padding:18px;border:1px solid var(--line);border-radius:19px;background:#0b1a25f5;box-shadow:0 12px 56px #030c1399}
.plx-ui .plx-detail h2,.plx-ui .plx-dialog h2{margin:12px 0 8px;font:880 clamp(30px,8vw,43px)/1.02 "Avenir Next Condensed","Arial Narrow",sans-serif;letter-spacing:-.045em}
.plx-ui .plx-detail p,.plx-ui .plx-dialog p{margin:0 0 17px;color:var(--muted);font-size:13px}
.plx-ui .plx-aux{padding:8px 12px;background:#162a36;border:1px solid var(--line);border-radius:9px;min-height:37px;font-size:11px;font-weight:780;transition:transform .12s}
.plx-ui .plx-profile{display:grid;grid-template-columns:minmax(0,1fr) 66px;gap:11px;margin:15px 0}
.plx-ui .plx-profile label{display:grid;gap:5px;color:#b3c7ca;font-size:11px;font-weight:710}
.plx-ui .plx-profile label:last-child{grid-column:span 2}
.plx-ui .plx-profile input,.plx-ui .plx-profile select{width:100%;border:1px solid #9ebebd50;border-radius:8px;color:var(--cream);background:#101f2a;padding:9px;color-scheme:dark;font-size:16px;min-height:41px;user-select:text;-webkit-user-select:text}
.plx-ui .plx-profile select{padding-inline-end:2px}
.plx-ui .plx-profile-record{display:flex;flex-wrap:wrap;gap:6px 13px;margin:0 0 14px;padding:9px 10px;color:#c9d8d5;background:#132734;border:1px solid var(--line);border-radius:8px;font-size:11px;font-weight:770}
.plx-ui .plx-profile-record span:first-child{color:var(--lime)}
.plx-ui .plx-hud{position:absolute;inset:0;color:var(--cream);pointer-events:none;touch-action:none}
.plx-ui .plx-score{position:absolute;left:13px;right:13px;top:max(12px,env(safe-area-inset-top));display:grid;grid-template-columns:1fr auto 1fr;height:59px;max-width:520px;margin:0 auto;overflow:hidden;border:1px solid #a5becb3a;border-radius:12px;background:#091723ed;box-shadow:0 7px 30px #030d154f}
.plx-ui .plx-team{display:flex;align-items:center;justify-content:center;gap:9px;min-width:0;border-top:2px solid var(--home-accent,#a894f6);background:linear-gradient(90deg,#4433715c,transparent);font-size:11px;font-weight:900;letter-spacing:.09em}
.plx-ui .plx-team.is-away{border-color:var(--away-accent,#f49667);background:linear-gradient(-90deg,#633c2860,transparent)}
.plx-ui .plx-team b{font:850 27px/1 "Avenir Next Condensed","Arial Narrow",sans-serif;letter-spacing:-.04em}
.plx-ui .plx-time{display:flex;min-width:89px;padding:0 9px;flex-direction:column;align-items:center;justify-content:center;font-variant-numeric:tabular-nums}
.plx-ui .plx-time strong{font-size:19px;line-height:1.05;font-weight:850}
.plx-ui .plx-time span{color:var(--lime);margin-top:4px;font-size:8px;font-weight:850;letter-spacing:.12em}
.plx-ui .plx-hud-top{position:absolute;top:calc(max(12px,env(safe-area-inset-top)) + 67px);left:13px;right:13px;max-width:520px;margin:0 auto;display:flex;align-items:center;gap:7px}
.plx-ui .plx-possession{flex:1;min-width:0;display:flex;align-items:center;gap:7px;padding:6px 8px;border-radius:7px;color:var(--cream);background:#0b1824c9;font-size:9px;font-weight:760;line-height:1.1;letter-spacing:.08em;text-transform:uppercase;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.plx-ui .plx-possession::before{content:"";width:6px;height:6px;background:var(--lime);border-radius:50%;flex:none}
.plx-ui .plx-possession[data-team="1"]::before{background:#f49667}
.plx-ui .plx-possession[data-team="loose"]::before{background:#b0bac7}
.plx-ui .plx-hud-top button,.plx-ui .plx-tactical button,.plx-ui .plx-sprint{pointer-events:auto;padding:8px 10px;min-height:34px;border-radius:8px;background:#0b1824e5;border:1px solid #a5becb3f;font-size:10px;font-weight:820;white-space:nowrap}
.plx-ui .plx-hud-top button{line-height:1}
.plx-ui .plx-notice{position:absolute;top:calc(max(12px,env(safe-area-inset-top)) + 111px);left:50%;transform:translateX(-50%);max-width:calc(100% - 32px);padding:7px 12px;background:#11222dee;border:1px solid #a5becb3f;border-radius:8px;color:var(--lime);font-weight:850;font-size:11px;letter-spacing:.08em;text-align:center;text-transform:uppercase}
.plx-ui .plx-meter{position:absolute;bottom:calc(max(15px,env(safe-area-inset-bottom)) + 202px);left:50%;transform:translateX(-50%);width:min(65%,245px);display:grid;gap:8px;padding:10px 12px;border-radius:9px;border:1px solid var(--line);background:#102230ed;text-align:center;font-size:10px;font-weight:850;letter-spacing:.13em}
.plx-ui .plx-meter-track{height:8px;border-radius:5px;position:relative;background:#334552}
.plx-ui .plx-meter-track::before{content:"";position:absolute;left:23%;width:46%;inset-block:0;background:#d4f779a3;border-radius:inherit}
.plx-ui .plx-meter-marker{position:absolute;top:-3px;bottom:-3px;left:0;width:3px;border-radius:3px;background:var(--cream);box-shadow:0 0 6px #f7fff9}
.plx-ui .plx-base{position:absolute;left:19px;bottom:calc(max(15px,env(safe-area-inset-bottom)) + 39px);width:112px;height:112px;display:grid;place-items:center;border:1px solid #b9cfda62;border-radius:50%;background:radial-gradient(circle,#172b3bcc 0 50%,#182c3add 51% 62%,#0a1725ee 63%);box-shadow:0 4px 18px #08131b82,inset 0 0 0 4px #cbebec16;pointer-events:auto;touch-action:none}
.plx-ui .plx-base::before{content:"";position:absolute;inset:14px;border:1px solid #b7d6e840;border-radius:50%;background:linear-gradient(0deg,transparent 49.5%,#b1d5dd3a 50%,transparent 50.5%),linear-gradient(90deg,transparent 49.5%,#b1d5dd3a 50%,transparent 50.5%);pointer-events:none}
.plx-ui .plx-knob{width:46px;height:46px;border-radius:50%;background:radial-gradient(circle at 31% 27%,#78939c,#394f60 55%,#162433 100%);border:1px solid #b7ced679;box-shadow:0 3px 11px #060e18b0,inset 0 0 0 4px #c6d8dc24;transform:translate(0,0);pointer-events:none;will-change:transform}
.plx-ui .plx-base.is-held .plx-knob{border-color:var(--lime)}
.plx-ui .plx-sprint{position:absolute;left:37px;bottom:calc(max(15px,env(safe-area-inset-bottom)) + 157px);min-width:76px;touch-action:none;color:#f3fae1}
.plx-ui .plx-sprint[data-held="true"]{color:var(--ink);background:var(--lime)}
.plx-ui .plx-controls{position:absolute;right:15px;bottom:calc(max(15px,env(safe-area-inset-bottom)) + 39px);display:flex;gap:8px;align-items:flex-end;touch-action:none}
.plx-ui .plx-action{pointer-events:auto;touch-action:none;background:linear-gradient(151deg,#e2f98b,var(--lime));color:#1a2a20;border:1px solid #ecffa3ce;border-radius:50%;width:62px;height:62px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;box-shadow:0 3px 0 #667b35,0 5px 13px #050c21a8;font-weight:900;letter-spacing:.02em;transition:transform .09s}
.plx-ui .plx-action span{font-size:18px;line-height:1;letter-spacing:-.05em}
.plx-ui .plx-action small{font-size:9px;font-weight:900}
.plx-ui .plx-action.is-pass{background:linear-gradient(150deg,#8aacfa,#476dbb);color:#fff;border-color:#a8c5ffb0;box-shadow:0 3px 0 #29436d,0 5px 13px #050c21a8;margin-bottom:16px}
.plx-ui .plx-action.is-dodge{width:45px;height:45px;margin-bottom:2px;background:#122333ef;color:var(--cream);border-color:#a5becb5f;box-shadow:0 2px 8px #050c21a8}
.plx-ui .plx-action.is-dodge span{font-size:12px}
.plx-ui .plx-action.is-dodge small{font-size:8px}
.plx-ui .plx-action[data-held="true"]{transform:scale(.93);box-shadow:none}
.plx-ui .plx-tactical{position:absolute;left:12px;right:12px;bottom:max(12px,env(safe-area-inset-bottom));display:flex;justify-content:center;gap:6px}
.plx-ui .plx-tactical button{flex:1;max-width:105px;min-height:34px;padding:6px 3px;text-transform:uppercase;font-size:9px;letter-spacing:.035em}
.plx-ui .plx-popup{position:absolute;inset:0;display:grid;align-items:center;justify-items:center;background:#06121ace;pointer-events:auto;padding:22px;touch-action:manipulation}
.plx-ui .plx-dialog{width:min(100%,335px);padding:20px;background:#0d2030;border:1px solid #d7eeec46;border-radius:17px;box-shadow:0 16px 65px #030916a1}
.plx-ui .plx-dialog h2{margin-top:0}
.plx-ui .plx-dialog .plx-menu-button{min-height:47px;grid-template-columns:1fr auto;padding:9px 13px}
.plx-ui .plx-dialog .plx-menu-button strong{font-size:16px}
@media (orientation:landscape) and (min-width:760px){
  .plx-ui .plx-menu{background:linear-gradient(90deg,#06101af2,#06101aad 29%,#06101a0b 67%);justify-content:center;padding-left:clamp(32px,7vw,110px)}
  .plx-ui .plx-card-stack{margin:0;max-width:380px}
  .plx-ui .plx-title{font-size:96px}
  .plx-ui .plx-base,.plx-ui .plx-sprint{margin-left:15px}
  .plx-ui .plx-controls{margin-right:15px}
}
.plx-ui.is-narrow{--pad:15px}
.plx-ui.is-narrow .plx-base{left:13px;width:92px;height:92px}
.plx-ui.is-narrow .plx-sprint{left:23px;bottom:calc(max(15px,env(safe-area-inset-bottom)) + 139px)}
.plx-ui.is-narrow .plx-controls{right:12px;gap:6px}
.plx-ui.is-narrow .plx-action{width:55px;height:55px}
.plx-ui.is-narrow .plx-action.is-dodge{width:40px;height:40px}
@media (max-height:600px){
  .plx-ui .plx-title{font-size:66px}
  .plx-ui .plx-subhead{margin:10px 0 14px}
  .plx-ui .plx-menu-button{min-height:56px;padding-block:8px}
  .plx-ui .plx-menu{padding-bottom:max(15px,env(safe-area-inset-bottom))}
}
`;

function interfaceMenuButton(action, icon, title, detail, primary = false) {
    return `<button type="button" class="plx-menu-button${primary ? " is-primary" : ""}" data-action="${action}"><span class="plx-icon ${icon}" aria-hidden="true"></span><span><strong>${title}</strong><small>${detail}</small></span><span class="plx-arrow" aria-hidden="true">↗</span></button>`;
}

const interfaceMarkup = `
<section class="plx-menu" aria-label="PolyLax main menu">
  <header class="plx-brand"><span>WEB PROTOTYPE</span></header>
  <div class="plx-card-stack" data-page="home">
    <h1 class="plx-title">POLY<i>LAX</i></h1>
    <p class="plx-subhead">3D field lacrosse</p>
    ${interfaceMenuButton("quick", "match", "Quick Play", "Full match or six-player practice", true)}
    ${interfaceMenuButton("career", "player", "Be a Pro", "Create a player and take the field")}
    ${interfaceMenuButton("clubs", "clubs", "PolyLax Clubs", "Clubs profile and online status")}
  </div>
  <div class="plx-card-stack plx-detail" data-page="quick" hidden>
    <button type="button" class="plx-aux" data-action="home">‹ Menu</button>
    <h2>Quick Play</h2>
    ${interfaceMenuButton("play-quick", "match", "Full Match", "Ten-on-ten exhibition", true)}
    ${interfaceMenuButton("play-practice", "player", "Practice", "Six-player offense and shooting")}
  </div>
  <div class="plx-card-stack plx-detail" data-page="career" hidden>
    <button type="button" class="plx-aux" data-action="home">‹ Menu</button>
    <h2>Be a Pro</h2>
    <p>Set up an athlete for a Player Lock exhibition. This browser saves your name, number, and position.</p>
    <div class="plx-profile">
      <label>Player name<input data-ui="name" type="text" maxlength="24" autocomplete="off" value="New Player"></label>
      <label>Jersey #<input data-ui="number" type="number" inputmode="numeric" min="0" max="99" value="3"></label>
      <label>Position<select data-ui="position">
        <option value="A">Attack</option><option value="M">Midfield</option><option value="F">Faceoff</option>
        <option value="LSM">Long-Stick Midfield</option><option value="SSDM">Short-Stick Defensive Midfield</option>
        <option value="D">Defense</option><option value="G">Goalie</option>
      </select></label>
    </div>
    <div class="plx-profile-record" data-ui="career-record" hidden><span data-ui="career-xp"></span><span data-ui="career-games"></span><span data-ui="career-last"></span></div>
    ${interfaceMenuButton("play-career", "player", "Player Lock Exhibition", "Control your athlete for a full match", true)}
  </div>
  <div class="plx-card-stack plx-detail" data-page="clubs" hidden>
    <button type="button" class="plx-aux" data-action="home">‹ Menu</button>
    <h2>PolyLax Clubs</h2>
    <p>The web Clubs lobby and online matches are pending. Set up a local athlete to play a Player Lock exhibition.</p>
    ${interfaceMenuButton("career", "player", "My Player", "Edit the athlete saved in this browser", true)}
  </div>
</section>
<section class="plx-hud" aria-label="Match controls" hidden>
  <div class="plx-score" aria-label="Scoreboard">
    <div class="plx-team"><span data-ui="home-team">WAT</span><b data-ui="home-score">0</b></div>
    <div class="plx-time"><strong data-ui="clock">2:00</strong><span data-ui="period">QUICK PLAY</span></div>
    <div class="plx-team is-away"><b data-ui="away-score">0</b><span data-ui="away-team">ARC</span></div>
  </div>
  <div class="plx-hud-top"><span class="plx-possession" data-ui="possession">Loose ball</span>
    <button type="button" data-action="camera" aria-label="Change camera">Camera</button><button type="button" data-action="pause">Pause</button>
  </div>
  <div class="plx-notice" data-ui="notice" aria-live="polite" hidden></div>
  <div class="plx-meter" data-ui="faceoff-meter" hidden><span>FACEOFF TIMING</span><span class="plx-meter-track" aria-hidden="true"><span class="plx-meter-marker" data-ui="faceoff-marker"></span></span></div>
  <div class="plx-base" data-ui="joystick" aria-label="Movement joystick"><span class="plx-knob" data-ui="knob"></span></div>
  <button type="button" class="plx-sprint" data-hold="sprint" aria-label="Hold to sprint">Sprint</button>
  <div class="plx-controls">
    <button type="button" class="plx-action is-dodge" data-play="dodge" aria-label="Dodge"><span>Q</span><small>DODGE</small></button>
    <button type="button" class="plx-action is-pass" data-play="pass" aria-label="Pass"><span>A</span><small>PASS</small></button>
    <button type="button" class="plx-action is-shoot" data-play="shoot" aria-label="Shoot"><span>B</span><small>SHOOT</small></button>
  </div>
  <nav class="plx-tactical" aria-label="Tactical calls">
    <button type="button" data-direct="swing">Swing</button><button type="button" data-direct="clear">Clear</button>
    <button type="button" data-direct="passdown">Pass down</button><button type="button" data-direct="pickdown">Pick down</button>
    <button type="button" data-direct="switch">Switch</button>
  </nav>
</section>
<section class="plx-popup" aria-label="Pause menu" hidden>
  <div class="plx-dialog">
    <h2 data-ui="dialog-title">Paused</h2><p data-ui="dialog-status">The game is paused.</p>
    <button type="button" class="plx-menu-button is-primary" data-action="resume"><strong>Resume</strong><span aria-hidden="true">↗</span></button>
    <button type="button" class="plx-menu-button" data-action="restart"><strong>Restart Match</strong><span aria-hidden="true">↻</span></button>
    <button type="button" class="plx-menu-button" data-action="exit"><strong>Main Menu</strong><span aria-hidden="true">‹</span></button>
  </div>
</section>`;

class LacrosseUI {
    constructor(canvas, callbacks, options = {}) {
        this.canvas = canvas;
        this.callbacks = callbacks;
        this.teams = options.teams || [];
        this.initialProfile = options.profile;
        this.getCareer = options.getCareer;
        this.worldRight = options.worldRight === -1 ? -1 : 1;
        this.controls = {x: 0, z: 0, sprint: false};
        this.keys = new Set();
        this.held = new Map();
        this.movement = {x: 0, z: 0};
        this.listeners = [];
        this.paused = false;
        this.final = false;
        this.aim = null;
        this.match = null;
        this.mode = "menu";
        this.root = document.createElement("div");
        this.root.className = "plx-ui";
        this.root.innerHTML = interfaceMarkup;
        if (typeof this.teams[0]?.color === "string") this.root.style.setProperty("--home-accent", this.teams[0].color);
        if (typeof this.teams[1]?.color === "string") this.root.style.setProperty("--away-accent", this.teams[1].color);
        this.style = document.createElement("style");
        this.style.textContent = interfaceCSS;
        this.nodes = Object.fromEntries(Array.from(this.root.querySelectorAll("[data-ui]"),
            node => [node.dataset.ui, node]));
        this.menu = this.root.querySelector(".plx-menu");
        this.hud = this.root.querySelector(".plx-hud");
        this.popup = this.root.querySelector(".plx-popup");
        this.pages = this.menu.querySelectorAll("[data-page]");
        this.actionButtons = Array.from(this.root.querySelectorAll("[data-play]"));
        this.directButtons = Array.from(this.root.querySelectorAll("[data-direct]"));
        this.sprint = this.root.querySelector("[data-hold]");
        document.head.appendChild(this.style);
        document.body.appendChild(this.root);
        this.readProfile();
        this.bindEvents();
        this.syncBounds();
        this.setMode("menu");
    }

    on(target, event, handler, options) {
        target.addEventListener(event, handler, options);
        this.listeners.push([target, event, handler, options]);
    }

    bindEvents() {
        this.on(window, "resize", () => this.syncBounds());
        this.on(window, "scroll", () => this.syncBounds(), true);
        this.on(window, "blur", () => this.clearControls());
        this.on(document, "fullscreenchange", () => this.syncBounds());
        this.on(document, "webkitfullscreenchange", () => this.syncBounds());
        this.on(document, "visibilitychange", () => { if (document.hidden) this.clearControls(); });
        if (window.visualViewport) this.on(window.visualViewport, "resize", () => this.syncBounds());
        if (typeof ResizeObserver !== "undefined") {
            this.observer = new ResizeObserver(() => this.syncBounds());
            this.observer.observe(this.canvas);
        }
        this.on(this.root, "click", event => {
            const button = event.target.closest("button");
            if (!button || button.disabled) return;
            if (button.dataset.action) this.menuAction(button.dataset.action);
            if (button.dataset.direct) this.send(button.dataset.direct);
            if (button.dataset.play && event.detail === 0 && !this.held.has(button)) this.sendPlay(button.dataset.play);
        });
        this.on(document, "keydown", event => this.keyboard(event, true));
        this.on(document, "keyup", event => this.keyboard(event, false));
        const joystick = this.nodes.joystick;
        this.on(joystick, "pointerdown", event => {
            if (this.joyID != null || this.paused || this.final) return;
            this.joyID = event.pointerId;
            this.capture(joystick, event);
            joystick.classList.add("is-held");
            this.stick(event);
        });
        this.on(joystick, "pointermove", event => {
            if (event.pointerId === this.joyID) this.stick(event);
        });
        for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
            this.on(joystick, name, event => {
                if (event.pointerId === this.joyID) this.resetStick();
            });
        }
        for (const button of [...this.actionButtons, this.sprint]) {
            this.on(button, "pointerdown", event => {
                if (button.disabled || this.held.has(button) || this.paused || this.final) return;
                this.capture(button, event);
                this.held.set(button, {id: event.pointerId, x: event.clientX, y: event.clientY});
                button.dataset.held = "true";
                if (button.dataset.play === "shoot" && this.context("shoot") === "shoot") this.aim = this.shotAim(0, 0);
                this.updateControls();
            });
            this.on(button, "pointermove", event => {
                const hold = this.held.get(button);
                if (this.aim && hold?.id === event.pointerId && button.dataset.play === "shoot") {
                    this.aim = this.shotAim(event.clientX - hold.x, hold.y - event.clientY);
                }
            });
            for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
                this.on(button, name, event => {
                    const hold = this.held.get(button);
                    if (!hold || hold.id !== event.pointerId) return;
                    this.held.delete(button);
                    delete button.dataset.held;
                    if (button.dataset.play === "shoot") this.aim = null;
                    this.updateControls();
                    if (name === "pointerup" && button.dataset.play) {
                    this.sendPlay(button.dataset.play, event.clientX - hold.x, hold.y - event.clientY, true);
                    }
                });
            }
        }
        for (const key of ["name", "number", "position"]) this.on(this.nodes[key], "change", () => this.profile());
    }

    capture(node, event) {
        if (event.cancelable) event.preventDefault();
        try { node.setPointerCapture(event.pointerId); } catch (_) {
            // Pointer capture can fail for a synthetic event or on a detached canvas.
        }
    }

    syncBounds() {
        const fullscreen = document.fullscreenElement || document.webkitFullscreenElement;
        const host = fullscreen && fullscreen !== this.canvas && fullscreen.contains(this.canvas) ? fullscreen : document.body;
        if (this.root.parentNode !== host) host.appendChild(this.root);
        const bounds = this.canvas.getBoundingClientRect();
        this.root.style.left = `${bounds.left}px`;
        this.root.style.top = `${bounds.top}px`;
        this.root.style.width = `${bounds.width}px`;
        this.root.style.height = `${bounds.height}px`;
        this.root.classList.toggle("is-narrow", bounds.width < 356);
        this.root.hidden = bounds.width === 0 || bounds.height === 0;
    }

    readProfile() {
        try {
            const saved = this.initialProfile || JSON.parse(localStorage.getItem("PolyLax.Web.Athlete.1") || "null");
            if (!saved) return;
            if (typeof saved.name === "string") this.nodes.name.value = saved.name.slice(0, 24);
            if (Number.isInteger(saved.number)) this.nodes.number.value = String(Math.max(0, Math.min(99, saved.number)));
            if (["A", "M", "D", "F", "G", "LSM", "SSDM"].includes(saved.position)) this.nodes.position.value = saved.position;
        } catch (_) {
            // The match still works if browser privacy settings disallow storage.
        }
    }

    profile() {
        const name = this.nodes.name.value.trim().slice(0, 24) || "New Player";
        const number = Math.max(0, Math.min(99, Math.floor(Number(this.nodes.number.value) || 0)));
        const position = this.nodes.position.value || "A";
        const profile = {name, number, position};
        if (this.callbacks.saveProfile) this.callbacks.saveProfile(profile);
        else {
            try { localStorage.setItem("PolyLax.Web.Athlete.1", JSON.stringify(profile)); } catch (_) {
                // Keep the profile on this screen for the current visit.
            }
        }
        return profile;
    }

    screen(name) {
        if (this.detail !== name) this.menu.scrollTop = 0;
        this.detail = name;
        for (const page of this.pages) page.hidden = page.dataset.page !== name;
        if (name === "career") this.careerRecord();
    }

    careerRecord() {
        const data = this.getCareer?.();
        this.nodes["career-record"].hidden = !data;
        if (!data) return;
        this.nodes["career-xp"].textContent = `${data.xp || 0} XP`;
        this.nodes["career-games"].textContent = `${data.games || 0} played · ${data.wins || 0} won`;
        const last = data.history?.[0];
        this.nodes["career-last"].textContent = last ? `Last match ${last.home}–${last.away}` : "";
    }

    setMode(mode) {
        this.mode = mode;
        this.clearControls();
        this.paused = this.final = false;
        this.popup.hidden = true;
        const playing = ["quick", "practice", "career"].includes(mode);
        this.menu.hidden = playing;
        this.hud.hidden = !playing;
        if (!playing) this.screen(mode === "clubs" ? "clubs" : "home");
        this.syncBounds();
    }

    menuAction(action) {
        if (["home", "quick", "career", "clubs"].includes(action)) {
            this.screen(action);
        } else if (action.startsWith("play-")) {
            const mode = action.slice(5);
            this.callbacks.start(mode, mode === "career" ? this.profile() : undefined);
        } else if (action === "pause") {
            this.pause();
        } else if (action === "resume") {
            this.pause(false);
        } else if (action === "restart") {
            this.callbacks.command("reset", {});
            this.pause(false);
        } else if (action === "exit") {
            this.callbacks.exit();
        } else if (action === "camera") {
            this.callbacks.camera?.();
        }
    }

    pause(open = !this.paused) {
        this.clearControls();
        this.paused = open;
        this.popup.hidden = !open;
        this.popup.querySelector('[data-action="resume"]').hidden = open && this.final;
        this.nodes["dialog-title"].textContent = this.final ? "Final score" : "Paused";
        const scores = this.match?.scores || [0, 0];
        this.nodes["dialog-status"].textContent = this.final ? `${scores[0]} – ${scores[1]}` : "Resume, restart, or return to the main menu.";
    }

    keyboard(event, down) {
        if (event.target.matches?.("input, select, textarea")) return;
        const code = event.code;
        if (code === "Escape" && down && !event.repeat) {
            if (!this.hud.hidden && !this.final) this.pause();
            else if (this.hud.hidden) this.screen("home");
            return;
        }
        if (this.hud.hidden || this.paused || this.final) return;
        const moves = ["KeyA", "KeyD", "KeyW", "KeyS", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "ShiftLeft", "ShiftRight"];
        if (moves.includes(code)) {
            event.preventDefault();
            if (down) this.keys.add(code); else this.keys.delete(code);
            this.updateControls();
            return;
        }
        if (!down || event.repeat) return;
        if (code === "Space" || code === "KeyE" || code === "KeyQ") {
            event.preventDefault();
            this.sendPlay(code === "Space" ? "shoot" : code === "KeyE" ? "pass" : "dodge");
        } else if (code === "KeyC") {
            this.callbacks.camera?.();
        } else if (code === "KeyF") {
            this.send("switch");
        }
    }

    stick(event) {
        const box = this.nodes.joystick.getBoundingClientRect();
        const radius = box.width * .35;
        const x = (event.clientX - box.left - box.width * .5) / radius;
        const z = (event.clientY - box.top - box.height * .5) / radius;
        const length = Math.hypot(x, z);
        const scaled = length <= .13 ? 0 : Math.min(1, (length - .13) / .87) / length;
        this.movement = {x: x * scaled, z: z * scaled};
        this.nodes.knob.style.transform = `translate(${this.movement.x * radius}px,${this.movement.z * radius}px)`;
        this.updateControls();
    }

    resetStick() {
        this.joyID = null;
        this.movement = {x: 0, z: 0};
        this.nodes.joystick.classList.remove("is-held");
        this.nodes.knob.style.transform = "translate(0,0)";
        this.updateControls();
    }

    updateControls() {
        const keys = this.keys;
        const left = keys.has("KeyA") || keys.has("ArrowLeft");
        const right = keys.has("KeyD") || keys.has("ArrowRight");
        const forwards = keys.has("KeyW") || keys.has("ArrowUp");
        const back = keys.has("KeyS") || keys.has("ArrowDown");
        const x = this.movement.x + Number(right) - Number(left);
        const z = this.movement.z + Number(back) - Number(forwards);
        const scale = Math.max(1, Math.hypot(x, z));
        this.controls.x = x * this.worldRight / scale;
        this.controls.z = z / scale;
        this.controls.sprint = this.held.has(this.sprint) || keys.has("ShiftLeft") || keys.has("ShiftRight");
    }

    clearControls() {
        this.keys.clear();
        for (const button of this.held.keys()) delete button.dataset.held;
        this.held.clear();
        this.aim = null;
        this.resetStick();
    }

    context(action) {
        const match = this.match;
        if (!match) return action;
        if (match.phase === "FACEOFF") {
            if (match.faceoff?.player === false || match.faceoff?.player === null) return null;
            return action === "shoot" ? "faceoff" : action === "pass" ? "counter" : null;
        }
        if (match.phase !== "LIVE") return null;
        if (action === "pass") {
            if (this.holding?.team === 1) return "poke";
            if (this.holding && this.holding.id !== match.controlled) return "call";
            if (match.ball.state === "loose") return "scoop";
        }
        if (action === "dodge") {
            if (this.holding?.team === 1) return "slap";
            if (this.holding && this.holding.id !== match.controlled) return "setpick";
        }
        if (action === "shoot" && this.holding?.id !== match.controlled) return null;
        return action;
    }

    send(action, extra = {}) {
        if (this.paused || this.hud.hidden || this.final) return;
        this.callbacks.command(action, {x: this.controls.x, z: this.controls.z, ...extra});
    }

    sendPlay(input, dx = 0, dy = 0, pointed = false) {
        const action = this.context(input);
        if (!action) return;
        if (action === "shoot" && pointed) {
            const aim = this.shotAim(dx, dy);
            this.send(action, {aimX: aim.x, aimY: aim.y});
        } else {
            this.send(action === "call" ? "pass" : action);
        }
    }

    shotAim(dx, dy) {
        const x = Math.max(-.82, Math.min(.82, dx * this.worldRight / 68));
        const y = Math.max(.19, Math.min(1.63, 1.03 + dy / 68));
        return {x, y, z: -this.match.goalZ};
    }

    update(match) {
        this.match = match;
        if (this.hud.hidden || !match) return;
        const players = match.players;
        const owner = match.ball.owner;
        this.holding = owner == null ? null : players.find(player => player.id === owner);
        const mode = this.mode === "practice" ? "PRACTICE" : this.mode === "career" ? "PLAYER LOCK" : "QUICK PLAY";
        const phase = String(match.phase || "").toUpperCase();
        const seconds = Math.max(0, Math.ceil(Number(match.clock) || 0));
        const clock = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
        const scores = match.scores;
        const setText = (name, value) => {
            const element = this.nodes[name];
            const text = String(value);
            if (element.textContent !== text) element.textContent = text;
        };
        setText("clock", clock);
        setText("period", match.periods > 1 ? `Q${match.period} · ${mode}` : mode);
        setText("home-score", scores[0]);
        setText("away-score", scores[1]);
        setText("home-team", this.teams[0]?.short || "WAT");
        setText("away-team", this.mode === "practice" ? "DEF" : this.teams[1]?.short || "ARC");
        const controlled = players.find(player => player.id === match.controlled);
        const number = controlled ? `#${controlled.number}  ·  ` : "";
        this.nodes.possession.dataset.team = this.holding ? String(this.holding.team) : "loose";
        setText("possession", number + (phase === "FACEOFF" ? "Faceoff" : this.holding?.id === match.controlled
            ? "You have possession" : this.holding ? `${this.holding.team === 0 ? "Home" : "Away"} possession`
                : ["pass", "shot", "flight"].includes(match.ball.state) ? "Ball in flight" : "Loose ball"));
        const labels = {dodge: "DODGE", pass: "PASS", call: "CALL", scoop: "SCOOP", setpick: "SET PICK", shoot: "SHOOT",
            poke: "POKE", slap: "SLAP", faceoff: "CLAMP", counter: "COUNTER"};
        if (this.context("shoot") !== "shoot") this.aim = null;
        for (const button of this.actionButtons) {
            const action = this.context(button.dataset.play);
            button.disabled = !action;
            const name = labels[action] || labels[button.dataset.play];
            if (button.lastElementChild.textContent !== name) {
                button.lastElementChild.textContent = name;
                button.setAttribute("aria-label", name);
            }
        }
        for (const button of this.directButtons) {
            const switching = button.dataset.direct === "switch";
            button.hidden = switching && this.mode === "career";
            button.disabled = phase !== "LIVE" || (!switching && this.holding?.team !== 0);
        }
        this.nodes["faceoff-meter"].hidden = phase !== "FACEOFF" || !match.faceoff;
        if (match.faceoff) this.nodes["faceoff-marker"].style.left = `${match.faceoff.progress * 100}%`;
        const notice = phase === "FACEOFF" ? (match.faceoff?.player === false || match.faceoff?.player === null
            ? "Waiting for possession" : "Clamp or counter in the green") : match.announcement;
        this.nodes.notice.hidden = !notice;
        if (notice) setText("notice", notice);
        const final = phase === "FINAL" || phase === "COMPLETE";
        if (final && !this.final) {
            this.final = true;
            this.pause(true);
        } else if (!final && this.final) {
            this.final = false;
        }
    }

    dispose() {
        this.observer?.disconnect();
        for (const [target, event, handler, options] of this.listeners) target.removeEventListener(event, handler, options);
        this.root.remove();
        this.style.remove();
    }
}

function createPolyLaxScene(activeEngine) {
    const canvas = activeEngine.getRenderingCanvas();
    const scene = new BABYLON.Scene(activeEngine);
    const teams = [
        {name: 'Philadelphia Waterdogs', short: 'WAT', color: '#9769ef'},
        {name: 'Utah Archers', short: 'ARC', color: '#f18a4d'}
    ];
    let storage;
    try { storage = globalThis.localStorage; } catch (_) { /* Storage is optional. */ }
    const career = new BrowserCareer(storage);

    // Keep touch hit areas in CSS pixels and cap the WebGL draw buffer on phones.
    const resolution = Math.min(1.5, Math.max(1, globalThis.devicePixelRatio || 1));
    activeEngine.setHardwareScalingLevel(1 / resolution);

    let match;
    let view;
    let currentMode = 'menu';
    let serial = 0;
    let matchId;
    let recorded = false;

    function makeMatch(mode, profile) {
        view?.dispose();
        match = new LacrosseMatch({mode, ...profile, seed: 321 + serial,
            periodLength: mode === 'practice' ? 180 : 60,
            teamNames: teams.map(team => team.name), teamShorts: teams.map(team => team.short)});
        view = new LacrosseView(scene, match, {teams});
    }

    function start(mode, profile) {
        if (!['quick', 'practice', 'career'].includes(mode)) return;
        const selected = mode === 'career' ? career.select(profile) : browserProfile(profile);
        currentMode = mode;
        serial += 1;
        matchId = `${Date.now()}-${serial}`;
        recorded = false;
        makeMatch(mode, selected);
        ui.setMode(mode);
    }

    function exit() {
        currentMode = 'menu';
        makeMatch('quick', browserProfile());
        ui.setMode('menu');
    }

    makeMatch('quick', browserProfile());

    const ui = new LacrosseUI(canvas, {
        start, exit,
        command: (action, payload) => {
            if (currentMode === 'menu') return false;
            if (action === 'reset' || action === 'restart') {
                start(currentMode, career.data.profile);
                return true;
            }
            return match.command(action, payload);
        },
        camera: () => view.cycleCamera?.(),
        saveProfile: profile => career.select(profile)
    }, {worldRight: -1, teams, profile: career.data.profile, getCareer: () => career.data});
    ui.setMode('menu');

    scene.onBeforeRenderObservable.add(() => {
        const elapsed = Math.min(.05, Math.max(0, activeEngine.getDeltaTime() / 1000));
        const playing = currentMode !== 'menu';
        if (playing && !ui.paused) match.update(elapsed, ui.controls);
        if (!recorded && currentMode === 'career' && match.phase === 'FINAL') {
            career.record(matchId, match);
            recorded = true;
        }
        view.setAim?.(playing && !ui.paused ? ui.aim : null);
        view.render(elapsed, playing && !ui.paused);
        ui.update(match, elapsed);
    });
    scene.onDisposeObservable.addOnce(() => {
        ui.dispose();
        view.dispose();
    });
    scene.metadata = {polylax: {
        get match() { return match; },
        get mode() { return currentMode; },
        get profile() { return career.data.profile; },
        get controls() { return ui.controls; }
    }};
    return scene;
}

return createPolyLaxScene(engine);
};

// End of PolyLax Web
