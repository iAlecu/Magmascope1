# Eruption Simulator — Design

**Date:** 2026-05-08
**Project:** Magmascope (`volcano-globe (7).html`)
**Status:** Spec — pending implementation plan
**Priority queue position:** #7

## Goal

For every active volcano in `VOLCANO_DATA` (status === 'Active'; ~163 entries), let the user trigger a simulated eruption from the existing info panel. The simulator renders three concentric destruction/hazard zones on the 3D globe and replaces the panel body with a damage report covering affected area, population at risk, named cities (where curated), and aftereffects.

This is a single-file extension to `volcano-globe (7).html` — no build, no new dependencies, no changes to the visual identity.

## Non-goals (explicit)

- Wind-aware directional plumes
- Lava flow paths along terrain
- Time-evolving ash dispersion or playback timeline
- Real-time casualty estimation models
- Sound effects
- Simulations for Dormant or Extinct volcanoes
- More than 20 curated volcanoes in this phase (the override map is extensible; phase 2 expands after the user tests phase 1)

## User flow

1. User selects an active volcano. The standard info panel renders, with a new **Simulate Eruption** button below the safety section.
2. User clicks **Simulate Eruption**.
3. Three concentric translucent zones ripple outward from the volcano cone over ~1.8 s on the globe; the cone briefly pulses red.
4. The panel re-renders into "damage report" mode: eruption banner, zone summary table, population-at-risk chips, named cities (if curated), aftereffects prose, footer disclaimer, and a **Reset** button at the top.
5. User clicks **Reset** (or selects a different volcano, or presses ESC, or closes the panel) → zones are cleared from the globe and the panel reverts to the normal layout.

The button only appears for `v.status === 'Active'`.

## Architecture

All new code lives in `volcano-globe (7).html` in section 3.5, adjacent to the existing safety/legend code. The integration points are:

| Concern | Existing thing | New thing |
|---|---|---|
| Panel body | `renderPanel(v)` in section 3.5 | Add optional `mode` parameter; insert button below `renderSafetySection(v)` when `v.status === 'Active'`; swap body when `mode === 'eruption'` |
| Globe meshes | `clusterCones[]` added to `globe.scene()` | New `THREE.Group` `eruptionGroup` added to `globe.scene()`; tagged `userData._isEruptionZones = true` |
| State | `lockedVolcano` (existing) | Module-scoped `activeEruption = { volcanoId, group, startTime }` (single instance) |
| Cleanup | `closePanel`, ESC handler, lock-on flow | All three call `clearEruptionZones()` before doing their normal work |
| i18n | `t()`, `tFallback()`, `rerenderI18nDynamic()` | New keys under `panel.*`, `eruption.tier.*`, `eruption.aftereffects.*`, `eruption.<volcanoId>.aftereffects` |
| Constants | `MONITORING_AGENCIES`, `HAZARDS_BY_TYPE` above `renderPanel` | `ERUPTION_VEI_RADII`, `ERUPTION_OVERRIDES`, `ERUPTION_AFTEREFFECTS_BY_TIER`, `POP_DENSITY_BY_COUNTRY` next to them |

No file outside `volcano-globe (7).html` is touched.

## Hazard zone model

Three zones per eruption, defined by an outer radius in km:

- **Inner — pyroclastic flow lethality zone.** Total destruction. Color `rgba(255, 87, 34, 0.55)` (matching Cataclysmic VEI 7-8 cones).
- **Middle — severe ashfall and lahar reach.** Heavy infrastructure damage, evacuation zone. Color `rgba(255, 167, 38, 0.40)` (Significant amber).
- **Outer — light ashfall and aviation hazard.** Disruption rather than destruction. Color `rgba(255, 213, 79, 0.25)` (light gold).

Each zone also draws a thin solid edge ring at its outer radius using full-opacity matching color.

### Default radii by VEI

Used for any active volcano without an `ERUPTION_OVERRIDES` entry.

