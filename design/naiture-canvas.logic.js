
const TINT = {
  gold: 'oklch(0.84 0.13 100)',
  moss: 'oklch(0.72 0.13 152)',
  sky: 'oklch(0.76 0.09 220)',
  quiet: 'rgba(235,244,236,0.42)'
};

const MIN_W = 420, MIN_H = 260;

class Component extends DCLogic {
  state = {
    timeOpen: false, startOpen: false, askOpen: false, dockNear: false,
    snapHint: null, active: 'browser', drag: null,
    wins: {
      browser: { mode: 'default', box: { x: 76, y: 76, w: 900, h: 800 }, restore: null, min: false, closed: false, z: 11 },
      draft:   { mode: 'default', box: { x: 1010, y: 150, w: 500, h: 600 }, restore: null, min: false, closed: false, z: 10 }
    }
  };

  componentWillUnmount() { this.detach(); }

  detach() {
    if (this._move) window.removeEventListener('mousemove', this._move);
    if (this._up) window.removeEventListener('mouseup', this._up);
    this._move = this._up = null;
  }

  patch(id, next) {
    this.setState(s => ({ wins: { ...s.wins, [id]: { ...s.wins[id], ...next } } }));
  }

  focus = (id) => () => {
    this.setState(s => {
      const top = Math.max(...Object.values(s.wins).map(w => w.z)) + 1;
      return { active: id, wins: { ...s.wins, [id]: { ...s.wins[id], z: top } } };
    });
  };

  zoneFor(x, y, w, h) {
    if (y < 70) return 'max';
    if (y > h - 110) return x < 300 ? 'close' : 'min';
    if (x < 70) return 'left';
    if (x > w - 70) return 'right';
    return null;
  }

  metrics(win) {
    const parent = win.offsetParent || win.parentElement;
    const pr = parent.getBoundingClientRect();
    const scale = (pr.width / parent.offsetWidth) || 1;
    return { pr, scale, w: parent.offsetWidth, h: parent.offsetHeight };
  }

  ptr(ev, m) {
    return { x: (ev.clientX - m.pr.left) / m.scale, y: (ev.clientY - m.pr.top) / m.scale };
  }

  // keep the title strip reachable no matter where a drag ends
  clamp(box, m) {
    return {
      ...box,
      x: Math.max(60 - box.w, Math.min(box.x, m.w - 60)),
      y: Math.max(0, Math.min(box.y, m.h - 56))
    };
  }

  liveBox(win) {
    return { x: win.offsetLeft, y: win.offsetTop, w: win.offsetWidth, h: win.offsetHeight };
  }

  startDrag = (id) => (e) => {
    if (e.button !== 0) return;
    const el = e.currentTarget.closest('[data-window]');
    if (!el) return;
    e.preventDefault();
    e.stopPropagation();
    const m = this.metrics(el);
    const box = this.liveBox(el);
    const start = this.ptr(e, m);
    const w = this.state.wins[id];
    // dragging a snapped window releases it at the size it had before snapping
    const freeBox = w.mode === 'default' ? box : (w.restore || box);
    const ratio = box.w ? (start.x - box.x) / box.w : 0.5;
    const grabX = freeBox.w * ratio, grabY = Math.min(start.y - box.y, 40);

    this.focus(id)();
    this.patch(id, { mode: 'free', box: { ...freeBox, x: start.x - grabX, y: start.y - grabY } });
    this.setState({ drag: id });

    this._move = (ev) => {
      const p = this.ptr(ev, m);
      this.patch(id, { box: { ...freeBox, x: p.x - grabX, y: p.y - grabY } });
      this.setState({ snapHint: this.zoneFor(p.x, p.y, m.w, m.h) });
    };
    this._up = (ev) => {
      const p = this.ptr(ev, m);
      const zone = this.zoneFor(p.x, p.y, m.w, m.h);
      this.detach();
      this.setState({ drag: null, snapHint: null });
      // minimise and close keep the pre-gesture geometry so restoring lands where it was
      if (zone === 'close') this.patch(id, { closed: true, box: freeBox });
      else if (zone === 'min') this.patch(id, { min: true, box: freeBox });
      else if (zone) this.patch(id, { mode: zone, restore: freeBox });
      else this.patch(id, { box: this.clamp({ ...freeBox, x: p.x - grabX, y: p.y - grabY }, m) });
    };
    window.addEventListener('mousemove', this._move);
    window.addEventListener('mouseup', this._up);
  };

