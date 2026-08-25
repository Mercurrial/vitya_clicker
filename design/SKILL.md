---
name: kardashev-design
description: Use this skill to generate well-branded interfaces and assets for KARDASHEV — a dark premium / sci-fi mobile incremental game — either for production or throwaway prototypes/mocks. Contains essential design guidelines, colors, type, fonts, geometric-glyph iconography, and UI-kit components for prototyping.
user-invocable: true
---

Read the `readme.md` file within this skill, and explore the other available files (`styles.css`, `tokens/`, `components/`, `ui_kits/kardashev/`, `guidelines/`).

If creating visual artifacts (slides, mocks, throwaway prototypes, etc.), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.

Key things to honor: the strict token palette (`--void`/`--surface-*` darks, plasma cyan `--accent` for identity/active, amber `--cta` ONLY for affordable purchases, 60-30-10 discipline); IBM Plex Sans for UI and IBM Plex Mono + `tabular-nums` for every number; scientific notation (`m.mm × 10ⁿ` hero, `m.mme+n` compact) via `ui_kits/kardashev/format.js`; minimalist geometric `Glyph`s instead of icons; and `prefers-reduced-motion` support. Never use pure black, never flood neon, never use proportional figures for numbers, never use emoji or skeuomorphic icons.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.