| VEI | Inner (km) | Middle (km) | Outer (km) | Tier label |
|----:|-----------:|------------:|-----------:|------------|
| 0   |        0.5 |         2.0 |        5.0 | Effusive |
| 1   |        1.0 |         4.0 |       10.0 | Gentle |
| 2   |        2.0 |         8.0 |       25.0 | Explosive |
| 3   |        4.0 |        15.0 |       50.0 | Severe |
| 4   |        8.0 |        30.0 |      100.0 | Cataclysmic |
| 5   |       15.0 |        60.0 |      200.0 | Paroxysmal |
| 6   |       25.0 |       100.0 |      400.0 | Colossal |
| 7   |       40.0 |       180.0 |      800.0 | Super-colossal |
| 8   |       60.0 |       300.0 |     1500.0 | Mega-colossal |

These are rule-of-thumb numbers derived from real volcanological scaling (pyroclastic reach ~ `2^(VEI/2)` km, ashfall envelope an order of magnitude wider). Tunable per-volcano via the override map.

### Curated overrides — schema

```js
ERUPTION_OVERRIDES['vesuvius'] = {
  zones: { innerKm: 7, middleKm: 30, outerKm: 100 },
  population: { inner: 700_000, middle: 3_100_000, outer: 6_000_000 },
  cities: {
    inner:  ['Torre del Greco', 'Ercolano (ancient Herculaneum)'],
    middle: ['Naples', 'Pompeii', 'Salerno'],
    outer:  ['Rome', 'Bari']
  },
  aftereffects: 'eruption.vesuvius.aftereffects'  // ALWAYS an i18n key — never a literal string
};
```

Any field is optional — partial overrides fall through to VEI defaults / templated text. The `aftereffects` value is always an i18n key (the actual paragraph lives in the EN/RO dictionary). This keeps translation flow consistent and avoids per-render branching on "is this a key or a literal?".

### Phase 1 curation list (20 notable volcanoes)

Override keys are the `id` strings from `VOLCANO_DATA` entries. Implementer must grep `VOLCANO_DATA` to confirm each id (e.g., `'vesuvius'`, `'krakatoa'`, `'st-helens'`); if a name on the list is not in the data, skip it and note in the implementation summary.

Display names of phase-1 targets: Vesuvius, Krakatoa, Tambora, Mount St. Helens, Pinatubo, Eyjafjallajökull, Mount Fuji, Etna, Sakurajima, Kīlauea, Mauna Loa, Yellowstone, Toba, Taal, Merapi, Nyiragongo, Hekla, Erebus, Cotopaxi, Unzen.

The override map is trivially extensible. The user plans to expand it after testing phase 1.

## Rendering — spherical cap meshes

### Geometry

Each zone is a `THREE.Mesh` whose geometry is a tessellated spherical cap — a disc on the sphere surface bounded by a small-circle of angular radius θ:

```
θ_radians = radiusKm / EARTH_RADIUS_KM       // EARTH_RADIUS_KM = 6371
sphereR    = 100                              // existing globe radius (Three.js units)
kmPerUnit  = EARTH_RADIUS_KM / sphereR        // = 63.71
```

The cap is built by generating ring vertices around the cap's pole at angular radius θ (default 64 segments) plus a center vertex, and triangle-fanning. The cap is then oriented so its pole vector points from the sphere center to the volcano lat/lng.

To prevent z-fighting between overlapping zones, each cap is placed at `sphereR + ε` with `ε = 0.05` (inner), `0.04` (middle), `0.03` (outer). Inner draws on top.

### Material

```
THREE.MeshBasicMaterial({
  color: <zone color>,
  opacity: <zone opacity>,
  transparent: true,
  depthWrite: false,
  side: THREE.DoubleSide,
  blending: THREE.NormalBlending
})
```

No lighting — keeps caps readable on the night side.

### Edge stroke

Each cap also gets a thin great-circle ring at the same radius rendered as a `THREE.LineLoop` with `LineBasicMaterial` (matching color, full opacity).

### Animation

A single `requestAnimationFrame` loop tied to `activeEruption.startTime`:

