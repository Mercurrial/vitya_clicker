"""KARDASHEV — Stage 1 economy simulator (v4 — CLICK-FREE).

No clicking anywhere. Bootstrap is the star core's passive *radiance*
(CORE_BASE, upgradeable) — thematically: the core always radiates energy, you
build harvesters around it. An "efficient player" (best income:cost ratio per
purchase, after Pecorella) runs the candidate Stage-1 economy.

The "wall"/prestige point is scale-free: the first moment where DOUBLING income
would take longer than DOUBLE_MIN minutes. We tune the knobs so that point lands
near ~60 minutes for an efficient player (a casual player is ~1.3-1.7x slower).

Run:  python tools/sim_stage1.py
"""
import math

# ---- Tunable knobs --------------------------------------------------------
R = 1.10                          # per-unit cost growth (geometric)
MILESTONES = [10, 25, 50, 100]    # owned counts that ×2 a line (AdCap-style)
MILESTONE_MULT = 2.0
CORE_BASE = 1.0                   # J/s the core radiates with 0 generators
DOUBLE_MIN = 20                   # income takes > this many min to 2x ⇒ wall
HARD_WAIT = 3600                  # safety: a single wait this long ⇒ stop
MAXT = 8 * 3600
SHARD_T0 = 1e6                    # shards = floor(sqrt(lifetime / SHARD_T0))

IDX_GEO, IDX_FUSION = 1, 2

# Stage 1 = first six generators of the Kardashev ladder.
GENS = [
    ("Photovoltaic Lattice", 20, 0.1),
    ("Geothermal Tap",       150, 1.0),
    ("Fusion Core",          1_700, 8.0),
    ("Antimatter Loop",      18_000, 47.0),
    ("Dyson Swarm",          200_000, 260.0),
    ("Neutron Forge",        2_100_000, 1_400.0),
]
NG = len(GENS)

# kind: 'core' (×core radiance) | 'gen' (×one gen) | 'global' (×all gens)
#       | 'coupling' (Fusion +1%/Geothermal) | 'resonance' (+10%/gen-type@25+)
UPGRADES = [
    ("core_x3",    300,        "core",      None, 3.0),
    ("core_x5",    6_000,      "core",      None, 5.0),
    ("photo_x2",   200,        "gen",       0,    2.0),
    ("geo_x2",     1_000,      "gen",       1,    2.0),
    ("fusion_x2",  11_000,     "gen",       2,    2.0),
    ("coupling",   80_000,     "coupling",  None, 1.0),
    ("cascade",    50_000,     "global",    None, 1.5),
    ("resonance",  250_000,    "resonance", None, 1.0),
    ("anti_x2",    120_000,    "gen",       3,    2.0),
    ("dyson_x2",   1_200_000,  "gen",       4,    2.0),
]


def milestone_mult(owned):
    return MILESTONE_MULT ** sum(1 for t in MILESTONES if owned >= t)


