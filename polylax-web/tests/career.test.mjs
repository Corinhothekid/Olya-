import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../src/career.js', import.meta.url), 'utf8');
const {BrowserCareer, browserProfile} = vm.runInNewContext(`${source}\n({BrowserCareer, browserProfile});`);

test('browser profile accepts jersey zero and locks positions to supported roles', () => {
    const player = browserProfile({name: '\u0000 Riley ', number: 0, position: 'LSM'});
    assert.equal(player.name, 'Riley');
    assert.equal(player.number, 0);
    assert.equal(player.position, 'LSM');
    assert.equal(browserProfile({position: 'referee'}).position, 'M');
});

test('Player Lock stores one completed match and reloads its own progress', () => {
    const saved = new Map([['PolyLax.Career.1', 'untouched']]);
    const storage = {getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value)};
    const career = new BrowserCareer(storage);
    career.select({name: 'Riley', number: 8, position: 'F'});
    const match = {phase: 'LIVE', scores: [3, 1], controlled: 4,
        players: [{id: 4, stats: {goals: 2, assists: 1}}]};
    career.record('demo-1', match);
    assert.equal(career.data.games, 0);
    match.phase = 'FINAL';
    career.record('demo-1', match);
    career.record('demo-1', match);
    const reloaded = new BrowserCareer(storage);
    assert.equal(reloaded.data.profile.position, 'F');
    assert.equal(reloaded.data.games, 1);
    assert.equal(reloaded.data.xp, 31);
    assert.equal(reloaded.data.history[0].goals, 2);
    assert.equal(saved.get('PolyLax.Career.1'), 'untouched');
});