```
const t = clamp01((now - startTime) / 1800);
const easeOutCubic = (x) => 1 - Math.pow(1 - x, 3);
[inner, middle, outer].forEach((cap, i) => {
  const delay = i * 0.15;            // outer chases inner
  const localT = clamp01((t - delay) / (1 - delay));
  cap.rebuildAt(targetRadius * easeOutCubic(localT));
});
```

Per-frame cost: ~64 vertices × 3 caps × ~30 frames total. Loop terminates when `t === 1`. Once the animation completes, no per-frame work runs while the sim sits idle on screen.

### Cone pulse

For the duration of the animation, the volcano's cluster cone material has its `emissive` color blended toward `#ff5722`, then back. The cone is found by `clusterCones.find(c => c.userData.volcanoId === v.id)` (already-set on existing cones). Original emissive is restored on cleanup.

### Cleanup — `clearEruptionZones()`

1. Remove `eruptionGroup` from `globe.scene()`.
2. Dispose all child geometries and materials.
3. Restore the volcano cone's original emissive.
4. Set `activeEruption = null`.

Wired into:
- The Reset button click handler.
- The existing ESC handler (extended).
- `closePanel()` — called before existing close logic.
- The volcano-selection / lock-on path — called before locking onto a new volcano.

## Panel — damage report mode

`renderPanel(v, opts)` accepts an `opts.mode` parameter. When `opts.mode === 'eruption'`, the body below the hero/title swaps to:

### 1. Eruption banner

A strip below the title with:
- VEI tier label (`Cataclysmic`, `Paroxysmal`, etc. from `eruption.tier.<n>`)
- Subtitle: "Hypothetical eruption — modeled at present-day VEI <n>"
- **Reset** button on the right

Background: same hot-orange as the inner zone. Ties the panel to the globe visually.

### 2. Zone summary table

Three rows, one per zone:

```
ZONE              RADIUS    AREA
● Pyroclastic     7 km      154 km²
● Severe ashfall  30 km     2,827 km²
● Light ashfall   100 km    31,416 km²
```

Area is computed `2π · R² · (1 - cos θ)` where R is Earth's radius and θ is the cap's angular radius. Always shown.

### 3. Population at risk

Three chips: `Inner: 700K · Middle: 3.1M · Outer: 6M`.

For curated volcanoes, uses override numbers. For the rest, computed from a `POP_DENSITY_BY_COUNTRY` lookup table (people per km², ~30 rows covering every country present in `VOLCANO_DATA`, with a `_default` fallback of 50 for missing entries) multiplied by zone area, with a footnote: "Estimated from country-average population density." Always shown.

Densities are sourced from the latest World Bank country-average data and rounded to 1–2 sig figs. Examples: Indonesia 150, Japan 340, USA 36, Iceland 4, Italy 200, Russia 9, Antarctica 0 (special-cased: population at risk = 0 for all zones, with a footnote "No permanent population — research stations only").

### 4. Cities & landmarks affected

Bulleted list grouped by zone (inner / middle / outer headings). Only rendered when the volcano has curated `cities` data. When absent, the section is omitted entirely (no "no data" placeholder).

### 5. Aftereffects

A 2–3 paragraph prose block.

For curated volcanoes: uses an authored block (string or i18n key in the override entry).

For the rest: assembled from `ERUPTION_AFTEREFFECTS_BY_TIER[vei]` plus conditional clauses appended by trait:
- `type === 'Caldera'` and `lat` between -30 and 30 → tsunami clause
- `type` includes `'Stratovolcano'` and `elevation > 3000` → lahar clause
- `vei >= 6` → climate clause (sulfate aerosols, 1–3 years global cooling)
- `vei >= 5` → aviation clause (transcontinental disruption)

### 6. Footer disclaimer

Small italic: "Hazard zones are illustrative estimates derived from VEI scaling and historical analogues. Real eruptions vary widely from these models."

## i18n keys

All EN + RO. Curated city names are not translated.

