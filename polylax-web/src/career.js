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
