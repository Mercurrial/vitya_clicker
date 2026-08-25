# KARDASHEV — Design System

# **KARDASHEV** is a mobile incremental / idle game with a **dark premium, sci-fi** identity. The player "feeds" a star core, accumulating **energy (joules, J)** and climbing the **Kardashev scale** of civilizations. Tapping the central core yields energy by hand; **generators** produce it automatically; **upgrades** are one-time multipliers. Growth is exponential, so the whole interface is built around making astronomically large numbers feel legible, alive, and rewarding.

This project is the design system for that game: design tokens, reusable UI components, foundation specimen cards, and a full interactive UI kit recreating the game's main screen.

> **Sources.** This system was authored from a written product/design brief (no external codebase or Figma file). There is no upstream repository or design URL to link — the brief itself is the source of truth, and its token values, type scale, geometry, and screen anatomy are encoded faithfully in `tokens/` and the UI kit.

---

## Concept & numbers

- Energy is measured in **joules (J)**. Rates are **J/s** (auto production) and **J/tap** (manual).
- **Number formatting** (`ui_kits/kardashev/format.js`, `window.KFmt`):
  - `< 1000` → grouped integer (`750`).
  - `≥ 1000` → scientific. The **hero counter** uses elegant `m.mm × 10ⁿ` (e.g. `4.20 × 10²³`); **compact** places (rates, prices, card stats) use `m.mme+n` (e.g. `4.20e23`).
  - Mantissa is **always 2 decimals** (3 significant figures) and rendered in a **monospace, tabular** font so the width never jumps as values tick.

---

## CONTENT FUNDAMENTALS

**Voice.** Terse, scientific, confident. The game speaks in the vocabulary of physics and megastructures, never in cute idle-game filler. No exclamation marks, no second-person hand-holding, no "Congrats!" — the numbers and the glow do the talking.

**Casing & labels.** Section/tab labels are **UPPERCASE, tracked** (`GENERATORS`, `UPGRADES`, `KARDASHEV · TYPE I`). Entity names are **Title Case** (`Photovoltaic Lattice`, `Black-Hole Accretor`). The tier line uses a middot separator: `KARDASHEV · TYPE I`.

**Naming ladder.** Generators ascend the real Kardashev energy ladder, planetary → stellar → galactic: *Photovoltaic Lattice, Geothermal Tap, Fusion Core, Antimatter Loop, Dyson Swarm, Neutron Forge, Black-Hole Accretor, Galactic Filament.* Upgrades are evocative physics terms paired with a blunt mechanical effect string: **"Fusion Overclock — Fusion Core ×2"**, **"Quantum Coherence — J/tap ×3"**, **"Resonance Cascade — all generators +50%"**.

**Effect copy.** Upgrade descriptions are formulae, not prose: `Fusion Core ×2`, `J/tap ×3`, `all generators +50%`, `J/tap += 1% of J/s`. Read like a patch note, not marketing.

**Units.** Always suffix the unit: `… J`, `… J/s`, `… J/tap`. Never bare numbers in stat positions.

**Emoji.** None. Iconography is geometric glyphs and a small set of Unicode symbols (`▲`, `⊙`) only.

---

## VISUAL FOUNDATIONS

**Palette & the 60-30-10 rule.** The system is disciplined: **dark neutrals \~60%** (`--void` background, `--surface-1/2/3`), **mid surfaces + plasma cyan \~30%**, **amber CTA ≤10%**. Cyan (`--accent #34E2D6`) is the identity colour — energy, the core, anything *active*. Amber (`--cta` gradient `#FFC24B→#FF8A00`) is reserved **exclusively for affordable purchases**; it must never flood a large area. The background is **`--void #0A0D14`, never pure black**.

**Type.** Two families. UI text is **IBM Plex Sans** (400/500/600). Everything with digits — counters, rates, prices, card stats — is **IBM Plex Mono** with `font-variant-numeric: tabular-nums` **everywhere**. Hero number is 44px/700 at `-0.02em`; J/s & J/tap chips 13px/500; tab labels 14px/600 `+0.04em` uppercase; entity name 15px/600; description 12px/400 in mid text; price 14px/600 mono.

