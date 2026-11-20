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
