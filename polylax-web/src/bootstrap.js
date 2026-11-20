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