  startResize = (id, dir) => (e) => {
    if (e.button !== 0) return;
    const el = e.currentTarget.closest('[data-window]');
    if (!el) return;
    e.preventDefault();
    e.stopPropagation();
    const m = this.metrics(el);
    const box = this.liveBox(el);
    const start = this.ptr(e, m);

    this.focus(id)();
    this.patch(id, { mode: 'free', box });

    this._move = (ev) => {
      const p = this.ptr(ev, m);
      const dx = p.x - start.x, dy = p.y - start.y;
      let { x, y, w, h } = box;
      if (dir.includes('e')) w = Math.max(MIN_W, box.w + dx);
      if (dir.includes('s')) h = Math.max(MIN_H, box.h + dy);
      if (dir.includes('w')) { const nw = Math.max(MIN_W, box.w - dx); x = box.x + (box.w - nw); w = nw; }
      if (dir.includes('n')) { const nh = Math.max(MIN_H, box.h - dy); y = box.y + (box.h - nh); h = nh; }
      this.patch(id, { box: { x, y, w, h } });
    };
    this._up = () => this.detach();
    window.addEventListener('mousemove', this._move);
    window.addEventListener('mouseup', this._up);
  };

  toggleMax = (id) => (e) => {
    const el = e.currentTarget.closest('[data-window]');
    const w = this.state.wins[id];
    if (w.mode === 'max') {
      this.patch(id, { mode: 'free', box: w.restore || w.box });
    } else {
      // remember the exact on-screen geometry so restore is pixel-identical
      this.patch(id, { mode: 'max', restore: el ? this.liveBox(el) : w.box });
    }
  };

  // handles live inside the window (it clips overflow), inset just enough to grab
  handles(id) {
    const dirs = [
      ['n', 'top: 0; left: 14px; right: 14px; height: 6px; cursor: ns-resize;'],
      ['s', 'bottom: 0; left: 14px; right: 14px; height: 6px; cursor: ns-resize;'],
      ['w', 'left: 0; top: 14px; bottom: 14px; width: 6px; cursor: ew-resize;'],
      ['e', 'right: 0; top: 14px; bottom: 14px; width: 6px; cursor: ew-resize;'],
      ['nw', 'left: 0; top: 0; width: 16px; height: 16px; cursor: nwse-resize;'],
      ['ne', 'right: 0; top: 0; width: 16px; height: 16px; cursor: nesw-resize;'],
      ['sw', 'left: 0; bottom: 0; width: 16px; height: 16px; cursor: nesw-resize;'],
      ['se', 'right: 0; bottom: 0; width: 16px; height: 16px; cursor: nwse-resize;']
    ];
    return dirs.map(([dir, css]) => ({
      style: `position: absolute; ${css} z-index: 40;`,
      onDown: this.startResize(id, dir)
    }));
  }

  geometry(w, dragging) {
    const base = 'position: absolute; box-sizing: border-box;';
    const anim = dragging ? '' : ' transition: left .24s cubic-bezier(.2,.8,.2,1), top .24s cubic-bezier(.2,.8,.2,1), width .24s cubic-bezier(.2,.8,.2,1), height .24s cubic-bezier(.2,.8,.2,1);';
    if (w.mode === 'max') return `${base} left: 0; top: 0; width: 100%; height: 100%;${anim}`;
    if (w.mode === 'left') return `${base} left: 0; top: 0; width: 50%; height: 100%;${anim}`;
    if (w.mode === 'right') return `${base} left: 50%; top: 0; width: 50%; height: 100%;${anim}`;
    // final safety: a free window can never render fully outside the 1600×1000 frame
    const b = this.clamp(w.box, { w: 1600, h: 1000 });
    return `${base} left: ${Math.round(b.x)}px; top: ${Math.round(b.y)}px; width: ${Math.round(b.w)}px; height: ${Math.round(b.h)}px;${anim}`;
  }