def run(shards=0, shard_bonus=0.0, stop_lifetime=None):
    owned = [0] * NG
    bought = set()
    energy = lifetime = t = 0.0
    tier_first = [None] * NG
    timeline = [(0.0, 0.0, 0.0)]  # (t, income, lifetime)

    pm = 1.0 + shard_bonus * shards  # prestige multiplier

    def core_mult():
        m = 1.0
        for u in UPGRADES:
            if u[0] in bought and u[2] == "core":
                m *= u[4]
        return m

    def gmul(i):
        m = 1.0
        for u in UPGRADES:
            if u[0] in bought and u[2] == "gen" and u[3] == i:
                m *= u[4]
        return m

    def glob():
        m = pm
        for u in UPGRADES:
            if u[0] in bought and u[2] == "global":
                m *= u[4]
        return m

    def synergy(i):
        f = 1.0
        if "resonance" in bought:
            k = sum(1 for j in range(NG) if owned[j] >= 25)
            f *= 1.0 + 0.10 * k
        if i == IDX_FUSION and "coupling" in bought:
            f *= 1.0 + 0.01 * owned[IDX_GEO]
        return f

    def out(i, ow, g):
        return ow * GENS[i][2] * milestone_mult(ow) * gmul(i) * synergy(i) * g

    def income(g):
        core = CORE_BASE * core_mult() * pm
        return core + sum(out(i, owned[i], g) for i in range(NG))

    steps = 0
    while t < MAXT and steps < 1_000_000:
        steps += 1
        g = glob()
        inc = income(g)
        unlocked = [i for i in range(NG) if i == 0 or owned[i - 1] >= 1]
        best = None
        for i in unlocked:
            cost = GENS[i][1] * (R ** owned[i])
            d = out(i, owned[i] + 1, g) - out(i, owned[i], g)
            ratio = d / cost
            if best is None or ratio > best[0]:
                best = (ratio, "gen", i, cost)
        for u in UPGRADES:
            if u[0] in bought:
                continue
            cost = u[1]
            bought.add(u[0]); after = income(glob()); bought.discard(u[0])
            ratio = (after - inc) / cost
            if best is None or ratio > best[0]:
                best = (ratio, "up", u[0], cost)

        cost = best[3]
        if energy < cost:
            if inc <= 0:
                break
            wait = (cost - energy) / inc
            if wait > HARD_WAIT and stop_lifetime is None:
                break
            t += wait
            energy += inc * wait
            lifetime += inc * wait
        energy -= cost
        if best[1] == "gen":
            i = best[2]
            owned[i] += 1
            if owned[i] == 1 and tier_first[i] is None:
                tier_first[i] = t
        else:
            bought.add(best[2])
        timeline.append((t, income(glob()), lifetime))
        if stop_lifetime is not None and lifetime >= stop_lifetime:
            break

    return dict(t=t, owned=owned, bought=bought, lifetime=lifetime,
                income=income(glob()), tier_first=tier_first, timeline=timeline)


def prestige_point(timeline, double_min=DOUBLE_MIN):
    n = len(timeline)
    for i in range(n):
        ti, inci, lifei = timeline[i]
        if inci <= 0:
            continue
        target = 2 * inci
        j = i + 1
        while j < n and timeline[j][1] < target:
            j += 1
        if j >= n:
            return ti, lifei, inci
        if (timeline[j][0] - ti) > double_min * 60:
            return ti, lifei, inci
    return timeline[-1][0], timeline[-1][2], timeline[-1][1]


def fmt(n):
    if n < 1000:
        return f"{n:.0f}"
    e = int(math.floor(math.log10(n)))
    return f"{n / 10 ** e:.2f}e{e}"


if __name__ == "__main__":
    r1 = run()
    pt, pl, pi = prestige_point(r1["timeline"])
    print("=" * 60)
    print("KARDASHEV Stage 1 — CLICK-FREE (cold start, no prestige)")
    print("=" * 60)
    print(f"natural prestige point: {pt/60:5.1f} min   (income doubling > {DOUBLE_MIN} min)")
    print(f"  income there:   {fmt(pi)} J/s")
    print(f"  lifetime there: {fmt(pl)} J")
    sh1 = int(math.sqrt(pl / SHARD_T0))
    print(f"  shards earned:  {sh1}   (floor(sqrt(L/{SHARD_T0:.0e})))")

    parts = []
    for i in range(NG):
        tf = r1["tier_first"][i]
        parts.append(GENS[i][0].split()[0] + "=" + ("-" if tf is None else f"{tf/60:.1f}"))
    print("tier first-buy (min): " + ", ".join(parts))

    print("\nincome vs time (sampled):  t(min) -> J/s")
    tl = r1["timeline"]
    for frac in (0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.65, 0.8, 1.0):
        k = min(len(tl) - 1, int(frac * (len(tl) - 1)))
        print(f"   {tl[k][0]/60:6.1f}m -> {fmt(tl[k][1])} J/s")

    print("\nRun-2 payoff by per-shard bonus (additive global multiplier):")
    for bonus in (0.03, 0.05, 0.08):
        r2m = run(shards=sh1, shard_bonus=bonus, stop_lifetime=pl)
        speed = pt / max(r2m["t"], 1e-9)
        print(f"   +{bonus*100:4.0f}%/shard (x{1+bonus*sh1:5.2f}): "
              f"reach run-1 wall in {r2m['t']/60:5.1f} min  ({speed:4.1f}x faster)")