- `panel.simulateButton`, `panel.resetButton`, `panel.eruptionBanner`
- `panel.zoneInner`, `panel.zoneMiddle`, `panel.zoneOuter`
- `panel.zoneRadius`, `panel.zoneArea`
- `panel.populationAtRisk`, `panel.citiesAffected`, `panel.aftereffects`
- `panel.footerDisclaimer`, `panel.populationFootnote`
- `eruption.tier.0` through `eruption.tier.8` — tier labels
- `eruption.aftereffects.tier.0` through `eruption.aftereffects.tier.8` — base templated paragraphs
- `eruption.aftereffects.tsunami`, `eruption.aftereffects.lahar`, `eruption.aftereffects.climate`, `eruption.aftereffects.aviation` — conditional clauses
- `eruption.<volcanoId>.aftereffects` — curated paragraphs for each of the 20 phase-1 volcanoes

If an RO entry is missing, fall back to the EN string for that key (existing pattern in the file). Add a `// TODO: RO translation` comment for any stub RO entries authored as fallbacks.

## Edge cases & invariants

- **New volcano selected during a sim** — lock-on path calls `clearEruptionZones()` before `renderPanel`. Single-instance invariant.
- **Search filter hides the active volcano's cone** — `obj.visible = false` on the cone is independent of the eruption group; zones stay visible. Acceptable behavior.
- **Closing the panel** — `closePanel()` clears zones first.
- **ESC key** — already wired for the legend info card; extend the same handler.
- **Globe rotation** — caps are children of `globe.scene()`, rotate automatically.
- **Polar volcanoes** (e.g. Erebus) — spherical-cap math is pole-safe.
- **Antimeridian** — pure 3D vector math, longitude-wraparound-safe.
- **VEI 8 outer zone** — 1500 km ≈ 13.5° of arc, well under a hemisphere. Renders fine.
- **Inactive volcanoes** — Simulate button gated on `v.status === 'Active'`; never appears for Dormant/Extinct.
- **Rapid clicks on Simulate** — button disabled for the duration of the spawn/animation, re-enabled by Reset.
- **Globe.gl layer instability** — explicitly avoided. We do not touch `ringsData`, `polygonsData`, or `customLayerData`. Zones live in our own group on `globe.scene()`, exactly like `clusterCones`.
- **Memory leak from repeated sims** — `clearEruptionZones()` disposes geometries and materials on every teardown.

## Verification plan

Per the project's "verify before claiming complete" rule:

1. `node --check` on the file post-edit, confirming the script block parses.
2. Headless Edge dump-dom: load the file, confirm stats render (226/163), confirm the panel renders for Vesuvius, confirm `Simulate Eruption` button exists in the DOM after a programmatic selection. (Click-driven mesh insertion can't be verified from dump-dom alone — see #4.)
3. Author Vesuvius and Krakatoa entries first so the user has two clear test cases.
4. **Manual visual check by user** — required, since SwiftShader screenshots fail in this environment per memory. The plan should explicitly flag this as a user step, not a Claude step.
5. Smoke test for memory: sim → reset → repeat 50× via the dev console; verify `globe.scene().children.length` returns to baseline after each Reset.

## Hard constraints (from project memory)

- Single-file, no bundler — all code in the existing `<script>` block.
- CDN deps only (Globe.gl 2.32.4 + Three.js 0.150.0 already loaded).
- Never call `customLayerData(filtered)` — would rebuild all 226 cones.
- Never swap `ringsData` during lock-on — would invalidate other layers.
- Globe radius = 100 Three.js units; eruption math uses `EARTH_RADIUS_KM = 6371` for km↔unit conversion.
- All user-facing strings must go through `t()` / `tFallback()` for EN/RO i18n.

## Open questions

None — all design decisions confirmed in brainstorm.

## Phase 2 (out of scope, noted for later)

- Expand `ERUPTION_OVERRIDES` past 20 volcanoes after user tests phase 1.
- Native-speaker review of RO translations for new eruption strings.
- Eruption video clips on the loading splash (priority queue #5).
- Other planets (priority queue #8).