  chrome(w, id, active, dragging) {
    const focused = active === id;
    return this.geometry(w, dragging)
      + ` border-radius: ${w.mode === 'max' ? 0 : 22}px; overflow: hidden; z-index: ${dragging === id ? 60 : w.z};`
      + ` background: rgba(13,24,17,${focused ? 0.7 : 0.6}); backdrop-filter: blur(40px) saturate(170%);`
      + ` border: 1px solid rgba(255,255,255,${focused ? 0.18 : 0.11});`
      + ` box-shadow: inset 0 1px 0 rgba(255,255,255,0.18), 0 ${focused ? 50 : 30}px ${focused ? 110 : 70}px -40px rgba(0,0,0,0.88);`
      + ` display: flex; flex-direction: column;`
      + (dragging === id ? ' opacity: .94;' : '')
      + (w.min || w.closed ? ' display: none;' : '');
  }

  snapPreview(hint) {
    if (!hint) return 'display: none;';
    const box = {
      max: 'left: 0; right: 0; top: 0; bottom: 0;',
      left: 'left: 0; width: 50%; top: 0; bottom: 0;',
      right: 'right: 0; width: 50%; top: 0; bottom: 0;',
      close: 'left: 0; width: 300px; bottom: 0; height: 110px;',
      min: 'left: 300px; right: 0; bottom: 0; height: 110px;'
    }[hint];
    const tint = hint === 'close' ? 'oklch(0.70 0.16 25' : 'oklch(0.80 0.09 220';
    return `position: absolute; ${box} z-index: 55; pointer-events: none;`
      + ` background: ${tint} / 0.16); border: 2px solid ${tint} / 0.62);`
      + ` display: flex; align-items: center; justify-content: center;`;
  }

  rnd(i, salt) {
    const x = Math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - Math.floor(x);
  }

  buildBlades() {
    const out = [];
    for (let i = 0; i < 44; i++) {
      const r1 = this.rnd(i, 1), r2 = this.rnd(i, 2), r3 = this.rnd(i, 3);
      const h = 46 + r1 * 128, w = 2 + r2 * 3.4;
      const left = (i / 44) * 104 - 2 + (r3 - 0.5) * 2.2;
      const dur = 13 + r2 * 11, lean = (r3 - 0.5) * 9, dark = 0.42 + r1 * 0.34;
      out.push({ style: `position: absolute; bottom: -8px; left: ${left.toFixed(2)}%; width: ${w.toFixed(1)}px; height: ${h.toFixed(0)}px;`
        + ` background: linear-gradient(to top, oklch(0.13 0.035 140 / ${dark.toFixed(2)}), oklch(0.20 0.05 150 / 0.05));`
        + ` border-radius: 50% 50% 2px 2px / 90% 90% 2px 2px; transform-origin: bottom center;`
        + ` transform: rotate(${lean.toFixed(1)}deg); animation: sway ${dur.toFixed(1)}s ease-in-out ${(r1 * 9).toFixed(1)}s infinite alternate;` });
    }
    return out;
  }

