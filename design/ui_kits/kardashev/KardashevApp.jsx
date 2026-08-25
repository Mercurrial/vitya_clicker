/* KARDASHEV — interactive game screen, composed from the design-system components. */
const { Core, GeneratorRow, UpgradeCard, SegmentedTabs, Chip, ProgressBar } =
  window.KARDASHEVDesignSystem_4d3925;

const REDUCED = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function initialGenerators() {
  return [
    { id: "g1", name: "Photovoltaic Lattice", glyph: "photovoltaic", count: 64, rate: 1.5,     cost: 940,     mult: 1.15 },
    { id: "g2", name: "Geothermal Tap",        glyph: "geothermal",   count: 21, rate: 12,      cost: 7200,    mult: 1.15 },
    { id: "g3", name: "Fusion Core",           glyph: "fusion",       count: 8,  rate: 180,     cost: 48000,   mult: 1.16 },
    { id: "g4", name: "Antimatter Loop",       glyph: "antimatter",   count: 2,  rate: 2400,    cost: 310000,  mult: 1.18 },
    { id: "g5", name: "Dyson Swarm",           glyph: "dyson",        count: 0,  rate: 32000,   cost: 6600000, mult: 1.2,  highlight: true },
    { id: "g6", name: "Neutron Forge",         glyph: "neutron",      count: 0,  rate: 410000,  cost: 8.8e8,   mult: 1.2, locked: true },
    { id: "g7", name: "Black-Hole Accretor",   glyph: "blackhole",    count: 0,  rate: 5.2e6,   cost: 1.4e11,  mult: 1.22, locked: true },
    { id: "g8", name: "Galactic Filament",     glyph: "galactic",     count: 0,  rate: 6.6e7,   cost: 2.0e14,  mult: 1.25, locked: true },
  ];
}

function initialUpgrades() {
  return [
    { id: "u1", glyph: "overclock", title: "Fusion Overclock",  desc: "Fusion Core ×2",            cost: 340000,  state: "available" },
    { id: "u2", glyph: "coherence", title: "Quantum Coherence", desc: "J/tap ×3",                  cost: 890000,  state: "available" },
    { id: "u3", glyph: "cascade",   title: "Resonance Cascade", desc: "All generators +50%",       cost: 2100000, state: "purchased" },
    { id: "u4", glyph: "zeropoint", title: "Zero-Point Tap",    desc: "J/tap += 1% of J/s",        cost: 5400000, state: "locked" },
    { id: "u5", glyph: "catalyst",  title: "Stellar Catalyst",  desc: "Dyson Swarm ×2",            cost: 1.8e7,   state: "locked" },
    { id: "u6", glyph: "horizon",   title: "Event Horizon",     desc: "Black-Hole Accretor ×3",    cost: 9.9e9,   state: "locked" },
  ];
}

function rateOf(gens, cascade) {
  let s = 0;
  for (const g of gens) s += g.count * g.rate;
  return cascade ? s * 1.5 : s;
}

/* Hero counter — owns its own rAF and only commits when the displayed
   value actually changes (~1/sec), so it doesn't thrash the rest of the UI. */