**Geometry.** 8pt grid (4/8/12/16/20/24/32). Radii: **sheet top 28, card 18, button 14, pill 999**. Card shadow is `0 8px 24px rgba(0,0,0,0.45)` plus an `inset 0 1px 0 rgba(255,255,255,0.05)` top highlight.

**Surfaces & glass.** Cards default to `--surface-2`; active/elevated to `--surface-3`. The bottom sheet is a **glass panel**: `rgba(23,28,40,0.55)` + `backdrop-filter: blur(14px)` + a 1px `rgba(255,255,255,0.08)` border and a 1px inset top highlight. A soft top fade-gradient masks scrolling content under the sheet's tab bar.

**The core.** A \~210px circular button with a **radial plasma-cyan gradient** (bright centre → deep teal → void edge), a dark inner ring, and a soft cyan glow halo. It carries a gentle **idle pulse** (scale 1.0↔1.03 over 2.4s, glow breathing in time).

**Motion.** Easing is `cubic-bezier(0.22,0.61,0.36,1)` (decelerate) for entrances and the tab thumb; tap feedback eases out. Signature animations: count-up lerp on the hero (tabular holds width); **tap burst** = expanding ripple ring (scale 0→2.2, 600ms) + floating `+J` gain (translateY −48px, 700ms) + 6 cyan quantum particles flung along random vectors (700ms); purchase = card 1.0→1.04→1.0 + accent flash (220ms); content entrance = fade + translateY 16→0, 60ms stagger. **Everything is gated on `prefers-reduced-motion`.**

**States.** Active = cyan tint + cyan inset border. Affordable = amber pill/border + glow. Unaffordable = dim text, no amber. Locked = greyscale + \~0.45 opacity on the whole row. The nearest-to-unlock generator gets a cyan-edged highlight. Purchased upgrade = cyan check + struck-through price + fade to \~0.4.

**Press.** Buttons shrink to `scale(0.96)` on pointer-down; the core deepens to `scale(0.96)` with an intensified glow.

---

## ICONOGRAPHY

KARDASHEV uses **no icon font and no detailed/skeuomorphic icons**. Iconography is **minimalist stroked geometric glyphs** rendered by the `Glyph` component (`components/core/Glyph.jsx`) at `stroke-width 1.5`, `currentColor`, on a 24px grid. Each generator and upgrade maps to one abstract glyph (a 2×2 cell for *Photovoltaic*, nested orbits for *Fusion*, a ring + point for *Black-Hole*, etc.). Glyphs render in **mid grey by default and plasma cyan when the related entity is active/unlocked**, via the `GlyphTile` wrapper.

A tiny set of **Unicode symbols** appears in text positions: `▲` (production rate), `⊙` (per-tap), `✓` (purchased), `×10ⁿ` / `×N` (scientific & owned counts). **No emoji.** These glyphs are intentionally drawn in code because they are abstract geometry, not representational icons — there are no raster/SVG art assets to ship.

---

## Index / manifest

**Root**

- `styles.css` — global entry point (imports only). Consumers link this.
- `tokens/colors.css`, `tokens/typography.css`, `tokens/spacing.css` — design tokens + the IBM Plex font import.
- `readme.md` (this file), `SKILL.md` (Agent-Skills wrapper).

**Foundation cards** (`guidelines/`, shown in the Design System tab)

- Colors — Surfaces · Accent & CTA · Text & Glass
- Type — Hero counter & numbers · UI text scale
- Spacing — 8pt grid · Radii & card shadow

**Components**

- `components/core/` — `Button`, `Chip`, `ProgressBar`, `SegmentedTabs`, `Glyph`, `GlyphTile`
- `components/game/` — `Core`, `GeneratorRow`, `UpgradeCard`

**UI kit**

- `ui_kits/kardashev/` — `index.html` (three interactive iPhone-14 frames: Generators, Upgrades, Core-pressed), `KardashevApp.jsx` (the game screen), `format.js` (number formatting).

> **Preview caveat.** The in-editor live preview keeps CSS *animations* in a pending state, so they don't visibly play in the editor/Design-System tab — the UI renders its correct resting state instead. All motion (idle pulse, tap burst, count-up, purchase flash, entrance) plays normally in exported/standalone output. Entrances are authored to be state-driven so content is never hidden if an animation can't run.