  renderVals() {
    const p = this.props || {};
    const edge = p.islandEdge ?? 'bottom';
    const switcherSide = p.switcherSide ?? 'center';
    const inset = p.islandInset ?? 26;
    const timeEdgeGap = p.timeEdgeGap ?? 0;
    const dockRest = p.dockRestOpacity ?? 0.2;
    const showAgentLane = p.showAgentLane ?? true;

    const st = this.state;
    const wins = st.wins;
    const maxed = Object.values(wins).some(w => w.mode === 'max' && !w.min && !w.closed);
    const toggle = (k) => () => this.setState(s => ({ [k]: !s[k] }));

    const horizontal = switcherSide === 'left' ? 'left: 0;' : switcherSide === 'right' ? 'right: 0;' : 'left: 50%; transform: translateX(-50%);';

    const taskbar = [
      { id: 'browser', title: 'Nordisk Energi — pricing', glyph: '◍', dot: TINT.sky },
      { id: 'draft', title: 'Nordics renewal — draft', glyph: '▤', dot: TINT.moss },
      { id: null, title: 'Archive', glyph: '▢', dot: TINT.quiet },
      { id: null, title: 'Field notes', glyph: '❋', dot: TINT.gold }
    ].map(t => {
      const w = t.id ? wins[t.id] : null;
      const open = !!w && !w.closed;
      const shown = open && !w.min;
      const isActive = shown && st.active === t.id;
      return {
        ...t,
        onClick: t.id
          ? () => {
              const cur = this.state.wins[t.id];
              this.patch(t.id, { min: false, closed: false, box: this.clamp(cur.box, { w: 1600, h: 1000 }) });
              this.focus(t.id)();
            }
          : () => {},
        style: `position: relative; width: 34px; height: 34px; border-radius: 11px; cursor: pointer; flex-shrink: 0;`
          + ` display: flex; align-items: center; justify-content: center; font-size: 15px; line-height: 1;`
          + ` transition: background .18s ease;`
          + (isActive
            ? ` background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.26); color: #f2f7f2;`
            : shown
              ? ` background: rgba(255,255,255,0.09); border: 1px solid rgba(255,255,255,0.13); color: rgba(242,247,242,0.8);`
              : ` background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); color: rgba(242,247,242,0.45);`),
        dotStyle: `position: absolute; bottom: -1px; left: 50%; transform: translateX(-50%);`
          + ` width: ${isActive ? 14 : open ? 5 : 0}px; height: 2.5px; border-radius: 999px; background: ${t.dot};`
          + ` opacity: ${isActive ? 1 : open ? 0.6 : 0}; transition: all .2s ease;`
      };
    });

    return {
      blades: this.buildBlades(),
      taskbar,
      showAgentLane,
      pageGridStyle: `flex: 1; min-height: 0; display: grid; grid-template-columns: ${showAgentLane ? '1fr 330px' : '1fr'};`,

      browserStyle: this.chrome(wins.browser, 'browser', st.active, st.drag),
      draftStyle: this.chrome(wins.draft, 'draft', st.active, st.drag),
      browserHandles: this.handles('browser'),
      draftHandles: this.handles('draft'),
      dragBrowser: this.startDrag('browser'),
      dragDraft: this.startDrag('draft'),
      maxBrowser: this.toggleMax('browser'),
      maxDraft: this.toggleMax('draft'),
      focusBrowser: this.focus('browser'),
      focusDraft: this.focus('draft'),

      snapZoneStyle: this.snapPreview(st.snapHint),
      snapLabel: { max: 'Maximise', left: 'Snap left', right: 'Snap right', close: 'Release to close', min: 'Release to minimise' }[st.snapHint] || '',

      toggleTime: toggle('timeOpen'), toggleStart: toggle('startOpen'), toggleAsk: toggle('askOpen'),
      timeOpen: st.timeOpen, startOpen: st.startOpen, askOpen: st.askOpen,
      dockEnter: () => this.setState({ dockNear: true }),
      dockLeave: () => this.setState({ dockNear: false, startOpen: false, askOpen: false }),
      dockHitStyle: `position: absolute; ${edge === 'top' ? 'top: 0;' : 'bottom: 0;'} left: 50%; transform: translateX(-50%); width: 720px; height: 150px; z-index: 50;`,
      switcherIslandStyle: `position: absolute; ${edge === 'top' ? 'top: 0;' : 'bottom: 0;'} ${horizontal} z-index: 51;`
        + ` display: flex; flex-direction: ${edge === 'top' ? 'column-reverse' : 'column'};`
        + ` align-items: center; gap: 12px;`,
      dockInnerStyle: `display: flex; align-items: center; gap: 8px; height: 50px; padding: 0 8px; box-sizing: border-box;`
        + ` border-radius: 16px 16px 0 0;`
        + (maxed
          ? ` background: rgba(10,18,13,0.84); border: 1px solid rgba(255,255,255,0.14); border-bottom: none;`
          : ` background: rgba(240,248,240,0.12); border: 1px solid rgba(255,255,255,0.18); border-bottom: none;`)
        + ` backdrop-filter: blur(36px) saturate(170%);`
        + ` box-shadow: inset 0 1px 0 rgba(255,255,255,0.18), 0 -12px 40px -18px rgba(0,0,0,0.7);`
        + ` transition: opacity .3s ease;`
        + (st.dockNear || st.askOpen || st.startOpen ? ` opacity: 1;` : ` opacity: ${dockRest};`),

      timeIslandStyle: `position: absolute; ${edge === 'top' ? 'top: 0;' : 'bottom: 0;'} right: ${timeEdgeGap}px; z-index: 52;`
        + ` display: flex; flex-direction: ${edge === 'top' ? 'column-reverse' : 'column'}; align-items: flex-end; gap: 12px;`,
      timePillStyle: `display: flex; align-items: center; justify-content: center; height: 50px; padding: 0 20px; box-sizing: border-box;`
        + (timeEdgeGap === 0 ? ` border-radius: 16px 0 0 0; border-right: none; border-bottom: none;` : ` border-radius: 16px 16px 0 0; border-bottom: none;`)
        + (maxed
          ? ` background: rgba(10,18,13,0.84); border: 1px solid rgba(255,255,255,0.14);`
          : ` background: rgba(240,248,240,0.12); border: 1px solid rgba(255,255,255,0.18);`)
        + ` backdrop-filter: blur(36px) saturate(170%);`
        + ` box-shadow: inset 0 1px 0 rgba(255,255,255,0.18), 0 22px 50px -22px rgba(0,0,0,0.75); cursor: pointer;`,

      startGroups: [
        { title: 'Places', items: ['Field notes', 'Memory', 'Archive', 'Growing'] },
        { title: 'Agents', items: ['Ivy — reading this page', 'Fennel — resting', 'New agent'] },
        { title: 'System', items: ['Permissions', 'Models', 'Field & weather', 'Sign out'] }
      ],
      quickTiles: [
        { name: 'Wi-Fi', detail: 'Hedgerow 5G', glyph: '≋', on: true },
        { name: 'Bluetooth', detail: 'Two devices', glyph: '✳', on: true },
        { name: 'Sound', detail: '40%', glyph: '◑', on: true },
        { name: 'Do not disturb', detail: 'Until 13:00', glyph: '◐', on: false },
        { name: 'Local models', detail: '3 warm', glyph: '⬡', on: true },
        { name: 'Field light', detail: 'Follows sun', glyph: '☀', on: true }
      ].map(t => ({
        ...t,
        style: `display: flex; align-items: center; gap: 11px; padding: 11px 13px; border-radius: 13px; cursor: pointer; transition: background .18s ease;`
          + (t.on
            ? ` background: oklch(0.76 0.09 220 / 0.2); border: 1px solid oklch(0.76 0.09 220 / 0.45);`
            : ` background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.09);`),
        glyphStyle: `width: 30px; height: 30px; border-radius: 9px; flex-shrink: 0; font-size: 14px;`
          + ` display: flex; align-items: center; justify-content: center;`
          + (t.on ? ` background: oklch(0.80 0.09 220 / 0.3); color: oklch(0.95 0.05 220);`
                  : ` background: rgba(255,255,255,0.07); color: rgba(242,247,242,0.5);`),
        nameStyle: `font-size: 12.5px; color: ${t.on ? 'rgba(242,247,242,0.95)' : 'rgba(242,247,242,0.7)'};`
      })),
      sliders: [
        { name: 'Volume', pct: '40%', tint: TINT.sky },
        { name: 'Brightness', pct: '72%', tint: TINT.gold }
      ],
      pageFacts: [
        { key: 'Page type', val: 'Pricing table, 3 tiers, NOK per connection' },
        { key: 'Your account', val: 'Tier 3 — 1,240 connections, kr 71' },
        { key: 'Changed since March', val: 'Tier 3 up 4 kr. Tier 4 threshold lowered.' },
        { key: 'Against last year', val: 'kr 88,040 / month, up 6.1% at same volume' }
      ],
      affordances: [
        { label: 'Request a quote', id: 'form#quote' },
        { label: 'Download terms (PDF)', id: 'a#terms-2026' },
        { label: 'Tier calculator', id: 'widget#calc' },
        { label: 'Contact enterprise sales', id: 'a#sales' }
      ]
    };
  }
}