function HeroCounter({ energyRef, jpsRef }) {
  const [, setTick] = React.useState(0);
  const lastStr = React.useRef("");
  const dispRef = React.useRef(energyRef.current);
  React.useEffect(() => {
    let raf, last = performance.now();
    const loop = (t) => {
      const dt = Math.min(0.05, (t - last) / 1000);
      last = t;
      energyRef.current += jpsRef.current * dt;
      const k = REDUCED ? 1 : Math.min(1, dt * 8);
      dispRef.current += (energyRef.current - dispRef.current) * k;
      const h = window.KFmt.hero(dispRef.current);
      const str = h.plain != null ? h.plain : h.m + "e" + h.e;
      if (str !== lastStr.current) { lastStr.current = str; setTick((n) => (n + 1) & 0xffff); }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);
  const h = window.KFmt.hero(dispRef.current);
  return (
    <div
      style={{
        fontFamily: "var(--font-mono)", fontVariantNumeric: "tabular-nums",
        fontSize: "var(--type-hero-size)", fontWeight: 700,
        letterSpacing: "var(--type-hero-tracking)", color: "var(--text-hi)",
        textShadow: "0 0 26px var(--accent-glow)", lineHeight: 1,
        display: "flex", alignItems: "baseline", justifyContent: "center", gap: 8,
      }}
    >
      {h.plain != null ? (
        <span>{h.plain}</span>
      ) : (
        <span>
          {h.m}
          <span style={{ fontSize: "0.46em", fontWeight: 500, margin: "0 1px 0 6px", color: "var(--text-mid)" }}>×10</span>
          <sup style={{ fontSize: "0.42em", fontWeight: 600, top: "-0.7em" }}>{h.e}</sup>
        </span>
      )}
      <span style={{ fontSize: "0.42em", fontWeight: 500, color: "var(--text-mid)" }}>J</span>
    </div>
  );
}

/* Core + tap feedback — isolated so taps/bursts don't re-render the lists. */
function CoreZone({ energyRef, jPerTap, showcase }) {
  const [pressed, setPressed] = React.useState(showcase && REDUCED);
  const [bursts, setBursts] = React.useState(
    showcase && REDUCED ? [{ id: 0, parts: [], text: "+" + window.KFmt.compact(jPerTap) + " J", stat: true }] : []
  );
  const burstId = React.useRef(1);
  const relRef = React.useRef(0);

  const doTap = React.useCallback(() => {
    energyRef.current += jPerTap;
    setPressed(true);
    window.clearTimeout(relRef.current);
    relRef.current = window.setTimeout(() => setPressed(false), 140);
    if (REDUCED) return;
    const id = burstId.current++;
    const parts = Array.from({ length: 6 }, (_, i) => {
      const a = (Math.PI * 2 / 6) * i + (Math.random() - 0.5) * 0.9;
      const d = 40 + Math.random() * 40;
      return { tx: Math.cos(a) * d, ty: Math.sin(a) * d };
    });
    setBursts((b) => [...b, { id, parts, text: "+" + window.KFmt.compact(jPerTap) + " J" }]);
    window.setTimeout(() => setBursts((b) => b.filter((x) => x.id !== id)), 760);
  }, [jPerTap, energyRef]);

  React.useEffect(() => {
    if (!showcase || REDUCED) return;
    const iv = window.setInterval(doTap, 1500);
    const t0 = window.setTimeout(doTap, 350);
    return () => { window.clearInterval(iv); window.clearTimeout(t0); };
  }, [showcase, doTap]);

  return (
    <section className="km-core-zone">
      <div className="km-core-wrap">
        <Core size={210} pressed={pressed} onPointerDown={(e) => { e.preventDefault(); doTap(); }} />
        <div className="km-burst-layer">
          {bursts.map((b) => (
            <React.Fragment key={b.id}>
              {!b.stat && <span className="km-ripple" />}
              <span className={"km-float" + (b.stat ? " km-static" : "")}>{b.text}</span>
              {b.parts.map((p, i) => (
                <span key={i} className="km-particle" style={{ "--tx": p.tx + "px", "--ty": p.ty + "px" }} />
              ))}
            </React.Fragment>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Entrance wrapper — the resting state (opacity 1, no offset) is committed by
   React via state, so content is always correct even if the transition can't
   visually play; the slide-in is pure decoration. Off under reduced motion. */
function EnterItem({ index = 0, flashed, children }) {
  const [shown, setShown] = React.useState(REDUCED);
  React.useEffect(() => {
    if (REDUCED) return;
    const t = window.setTimeout(() => setShown(true), 30);
    return () => window.clearTimeout(t);
  }, []);
  return (
    <div
      className={flashed ? "km-pop" : undefined}
      style={{
        opacity: shown ? 1 : 0,
        transform: shown ? "none" : "translateY(12px)",
        transition: REDUCED ? "none" : "opacity 320ms ease, transform 360ms cubic-bezier(0.22,0.61,0.36,1)",
        transitionDelay: REDUCED ? "0ms" : index * 50 + "ms",
      }}
    >
      {children}
    </div>
  );
}

function KardashevApp({ startTab = "Generators", showcase = false }) {
  const [tab, setTab] = React.useState(startTab);
  const [gens, setGens] = React.useState(initialGenerators);
  const [ups, setUps] = React.useState(initialUpgrades);
  const [flash, setFlash] = React.useState({});
  const energyRef = React.useRef(1240000);

  const cascade = ups.find((u) => u.id === "u3").state === "purchased";
  const coherence = ups.find((u) => u.id === "u2").state === "purchased";
  const jPerSec = rateOf(gens, cascade);
  const jPerTap = 4200 * (coherence ? 3 : 1);
  const jpsRef = React.useRef(jPerSec);
  jpsRef.current = jPerSec;

  const doFlash = (id) => setFlash((f) => ({ ...f, [id]: (f[id] || 0) + 1 }));

  const buyGen = (g) => {
    if (g.locked || energyRef.current < g.cost) return;
    energyRef.current -= g.cost;
    setGens((arr) => arr.map((x) => (x.id === g.id ? { ...x, count: x.count + 1, cost: Math.ceil(x.cost * x.mult) } : x)));
    doFlash(g.id);
  };
  const buyUp = (u) => {
    if (u.state !== "available" || energyRef.current < u.cost) return;
    energyRef.current -= u.cost;
    setUps((arr) => arr.map((x) => (x.id === u.id ? { ...x, state: "purchased" } : x)));
    doFlash(u.id);
  };

  return (
    <div className={"km-app" + (REDUCED ? " km-reduced" : "")}>
      <header className="km-header">
        <div className="km-tier">KARDASHEV · TYPE I</div>
        <HeroCounter energyRef={energyRef} jpsRef={jpsRef} />
        <div className="km-chips">
          <Chip icon="▲" value={window.KFmt.compact(jPerSec) + " J/s"} tone="accent" />
          <Chip icon="⊙" value={window.KFmt.compact(jPerTap) + " J/tap"} tone="mid" />
        </div>
        <div style={{ padding: "0 28px" }}><ProgressBar value={0.42} /></div>
      </header>

      <CoreZone energyRef={energyRef} jPerTap={jPerTap} showcase={showcase} />

      <section className="km-sheet">
        <div className="km-sheet-tabs">
          <SegmentedTabs tabs={["Generators", "Upgrades"]} active={tab} onChange={setTab} />
        </div>
        <div className="km-sheet-body">
          <div className="km-fade" />
          <div className="km-scroll">
            {tab === "Generators" ? (
              <div key="gen" className="km-list">
                {gens.map((g, i) => {
                  const affordable = !g.locked && energyRef.current >= g.cost;
                  const contribution = g.locked
                    ? "Locked"
                    : g.count > 0
                      ? "+" + window.KFmt.compact(g.count * g.rate) + " J/s"
                      : "+" + window.KFmt.compact(g.rate) + " J/s ea";
                  return (
                    <EnterItem key={g.id} index={i} flashed={!!flash[g.id]}>
                      <GeneratorRow
                        glyph={g.glyph} name={g.name} count={g.count} rate={contribution}
                        price={g.locked ? "—" : window.KFmt.compact(g.cost) + " J"}
                        affordable={affordable} locked={g.locked} highlighted={g.highlight && !affordable}
                        onBuy={() => buyGen(g)}
                      />
                    </EnterItem>
                  );
                })}
              </div>
            ) : (
              <div key="up" className="km-grid">
                {ups.map((u, i) => (
                  <EnterItem key={u.id} index={i} flashed={!!flash[u.id]}>
                    <UpgradeCard
                      glyph={u.glyph} title={u.title} desc={u.desc}
                      price={window.KFmt.compact(u.cost) + " J"}
                      state={u.state} onBuy={() => buyUp(u)}
                    />
                  </EnterItem>
                ))}
              </div>
            )}
          </div>
        </div>
      </section>
    </div>
  );
}

window.KardashevApp = KardashevApp;
