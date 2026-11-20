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
