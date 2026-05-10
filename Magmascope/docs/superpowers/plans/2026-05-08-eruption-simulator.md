# Eruption Simulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-volcano eruption simulator (Simulate button → animated 3-zone destruction footprint on the globe + damage report panel) for every active volcano in `volcano-globe (7).html`.

**Architecture:** All work in the single existing HTML file. Three concentric spherical-cap meshes are added directly to `globe.scene()` (sidesteps Globe.gl's known layer-swap instability). Radii/populations come from VEI-derived defaults plus 20 curated overrides; the panel re-renders into damage-report mode while a sim is active. Cleanup is wired into close-panel, ESC, and the lock-on path.

**Tech Stack:** Three.js 0.150.0 (already loaded), Globe.gl 2.32.4 (untouched here), vanilla JS, single-file HTML, no build, no test framework.

**Spec:** `docs/superpowers/specs/2026-05-08-eruption-simulator-design.md`

**Project conventions (apply throughout):**
- One file: `C:\Users\Tudor\Desktop\Magmascope\volcano-globe (7).html`
- No git in this repo → no `git commit` steps. Each task ends with a verification step instead.
- Verification toolkit: `node --check` for static parse; `msedge --headless --disable-gpu --virtual-time-budget=10000 --dump-dom <file-url>` for runtime DOM probes; injected JS in dump-dom for object-graph smoke; manual user visual confirmation for anything WebGL-rendered (SwiftShader screenshots fail in this env).
- All user-facing strings go through `t()`/`tFallback()`; add EN+RO entries together.
- Globe radius = 100 Three.js units; `EARTH_RADIUS_KM = 6371`; `kmPerUnit = 63.71`.
- **Hard constraints (do NOT violate):** Do not call `customLayerData(filtered)`; do not touch `ringsData`; do not modify cluster cone management. The eruption group is its own `THREE.Group` added directly to `globe.scene()`.

---

## File Structure

All edits to: `volcano-globe (7).html`

| Insertion zone | Anchor (grep target) | What goes there |
|---|---|---|
| EN i18n dict | `'stats.active': 'Active',` line ~1615 | New `panel.*` and `eruption.*` EN keys |
| RO i18n dict | `'stats.active': 'Active',` line ~1738 (RO copy) | Mirrored RO keys |
| Constants block | `const MONITORING_AGENCIES = {` line ~7171 | New constants placed *immediately above* `MONITORING_AGENCIES`: `EARTH_RADIUS_KM`, `ERUPTION_VEI_RADII`, `ERUPTION_ZONE_STYLES`, `ERUPTION_AFTEREFFECTS_BY_TIER`, `ERUPTION_AFTEREFFECTS_CLAUSES`, `POP_DENSITY_BY_COUNTRY`, `ERUPTION_OVERRIDES`. Module-scoped `let activeEruption = null;` at the same level. |
| Helper functions | After `renderSafetySection` ends, before `function renderPanel(v) {` line ~7389 | `buildSphericalCap`, `areaForCapKm2`, `spawnEruptionAt`, `runEruptionAnimation`, `clearEruptionZones`, `getZoneRadiiFor`, `getPopulationFor`, `getCitiesFor`, `getAftereffectsFor`, `pulseConeFor`, `restoreConeFor` |
| renderPanel | line 7389-7468 | Add `opts={}` param; conditional eruption-mode body; inject Simulate button after `renderSafetySection(v)` for active volcanoes |
| Cleanup hooks | `closePanel` definition, ESC handler, `lockOnVolcano`/equivalent | Insert `clearEruptionZones()` call before existing logic |
| CSS | Top `<style>` block, near existing `.eruption-block` line ~1235 | New rules for `.simulate-button`, `.reset-button`, `.eruption-banner`, `.zone-summary`, `.zone-row`, `.zone-swatch`, `.pop-chips`, `.pop-chip`, `.cities-list`, `.cities-zone-heading`, `.aftereffects-block`, `.footer-disclaimer` |

---

## Task 1: Add eruption constants block

**Files:**
- Modify: `volcano-globe (7).html` (insert above `const MONITORING_AGENCIES = {` near line 7171)

- [ ] **Step 1: Locate the insertion point**

Run: `Grep MONITORING_AGENCIES = volcano-globe (7).html`
Confirm there is exactly one match. Open the file at that line. Insert the new block on the line above the `const MONITORING_AGENCIES = {` line.

- [ ] **Step 2: Insert the constants block**

Insert this code:

```js
// ============================================================================
// ERUPTION SIMULATOR — constants & state
// ============================================================================

const EARTH_RADIUS_KM = 6371;
// Globe radius is 100 Three.js units (existing). 1 unit ≈ 63.71 km.

let activeEruption = null;  // { volcanoId, group, startTime, caps, edges, animFrameId, originalConeEmissive } | null

// VEI -> [innerKm, middleKm, outerKm]. Used when no override is provided.
const ERUPTION_VEI_RADII = {
  0: [0.5,   2.0,    5.0],
  1: [1.0,   4.0,   10.0],
  2: [2.0,   8.0,   25.0],
  3: [4.0,  15.0,   50.0],
  4: [8.0,  30.0,  100.0],
  5: [15.0, 60.0,  200.0],
  6: [25.0, 100.0, 400.0],
  7: [40.0, 180.0, 800.0],
  8: [60.0, 300.0, 1500.0]
};

// Zone visual styles. Inner draws on top — uses largest epsilon offset.
const ERUPTION_ZONE_STYLES = {
  inner:  { color: 0xff5722, opacity: 0.55, epsilon: 0.05 },
  middle: { color: 0xffa726, opacity: 0.40, epsilon: 0.04 },
  outer:  { color: 0xffd54f, opacity: 0.25, epsilon: 0.03 }
};

// Tier label i18n keys. Indexed by VEI 0..8.
const ERUPTION_TIER_KEYS = [
  'eruption.tier.0', 'eruption.tier.1', 'eruption.tier.2',
  'eruption.tier.3', 'eruption.tier.4', 'eruption.tier.5',
  'eruption.tier.6', 'eruption.tier.7', 'eruption.tier.8'
];

// Templated aftereffects paragraph i18n keys, indexed by VEI 0..8.
const ERUPTION_AFTEREFFECTS_TIER_KEYS = [
  'eruption.aftereffects.tier.0', 'eruption.aftereffects.tier.1',
  'eruption.aftereffects.tier.2', 'eruption.aftereffects.tier.3',
  'eruption.aftereffects.tier.4', 'eruption.aftereffects.tier.5',
  'eruption.aftereffects.tier.6', 'eruption.aftereffects.tier.7',
  'eruption.aftereffects.tier.8'
];

// Country-average population density (people / km²).
// Used when override.population is not supplied. Default fallback: 50.
const POP_DENSITY_BY_COUNTRY = {
  'Italy': 200,
  'Indonesia': 150,
  'United States': 36,
  'Iceland': 4,
  'Japan': 340,
  'Antarctica': 0,
  'Russia': 9,
  'Philippines': 370,
  'Ecuador': 70,
  'Mexico': 65,
  'Chile': 26,
  'Peru': 26,
  'New Zealand': 19,
  'Papua New Guinea': 19,
  'Greece': 80,
  'Spain': 95,
  'Costa Rica': 100,
  'Guatemala': 170,
  'Nicaragua': 55,
  'Colombia': 46,
  'Tanzania': 70,
  'Ethiopia': 110,
  'Democratic Republic of the Congo': 40,
  'Cameroon': 56,
  'France': 120,
  'Portugal': 110,
  'Kenya': 95,
  'Vanuatu': 25,
  'Solomon Islands': 25,
  'Romania': 80,
  'Canada': 4,
  'United Kingdom': 280,
  'Argentina': 17,
  'Bolivia': 11,
  'Iran': 50,
  'Turkey': 110,
  'El Salvador': 310,
  'Panama': 55,
  'Saint Vincent and the Grenadines': 280,
  'Saint Lucia': 290,
  'Saint Kitts and Nevis': 200,
  'Comoros': 470,
  'Cape Verde': 130,
  'Eritrea': 35,
  'Tonga': 145,
  'Martinique': 320,
  'Guadeloupe': 240,
  'Réunion': 340,
  '_default': 50
};

// Curated overrides — phase 1, 20 volcanoes. Keys MUST match v.id from VOLCANO_DATA.
// Any field is optional; missing fields fall through to VEI defaults / templated text.
// `aftereffects` is ALWAYS an i18n key (the actual paragraph lives in the EN/RO dictionary).
const ERUPTION_OVERRIDES = {};
// Filled in Task 8.
```

- [ ] **Step 3: Verify static parse**

Run: `node --check "volcano-globe (7).html"`
This will fail (HTML, not JS), so use this Bash check instead:

```bash
node --check <(awk '/<script>/,/<\/script>/' "volcano-globe (7).html" | sed '1d;$d')
```

Expected: no output (= clean parse). If a SyntaxError prints, fix it before continuing.

- [ ] **Step 4: Verify load with headless Edge**

Run: `msedge --headless --disable-gpu --virtual-time-budget=10000 --dump-dom "file:///C:/Users/Tudor/Desktop/Magmascope/volcano-globe%20(7).html" > _probe.html`

Open `_probe.html`; confirm `<span id="statTotal">226</span>` and `<span id="statActive">163</span>` (or the equivalent rendered numbers — baseline still loads). If those are not populated, a runtime error has been introduced — bisect by removing parts of the inserted block.

---

## Task 2: Add EN + RO i18n keys for the simulator

**Files:**
- Modify: `volcano-globe (7).html` EN dict (~lines 1615-1730), RO dict (~lines 1738-1850)

- [ ] **Step 1: Add EN keys to the EN dictionary**

Locate the EN object (the one containing `'stats.active': 'Active',`). Add these entries (any consistent location inside the object is fine — group them at the bottom for readability):

```js
// === Eruption simulator ===
'panel.simulateButton':      'Simulate Eruption',
'panel.resetButton':         'Reset',
'panel.eruptionBannerTitle': 'Hypothetical Eruption',
'panel.eruptionBannerSub':   'Modeled at present-day VEI {vei}',
'panel.zoneInner':           'Pyroclastic',
'panel.zoneMiddle':          'Severe ashfall',
'panel.zoneOuter':           'Light ashfall',
'panel.zoneRadius':          'Radius',
'panel.zoneArea':            'Area',
'panel.populationAtRisk':    'Population at risk',
'panel.populationFootnote':  'Estimated from country-average population density.',
'panel.populationAntarctica':'No permanent population — research stations only.',
'panel.citiesAffected':      'Cities & landmarks affected',
'panel.aftereffects':        'Aftereffects',
'panel.footerDisclaimer':    'Hazard zones are illustrative estimates derived from VEI scaling and historical analogues. Real eruptions vary widely from these models.',

'eruption.tier.0': 'Effusive',
'eruption.tier.1': 'Gentle',
'eruption.tier.2': 'Explosive',
'eruption.tier.3': 'Severe',
'eruption.tier.4': 'Cataclysmic',
'eruption.tier.5': 'Paroxysmal',
'eruption.tier.6': 'Colossal',
'eruption.tier.7': 'Super-colossal',
'eruption.tier.8': 'Mega-colossal',

'eruption.aftereffects.tier.0': 'An effusive eruption produces gentle lava flows close to the vent. Local landscape change is likely, but no significant ashfall or regional disruption is expected.',
'eruption.aftereffects.tier.1': 'A small explosive event can disperse ash within a few kilometres of the vent and produce minor lava flows. Local agriculture, road traffic and small aircraft operations may be briefly disrupted.',
'eruption.aftereffects.tier.2': 'A moderate eruption ejects ash several kilometres into the atmosphere. Nearby communities may experience days of ashfall and air-quality warnings.',
'eruption.aftereffects.tier.3': 'A severe eruption sends ash plumes 5–15 km into the troposphere, blanketing the surrounding region with abrasive ash. Power, water and transportation disruption can extend across hundreds of kilometres.',
'eruption.aftereffects.tier.4': 'A cataclysmic eruption injects ash 10–25 km high, disrupting regional aviation for days and potentially destroying communities within tens of kilometres of the vent.',
'eruption.aftereffects.tier.5': 'A paroxysmal eruption can blanket continents in fine ash and inject sulfur dioxide into the stratosphere, briefly cooling regional climate. Major aviation hubs may close for days to weeks.',
'eruption.aftereffects.tier.6': 'A colossal eruption injects megaton-scale sulfate aerosols into the stratosphere, capable of cooling global temperatures by ~0.3–0.5 °C for one to three years and triggering food-supply shocks across entire hemispheres.',
'eruption.aftereffects.tier.7': 'A super-colossal eruption rivals or exceeds Tambora 1815 — among the largest events of the last 10,000 years. Continental ash fields, year-without-a-summer climate effects and regional famine become realistic outcomes.',
'eruption.aftereffects.tier.8': 'A mega-colossal eruption is a civilisation-scale event. Planetary climate disruption, multi-year volcanic winters and continent-wide ecosystem collapse fall within the envelope of what is possible.',

'eruption.aftereffects.tsunami':  'Tsunami risk: as a coastal caldera, flank collapse or pyroclastic-flow ocean entry could generate ocean-crossing tsunami within hours of the eruption peak.',
'eruption.aftereffects.lahar':    'Lahar risk: a glaciated stratovolcano can liquefy snow and ice into fast-moving mudflows that travel down river valleys far beyond the visible blast radius.',
'eruption.aftereffects.climate':  'Climate impact: sulfate aerosols injected into the stratosphere could measurably cool global temperatures for one to three years.',
'eruption.aftereffects.aviation': 'Aviation disruption: an ash plume of this magnitude could ground transcontinental flights across the affected hemisphere for days to weeks.',
```

(Curated `eruption.<id>.aftereffects` entries are added in Task 8 alongside their override data.)

- [ ] **Step 2: Add RO mirrors to the RO dictionary**

Locate the RO dictionary (the second i18n object containing `'stats.active': 'Activ',` or similar). Add the same keys with Romanian translations:

```js
// === Eruption simulator ===
'panel.simulateButton':      'Simulează Erupția',
'panel.resetButton':         'Resetează',
'panel.eruptionBannerTitle': 'Erupție Ipotetică',
'panel.eruptionBannerSub':   'Modelată la VEI {vei} curent',
'panel.zoneInner':           'Piroclastic',
'panel.zoneMiddle':          'Cenușă severă',
'panel.zoneOuter':           'Cenușă ușoară',
'panel.zoneRadius':          'Rază',
'panel.zoneArea':            'Suprafață',
'panel.populationAtRisk':    'Populație în risc',
'panel.populationFootnote':  'Estimat din densitatea medie a populației pe țară.',
'panel.populationAntarctica':'Fără populație permanentă — doar stații de cercetare.',
'panel.citiesAffected':      'Orașe și repere afectate',
'panel.aftereffects':        'Consecințe',
'panel.footerDisclaimer':    'Zonele de pericol sunt estimări ilustrative derivate din scalarea VEI și analogii istorice. Erupțiile reale variază considerabil față de aceste modele.',

'eruption.tier.0': 'Efuzivă',
'eruption.tier.1': 'Lină',
'eruption.tier.2': 'Explozivă',
'eruption.tier.3': 'Severă',
'eruption.tier.4': 'Cataclismică',
'eruption.tier.5': 'Paroxistică',
'eruption.tier.6': 'Colosală',
'eruption.tier.7': 'Super-colosală',
'eruption.tier.8': 'Mega-colosală',

'eruption.aftereffects.tier.0': 'O erupție efuzivă produce curgeri lente de lavă în apropierea craterului. Modificări locale ale peisajului sunt probabile, dar nu se așteaptă cădere semnificativă de cenușă sau perturbări regionale.',
'eruption.aftereffects.tier.1': 'Un eveniment exploziv mic poate dispersa cenușă pe câțiva kilometri și produce curgeri minore de lavă. Agricultura locală, traficul rutier și operațiunile cu aeronave mici pot fi temporar perturbate.',
'eruption.aftereffects.tier.2': 'O erupție moderată ejectează cenușă la câțiva kilometri în atmosferă. Comunitățile din apropiere pot experimenta zile de cenușă căzând și avertizări de calitate a aerului.',
'eruption.aftereffects.tier.3': 'O erupție severă trimite coloane de cenușă la 5–15 km în troposferă, acoperind regiunea cu cenușă abrazivă. Perturbările alimentării cu energie, apă și transport se pot extinde pe sute de kilometri.',
'eruption.aftereffects.tier.4': 'O erupție cataclismică injectează cenușă la 10–25 km altitudine, perturbând aviația regională timp de zile și putând distruge comunități la zeci de kilometri de crater.',
'eruption.aftereffects.tier.5': 'O erupție paroxistică poate acoperi continente cu cenușă fină și injecta dioxid de sulf în stratosferă, răcind temporar clima regională. Hub-urile majore de aviație pot fi închise zile sau săptămâni.',
'eruption.aftereffects.tier.6': 'O erupție colosală injectează aerosoli sulfați la scară de megatone în stratosferă, capabili să răcească temperaturile globale cu ~0,3–0,5 °C timp de unu până la trei ani și să declanșeze șocuri în lanțul alimentar pe emisfere întregi.',
'eruption.aftereffects.tier.7': 'O erupție super-colosală rivalizează sau depășește Tambora 1815 — printre cele mai mari evenimente din ultimii 10.000 de ani. Câmpuri continentale de cenușă, efecte climatice de tip „an fără vară" și foamete regională devin rezultate realiste.',
'eruption.aftereffects.tier.8': 'O erupție mega-colosală este un eveniment la scară civilizațională. Perturbări climatice planetare, ierni vulcanice de mai mulți ani și colaps ecosistemic la nivel continental sunt în plaja posibilului.',

'eruption.aftereffects.tsunami':  'Risc de tsunami: ca o caldeiră de coastă, colapsul flancului sau intrarea curgerilor piroclastice în ocean poate genera tsunami transoceanic în ore.',
'eruption.aftereffects.lahar':    'Risc de lahar: un stratovulcan glaciat poate lichefia zăpada și gheața în curgeri rapide de noroi care călătoresc pe văile râurilor mult dincolo de raza vizibilă a exploziei.',
'eruption.aftereffects.climate':  'Impact climatic: aerosolii sulfați injectați în stratosferă ar putea răci măsurabil temperaturile globale timp de unu până la trei ani.',
'eruption.aftereffects.aviation': 'Perturbarea aviației: un panaș de cenușă de această magnitudine ar putea opri zborurile transcontinentale pe emisfera afectată zile sau săptămâni.',
```

- [ ] **Step 3: Verify parse**

Run the `node --check` extraction from Task 1 Step 3. Expected: no output.

- [ ] **Step 4: Verify dictionary lookups**

In your browser dev console, after loading the file:

```js
t('panel.simulateButton')   // → 'Simulate Eruption'
t('eruption.tier.5')         // → 'Paroxysmal'
setLanguage('ro');
t('panel.simulateButton')   // → 'Simulează Erupția'
setLanguage('en');
```

(If the language toggle helper has a different name in this codebase, find it via `Grep currentLang volcano-globe (7).html` and use the same approach the lang switcher buttons use.)

---

## Task 3: Implement spherical-cap geometry helpers

**Files:**
- Modify: `volcano-globe (7).html` (insert after `renderSafetySection` ends, before `function renderPanel(v) {` near line 7389)

- [ ] **Step 1: Insert the geometry helpers**

```js
// ============================================================================
// ERUPTION SIMULATOR — geometry helpers
// ============================================================================

/**
 * Build a tessellated spherical cap mesh that sits ε above the globe surface,
 * centered on (latDeg, lngDeg) with the given angular radius (radians).
 *
 * Returns { mesh: THREE.Mesh, edge: THREE.LineLoop } — both already positioned
 * and oriented for adding to the scene.
 *
 * angularRadiusRad = radiusKm / EARTH_RADIUS_KM
 * Cap radius is in Three.js units; pole is placed at (sphereRadius + epsilon).
 */
function buildSphericalCap(latDeg, lngDeg, angularRadiusRad, opts = {}) {
  const segments    = opts.segments    || 64;
  const sphereR     = opts.sphereRadius || 100;
  const epsilon     = opts.epsilon     || 0.03;
  const color       = opts.color       || 0xff5722;
  const opacity     = opts.opacity     || 0.4;

  const r = sphereR + epsilon;
  const theta = Math.max(angularRadiusRad, 1e-6);

  // --- Cap mesh (filled disc on sphere surface) ---------------------------
  // Build vertices in a "north-pole" frame: pole at +Y, cap rim at angle θ from it.
  // Then orient the whole thing so the pole points to (latDeg, lngDeg).
  const positions = new Float32Array((segments + 2) * 3);
  positions[0] = 0;
  positions[1] = r;
  positions[2] = 0;
  for (let i = 0; i <= segments; i++) {
    const phi = (i / segments) * Math.PI * 2;
    // Spherical to Cartesian: rim at polar angle θ from the +Y pole.
    const sinTheta = Math.sin(theta);
    const cosTheta = Math.cos(theta);
    const x = r * sinTheta * Math.cos(phi);
    const y = r * cosTheta;
    const z = r * sinTheta * Math.sin(phi);
    positions[(i + 1) * 3 + 0] = x;
    positions[(i + 1) * 3 + 1] = y;
    positions[(i + 1) * 3 + 2] = z;
  }

  const indices = [];
  for (let i = 1; i <= segments; i++) {
    indices.push(0, i, i + 1);
  }

  const capGeo = new THREE.BufferGeometry();
  capGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  capGeo.setIndex(indices);
  capGeo.computeVertexNormals();

  const capMat = new THREE.MeshBasicMaterial({
    color, opacity,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
    blending: THREE.NormalBlending
  });
  const mesh = new THREE.Mesh(capGeo, capMat);

  // --- Edge ring (great-circle line at the cap rim) -----------------------
  const edgePositions = new Float32Array(segments * 3);
  for (let i = 0; i < segments; i++) {
    const phi = (i / segments) * Math.PI * 2;
    const sinTheta = Math.sin(theta);
    const cosTheta = Math.cos(theta);
    edgePositions[i * 3 + 0] = r * sinTheta * Math.cos(phi);
    edgePositions[i * 3 + 1] = r * cosTheta;
    edgePositions[i * 3 + 2] = r * sinTheta * Math.sin(phi);
  }
  const edgeGeo = new THREE.BufferGeometry();
  edgeGeo.setAttribute('position', new THREE.BufferAttribute(edgePositions, 3));
  const edgeMat = new THREE.LineBasicMaterial({ color, transparent: true, opacity: 1.0 });
  const edge = new THREE.LineLoop(edgeGeo, edgeMat);

  // --- Orient the cap so its pole points to (latDeg, lngDeg) --------------
  // Globe.gl's lat/lng convention (0,0 → +X, +Y = north pole) means we rotate
  // a +Y-pole local frame onto the target lat/lng vector.
  const phi   = (90 - latDeg) * Math.PI / 180;   // colatitude from +Y
  const lambda = lngDeg          * Math.PI / 180;
  const target = new THREE.Vector3(
    Math.sin(phi) * Math.cos(lambda),
    Math.cos(phi),
    Math.sin(phi) * Math.sin(lambda)
  );
  const yAxis = new THREE.Vector3(0, 1, 0);
  const quat = new THREE.Quaternion().setFromUnitVectors(yAxis, target);
  mesh.quaternion.copy(quat);
  edge.quaternion.copy(quat);

  return { mesh, edge };
}

/**
 * Surface area of a spherical cap of angular radius θ (radians) on Earth.
 * area = 2π · R² · (1 − cos θ).  Returns km².
 */
function areaForCapKm2(angularRadiusRad) {
  const R = EARTH_RADIUS_KM;
  return 2 * Math.PI * R * R * (1 - Math.cos(angularRadiusRad));
}
```

- [ ] **Step 2: Verify static parse**

Run the extraction `node --check` from Task 1.
Expected: no output.

- [ ] **Step 3: Smoke-test in the dev console**

Open the file in a browser. In the console:

```js
const cap = buildSphericalCap(40.821, 14.426, 30 / EARTH_RADIUS_KM);
globe.scene().add(cap.mesh);
globe.scene().add(cap.edge);
```

Expected: an orange disc appears centered on Vesuvius (Naples). Run `globe.scene().remove(cap.mesh); globe.scene().remove(cap.edge);` to clear.

```js
areaForCapKm2(30 / EARTH_RADIUS_KM).toFixed(0)
// Expected: ≈ "2827" (matches π · 30² for small θ)
```

If the disc appears in the wrong location (e.g. the equator-meridian intersection), the orientation math is wrong — re-check the lat/lng → vector formula in step 1.

---

## Task 4: Implement spawn / animate / clear

**Files:**
- Modify: `volcano-globe (7).html` (immediately after the geometry helpers added in Task 3)

- [ ] **Step 1: Insert the runtime functions**

```js
// ============================================================================
// ERUPTION SIMULATOR — spawn / animate / clear
// ============================================================================

/**
 * Returns { innerKm, middleKm, outerKm } for a volcano,
 * preferring an override entry, falling back to ERUPTION_VEI_RADII[v.vei].
 */
function getZoneRadiiFor(v) {
  const o = ERUPTION_OVERRIDES[v.id];
  if (o && o.zones) return { ...o.zones };
  const tier = ERUPTION_VEI_RADII[v.vei] || ERUPTION_VEI_RADII[3];
  return { innerKm: tier[0], middleKm: tier[1], outerKm: tier[2] };
}

/**
 * Returns { inner, middle, outer } population estimates. Prefers override,
 * falls back to country-density × cap area.
 */
function getPopulationFor(v) {
  const o = ERUPTION_OVERRIDES[v.id];
  if (o && o.population) return { ...o.population };
  const { innerKm, middleKm, outerKm } = getZoneRadiiFor(v);
  const density = (POP_DENSITY_BY_COUNTRY[v.country] !== undefined)
    ? POP_DENSITY_BY_COUNTRY[v.country]
    : POP_DENSITY_BY_COUNTRY._default;
  const areaInner  = Math.PI * innerKm  * innerKm;
  const areaMiddle = Math.PI * middleKm * middleKm - areaInner;
  const areaOuter  = Math.PI * outerKm  * outerKm  - Math.PI * middleKm * middleKm;
  return {
    inner:  Math.round(density * areaInner),
    middle: Math.round(density * areaMiddle),
    outer:  Math.round(density * areaOuter)
  };
}

function getCitiesFor(v) {
  const o = ERUPTION_OVERRIDES[v.id];
  return (o && o.cities) ? o.cities : null;  // null = section omitted
}

/**
 * Returns the aftereffects HTML (already i18n-resolved) for a volcano.
 * Curated overrides return a single curated paragraph; otherwise base tier
 * paragraph + conditional clauses concatenated.
 */
function getAftereffectsFor(v) {
  const o = ERUPTION_OVERRIDES[v.id];
  if (o && o.aftereffects) return `<p>${t(o.aftereffects)}</p>`;

  const parts = [];
  parts.push(t(ERUPTION_AFTEREFFECTS_TIER_KEYS[v.vei] || ERUPTION_AFTEREFFECTS_TIER_KEYS[3]));

  if (v.type === 'Caldera' && v.lat >= -30 && v.lat <= 30) {
    parts.push(t('eruption.aftereffects.tsunami'));
  }
  if ((v.type || '').includes('Stratovolcano') && v.elevation > 3000) {
    parts.push(t('eruption.aftereffects.lahar'));
  }
  if (v.vei >= 6) {
    parts.push(t('eruption.aftereffects.climate'));
  }
  if (v.vei >= 5) {
    parts.push(t('eruption.aftereffects.aviation'));
  }
  return parts.map(p => `<p>${p}</p>`).join('');
}

/**
 * Find the existing cluster cone for a volcano. Returns the THREE.Mesh or null.
 */
function findConeFor(volcanoId) {
  if (!Array.isArray(clusterCones)) return null;
  return clusterCones.find(c => c.userData && c.userData.volcanoId === volcanoId) || null;
}

function pulseConeFor(volcanoId) {
  const cone = findConeFor(volcanoId);
  if (!cone || !cone.material) return null;
  const m = cone.material;
  // Save original emissive (or 0x000000 if material has no emissive).
  const originalEmissive = (m.emissive && m.emissive.clone) ? m.emissive.clone() : null;
  if (m.emissive && m.emissive.set) {
    m.emissive.set(0xff5722);
    m.needsUpdate = true;
  }
  return originalEmissive;
}

function restoreConeFor(volcanoId, originalEmissive) {
  const cone = findConeFor(volcanoId);
  if (!cone || !cone.material) return;
  if (originalEmissive && cone.material.emissive && cone.material.emissive.copy) {
    cone.material.emissive.copy(originalEmissive);
    cone.material.needsUpdate = true;
  }
}

/**
 * Spawn a 3-zone eruption for a volcano. Idempotent: clears any prior sim first.
 * Mutates module-level activeEruption.
 */
function spawnEruptionAt(v) {
  clearEruptionZones();

  const { innerKm, middleKm, outerKm } = getZoneRadiiFor(v);
  const targets = [
    { name: 'inner',  km: innerKm,  style: ERUPTION_ZONE_STYLES.inner  },
    { name: 'middle', km: middleKm, style: ERUPTION_ZONE_STYLES.middle },
    { name: 'outer',  km: outerKm,  style: ERUPTION_ZONE_STYLES.outer }
  ];

  const group = new THREE.Group();
  group.userData = { _isEruptionZones: true, volcanoId: v.id };

  const caps = [];
  // Build each cap initially at radius 0 (animation will grow them).
  for (const z of targets) {
    const built = buildSphericalCap(v.lat, v.lng, 1e-6, {
      color:   z.style.color,
      opacity: z.style.opacity,
      epsilon: z.style.epsilon
    });
    group.add(built.mesh);
    group.add(built.edge);
    caps.push({
      name: z.name,
      mesh: built.mesh,
      edge: built.edge,
      targetRad: z.km / EARTH_RADIUS_KM,
      style: z.style,
      lat: v.lat,
      lng: v.lng
    });
  }

  globe.scene().add(group);

  const originalConeEmissive = pulseConeFor(v.id);

  activeEruption = {
    volcanoId: v.id,
    group,
    caps,
    startTime: performance.now(),
    animFrameId: null,
    originalConeEmissive
  };

  runEruptionAnimation();
}

/**
 * RAF loop. Updates each cap's geometry to its eased current radius until
 * t >= 1, then stops scheduling further frames.
 */
function runEruptionAnimation() {
  if (!activeEruption) return;
  const DURATION = 1800;
  const PULSE_DURATION = 1000;

  const tick = (now) => {
    if (!activeEruption) return;
    const elapsed = now - activeEruption.startTime;
    const t = Math.min(1, elapsed / DURATION);

    activeEruption.caps.forEach((cap, i) => {
      const delay = i * 0.15;
      const localT = Math.max(0, Math.min(1, (t - delay) / (1 - delay)));
      const eased = 1 - Math.pow(1 - localT, 3);
      const angularRad = Math.max(1e-6, cap.targetRad * eased);
      // Rebuild geometry in place — cheap (~64 verts).
      const rebuilt = buildSphericalCap(cap.lat, cap.lng, angularRad, {
        color:   cap.style.color,
        opacity: cap.style.opacity,
        epsilon: cap.style.epsilon
      });
      cap.mesh.geometry.dispose();
      cap.mesh.geometry = rebuilt.mesh.geometry;
      cap.edge.geometry.dispose();
      cap.edge.geometry = rebuilt.edge.geometry;
      // Throw away the wrapper meshes' materials we don't reuse.
      rebuilt.mesh.material.dispose();
      rebuilt.edge.material.dispose();
    });

    // Cone pulse: restore once the pulse window ends.
    if (elapsed >= PULSE_DURATION && activeEruption.originalConeEmissive !== undefined) {
      restoreConeFor(activeEruption.volcanoId, activeEruption.originalConeEmissive);
      activeEruption.originalConeEmissive = undefined;  // mark restored
    }

    if (t < 1) {
      activeEruption.animFrameId = requestAnimationFrame(tick);
    } else {
      activeEruption.animFrameId = null;
    }
  };

  activeEruption.animFrameId = requestAnimationFrame(tick);
}

/**
 * Tear down any active eruption sim. Safe to call when none is active.
 */
function clearEruptionZones() {
  if (!activeEruption) return;

  if (activeEruption.animFrameId !== null) {
    cancelAnimationFrame(activeEruption.animFrameId);
  }

  // Restore cone emissive if pulse was still in progress.
  if (activeEruption.originalConeEmissive !== undefined) {
    restoreConeFor(activeEruption.volcanoId, activeEruption.originalConeEmissive);
  }

  globe.scene().remove(activeEruption.group);
  activeEruption.group.traverse(obj => {
    if (obj.geometry) obj.geometry.dispose();
    if (obj.material) {
      if (Array.isArray(obj.material)) obj.material.forEach(m => m.dispose());
      else obj.material.dispose();
    }
  });

  activeEruption = null;
}
```

- [ ] **Step 2: Verify static parse**

Run extraction `node --check`. Expected: no output.

- [ ] **Step 3: Smoke-test spawn/clear in the dev console**

```js
const v = VOLCANO_DATA.find(x => x.id === 'vesuvius');
const beforeChildren = globe.scene().children.length;
spawnEruptionAt(v);
// Wait ~2s for animation to settle, then:
console.log(globe.scene().children.length - beforeChildren);  // → 1 (the eruption group)
console.log(activeEruption.caps.map(c => c.name));            // → ['inner', 'middle', 'outer']

clearEruptionZones();
console.log(globe.scene().children.length - beforeChildren);  // → 0
console.log(activeEruption);                                  // → null
```

Expected: each line prints the indicated value. If the post-clear scene child count is non-zero, there's a leak — re-check `clearEruptionZones`.

- [ ] **Step 4: Smoke-test repeated spawn (idempotency)**

```js
for (let i = 0; i < 10; i++) spawnEruptionAt(v);
// activeEruption should refer to the LAST sim, not 10 stacked groups.
console.log(globe.scene().children.length - beforeChildren);  // → 1
clearEruptionZones();
```

Expected: 1, then 0 after clear. If > 1, `spawnEruptionAt` is not calling `clearEruptionZones` first.

---

## Task 5: Add CSS for the new panel sections

**Files:**
- Modify: `volcano-globe (7).html` `<style>` block (insert near the existing `.eruption-block` rules around line 1235)

- [ ] **Step 1: Insert CSS rules**

Find the existing `.eruption-block` rule and add the following AFTER it:

```css
/* === Eruption simulator — Simulate / Reset buttons === */
.simulate-button {
  display: block;
  width: 100%;
  margin-top: 16px;
  padding: 12px 20px;
  border: 1px solid rgba(255, 87, 34, 0.6);
  border-radius: 6px;
  background: linear-gradient(135deg, rgba(255, 87, 34, 0.20), rgba(255, 87, 34, 0.08));
  color: #ff7a4d;
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
  transition: background 160ms ease, border-color 160ms ease, color 160ms ease;
}
.simulate-button:hover {
  background: linear-gradient(135deg, rgba(255, 87, 34, 0.32), rgba(255, 87, 34, 0.16));
  border-color: rgba(255, 87, 34, 0.9);
  color: #ffaa88;
}
.simulate-button:disabled {
  opacity: 0.5;
  cursor: progress;
}

.reset-button {
  padding: 6px 12px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 4px;
  background: rgba(0, 0, 0, 0.25);
  color: #cfd6dc;
  font-family: inherit;
  font-size: 11px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  cursor: pointer;
  transition: background 160ms ease, border-color 160ms ease;
}
.reset-button:hover {
  background: rgba(0, 0, 0, 0.45);
  border-color: rgba(255, 255, 255, 0.5);
}

/* === Eruption banner === */
.eruption-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 0 0 16px 0;
  padding: 14px 18px;
  border: 1px solid rgba(255, 87, 34, 0.6);
  border-radius: 6px;
  background: linear-gradient(135deg, rgba(255, 87, 34, 0.32), rgba(255, 167, 38, 0.18));
}
.eruption-banner-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.eruption-banner-title {
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 0.06em;
  color: #ffd2bc;
}
.eruption-banner-sub {
  font-size: 11px;
  color: rgba(255, 210, 188, 0.7);
  letter-spacing: 0.04em;
}

/* === Zone summary table === */
.zone-summary {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 6px 14px;
  align-items: center;
  margin: 12px 0;
  padding: 10px 14px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.04);
  font-size: 12px;
}
.zone-summary-header {
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 10px;
  color: rgba(255, 255, 255, 0.4);
  font-weight: 600;
}
.zone-row {
  display: contents;
}
.zone-row-name { display: flex; align-items: center; gap: 8px; color: #e6ebf0; }
.zone-row-radius { color: #b6bec6; text-align: right; font-variant-numeric: tabular-nums; }
.zone-row-area   { color: #b6bec6; text-align: right; font-variant-numeric: tabular-nums; }

.zone-swatch {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.zone-swatch-inner  { background: #ff5722; box-shadow: 0 0 6px rgba(255, 87, 34, 0.6); }
.zone-swatch-middle { background: #ffa726; }
.zone-swatch-outer  { background: #ffd54f; }

/* === Population chips === */
.pop-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 8px 0 4px 0;
}
.pop-chip {
  padding: 5px 10px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.12);
  font-size: 11px;
  color: #d6dde4;
  font-variant-numeric: tabular-nums;
}
.pop-chip strong { color: #ffd2bc; font-weight: 600; }
.pop-footnote {
  margin-top: 6px;
  font-size: 10px;
  color: rgba(255, 255, 255, 0.45);
  font-style: italic;
}

/* === Cities list === */
.cities-list {
  margin: 0;
  padding: 0;
  list-style: none;
}
.cities-zone-heading {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgba(255, 255, 255, 0.5);
  margin: 8px 0 4px 0;
}
.cities-list li {
  margin: 0 0 3px 0;
  padding-left: 16px;
  position: relative;
  font-size: 12px;
  color: #d6dde4;
}
.cities-list li::before {
  content: '·';
  position: absolute;
  left: 4px;
  color: rgba(255, 255, 255, 0.4);
}

/* === Aftereffects block === */
.aftereffects-block p {
  margin: 0 0 10px 0;
  font-size: 13px;
  line-height: 1.55;
  color: #cfd6dc;
}
.aftereffects-block p:last-child { margin-bottom: 0; }

/* === Footer disclaimer === */
.footer-disclaimer {
  margin-top: 16px;
  padding-top: 10px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  font-size: 10px;
  font-style: italic;
  color: rgba(255, 255, 255, 0.4);
  line-height: 1.5;
}
```

- [ ] **Step 2: Verify the file still loads**

Reload the file in the browser. Confirm the existing layout still renders correctly (open Vesuvius's panel; the existing layout should look unchanged).

---

## Task 6: Wire Simulate button + eruption-mode body into renderPanel

**Files:**
- Modify: `volcano-globe (7).html` `renderPanel` (lines ~7389-7468)

- [ ] **Step 1: Add a renderer for the eruption-mode body**

Insert this helper *immediately above* the `function renderPanel(v) {` line:

```js
/**
 * Build the HTML for the eruption damage report. Used by renderPanel when
 * called with mode === 'eruption'.
 */
function renderEruptionModeBody(v) {
  const { innerKm, middleKm, outerKm } = getZoneRadiiFor(v);
  const angInner  = innerKm  / EARTH_RADIUS_KM;
  const angMiddle = middleKm / EARTH_RADIUS_KM;
  const angOuter  = outerKm  / EARTH_RADIUS_KM;
  const aInner    = areaForCapKm2(angInner);
  const aMiddle   = areaForCapKm2(angMiddle);
  const aOuter    = areaForCapKm2(angOuter);

  const fmtKm = n => n >= 100 ? n.toLocaleString(undefined, {maximumFractionDigits: 0}) :
                     n >= 10  ? n.toFixed(0) :
                                n.toFixed(1);
  const fmtArea = n => n.toLocaleString(undefined, {maximumFractionDigits: 0});
  const fmtPop = n => {
    if (n >= 1_000_000) return (n / 1_000_000).toFixed(n >= 10_000_000 ? 0 : 1) + 'M';
    if (n >= 1_000)     return (n / 1_000).toFixed(n >= 100_000 ? 0 : 1) + 'K';
    return n.toLocaleString();
  };

  const tier = t(ERUPTION_TIER_KEYS[v.vei] || ERUPTION_TIER_KEYS[3]);
  const banner = `
    <div class="eruption-banner">
      <div class="eruption-banner-text">
        <span class="eruption-banner-title">${tier} · ${t('panel.eruptionBannerTitle')}</span>
        <span class="eruption-banner-sub">${t('panel.eruptionBannerSub').replace('{vei}', String(v.vei))}</span>
      </div>
      <button class="reset-button" id="resetEruption">${t('panel.resetButton')}</button>
    </div>
  `;

  const zoneTable = `
    <div class="panel-section">
      <div class="zone-summary">
        <div class="zone-summary-header">${t('panel.zoneInner')}</div>
        <div class="zone-summary-header" style="text-align:right">${t('panel.zoneRadius')}</div>
        <div class="zone-summary-header" style="text-align:right">${t('panel.zoneArea')}</div>

        <div class="zone-row-name"><span class="zone-swatch zone-swatch-inner"></span>${t('panel.zoneInner')}</div>
        <div class="zone-row-radius">${fmtKm(innerKm)} km</div>
        <div class="zone-row-area">${fmtArea(aInner)} km²</div>

        <div class="zone-row-name"><span class="zone-swatch zone-swatch-middle"></span>${t('panel.zoneMiddle')}</div>
        <div class="zone-row-radius">${fmtKm(middleKm)} km</div>
        <div class="zone-row-area">${fmtArea(aMiddle)} km²</div>

        <div class="zone-row-name"><span class="zone-swatch zone-swatch-outer"></span>${t('panel.zoneOuter')}</div>
        <div class="zone-row-radius">${fmtKm(outerKm)} km</div>
        <div class="zone-row-area">${fmtArea(aOuter)} km²</div>
      </div>
    </div>
  `;

  const pop = getPopulationFor(v);
  const isAntarctica = v.country === 'Antarctica';
  const popFootnote = isAntarctica
    ? `<div class="pop-footnote">${t('panel.populationAntarctica')}</div>`
    : (ERUPTION_OVERRIDES[v.id] && ERUPTION_OVERRIDES[v.id].population)
      ? ''
      : `<div class="pop-footnote">${t('panel.populationFootnote')}</div>`;
  const popBlock = `
    <div class="panel-section">
      <div class="description-eyebrow">${t('panel.populationAtRisk')}</div>
      <div class="pop-chips">
        <span class="pop-chip"><strong>${t('panel.zoneInner')}:</strong> ${fmtPop(pop.inner)}</span>
        <span class="pop-chip"><strong>${t('panel.zoneMiddle')}:</strong> ${fmtPop(pop.middle)}</span>
        <span class="pop-chip"><strong>${t('panel.zoneOuter')}:</strong> ${fmtPop(pop.outer)}</span>
      </div>
      ${popFootnote}
    </div>
  `;

  const cities = getCitiesFor(v);
  const citiesBlock = cities ? `
    <div class="panel-section">
      <div class="description-eyebrow">${t('panel.citiesAffected')}</div>
      ${cities.inner && cities.inner.length ? `
        <div class="cities-zone-heading">${t('panel.zoneInner')}</div>
        <ul class="cities-list">${cities.inner.map(c => `<li>${c}</li>`).join('')}</ul>
      ` : ''}
      ${cities.middle && cities.middle.length ? `
        <div class="cities-zone-heading">${t('panel.zoneMiddle')}</div>
        <ul class="cities-list">${cities.middle.map(c => `<li>${c}</li>`).join('')}</ul>
      ` : ''}
      ${cities.outer && cities.outer.length ? `
        <div class="cities-zone-heading">${t('panel.zoneOuter')}</div>
        <ul class="cities-list">${cities.outer.map(c => `<li>${c}</li>`).join('')}</ul>
      ` : ''}
    </div>
  ` : '';

  const aftereffectsBlock = `
    <div class="panel-section">
      <div class="description-eyebrow">${t('panel.aftereffects')}</div>
      <div class="aftereffects-block">${getAftereffectsFor(v)}</div>
    </div>
  `;

  const footer = `
    <div class="panel-section">
      <div class="footer-disclaimer">${t('panel.footerDisclaimer')}</div>
    </div>
  `;

  return banner + zoneTable + popBlock + citiesBlock + aftereffectsBlock + footer;
}
```

- [ ] **Step 2: Refactor `renderPanel` to accept `opts` and branch on mode**

Replace the `renderPanel` function (lines ~7389-7468) with:

```js
/**
 * Renders the info panel. Every volcano gets a hero backdrop image
 * (lazy-loaded from Wikipedia); notable volcanoes additionally get
 * the rich historical description block.
 *
 * opts.mode: 'eruption' renders the post-eruption damage report instead
 * of the standard description body.
 */
function renderPanel(v, opts = {}) {
  const panel = document.getElementById('infoPanel');
  const inner = document.getElementById('panelInner');

  const fmtLat = `${Math.abs(v.lat).toFixed(3)}° ${v.lat >= 0 ? 'N' : 'S'}`;
  const fmtLng = `${Math.abs(v.lng).toFixed(3)}° ${v.lng >= 0 ? 'E' : 'W'}`;

  const isEruption = opts.mode === 'eruption';

  const descriptionHTML = (!isEruption && v.notable && v.description)
    ? `
      <div class="panel-section description-block">
        <div class="description-eyebrow">Historical Significance</div>
        ${v.description.map(p => `<p class="description-text">${p}</p>`).join('')}
      </div>
    `
    : '';

  const simulateButtonHTML = (!isEruption && v.status === 'Active')
    ? `<button class="simulate-button" id="simulateBtn">${t('panel.simulateButton')}</button>`
    : '';

  const standardBody = isEruption ? '' : `
    <div class="panel-section eruption-block">
      <div class="eruption-label">${t('panel.lastEruption')}</div>
      <div class="eruption-value">${v.lastEruption}</div>
    </div>

    <div class="panel-section data-grid">
      <div class="data-cell">
        <div class="data-label">${t('panel.latitude')}</div>
        <div class="data-value">${fmtLat}</div>
      </div>
      <div class="data-cell">
        <div class="data-label">${t('panel.longitude')}</div>
        <div class="data-value">${fmtLng}</div>
      </div>
      <div class="data-cell">
        <div class="data-label">${t('panel.elevation')}</div>
        <div class="data-value">${v.elevation.toLocaleString()} m</div>
      </div>
      <div class="data-cell">
        <div class="data-label">${t('panel.vei')}</div>
        <div class="data-value data-value-accent">${v.vei} / 8</div>
      </div>
    </div>

    ${renderSafetySection(v)}

    ${simulateButtonHTML}

    ${descriptionHTML}
  `;

  const eruptionBody = isEruption ? renderEruptionModeBody(v) : '';

  inner.innerHTML = `
    <div class="panel-hero" id="panelHero">
      <img class="panel-hero-img" id="panelHeroImg" alt="" />
      <span class="panel-hero-credit" id="panelHeroCredit">${t('panel.photoCredit')}</span>
    </div>

    <div class="panel-header">
      <span class="panel-tag">${t('panel.record')} · ${v.id.toUpperCase()}</span>
      <button class="close-btn" id="closePanel" aria-label="Close panel">×</button>
    </div>

    <div class="panel-section">
      <h2 class="volcano-name">${v.name}</h2>
      <div class="volcano-location">${v.region} · ${tFallback('country', v.country)}</div>
      <div class="status-row">
        <span class="chip chip-active">${tFallback('status', v.status)}</span>
        <span class="chip">${tFallback('type', v.type)}</span>
        ${v.notable ? `<span class="chip chip-notable">${t('panel.historic')}</span>` : ''}
      </div>
    </div>

    ${standardBody}
    ${eruptionBody}
  `;

  panel.classList.toggle('is-notable', !!v.notable);
  panel.classList.toggle('is-eruption', isEruption);
  panel.classList.add('active');
  panel.setAttribute('aria-hidden', 'false');

  document.getElementById('closePanel').addEventListener('click', closePanel);

  // Wire the Simulate button (standard mode, active volcanoes only).
  const simBtn = document.getElementById('simulateBtn');
  if (simBtn) {
    simBtn.addEventListener('click', () => {
      simBtn.disabled = true;
      spawnEruptionAt(v);
      renderPanel(v, { mode: 'eruption' });
    });
  }

  // Wire the Reset button (eruption mode).
  const resetBtn = document.getElementById('resetEruption');
  if (resetBtn) {
    resetBtn.addEventListener('click', () => {
      clearEruptionZones();
      renderPanel(v);  // standard mode
    });
  }

  loadHeroImage(v);
}
```

Key differences from the original:
- New `opts = {}` parameter and `isEruption` branch.
- Simulate button is injected after `renderSafetySection(v)` for active volcanoes only.
- When in eruption mode: standard body (last eruption / data grid / safety / description) is replaced by `renderEruptionModeBody(v)`.
- New `is-eruption` class on the panel for any future CSS targeting.
- Click handlers for both Simulate and Reset are bound on every render.

- [ ] **Step 3: Verify static parse**

Run extraction `node --check`. Expected: no output.

- [ ] **Step 4: Manual visual verification (USER STEP)**

Reload the file. Click on Vesuvius. Confirm:
- The standard panel renders with all original content intact.
- A new "Simulate Eruption" button appears below the safety section.
- Clicking it: three rings ripple outward over ~1.8s on the globe; the panel re-renders into damage report mode (banner with VEI tier, zone table, population chips, aftereffects paragraphs, disclaimer footer).
- Clicking "Reset" in the banner: zones disappear from the globe; the standard panel returns.
- Selecting a Dormant volcano (e.g. Fuji is Active so try a Dormant one): no Simulate button appears.

If any of those fail, check the browser dev console for JS errors.

---

## Task 7: Wire cleanup hooks (closePanel, ESC, lock-on)

**Files:**
- Modify: `volcano-globe (7).html` — `closePanel`, ESC key handler, volcano-selection / lock-on handler

- [ ] **Step 1: Find the `closePanel` definition**

Run: `Grep "function closePanel" volcano-globe (7).html`
Open the file at the matching line.

- [ ] **Step 2: Insert `clearEruptionZones()` at the start of `closePanel`**

Add a single line at the very top of the function body:

```js
function closePanel() {
  clearEruptionZones();
  // ... existing close logic untouched ...
}
```

If `closePanel` is defined as an arrow function or assigned to a variable, the same principle applies — `clearEruptionZones()` is the first statement.

- [ ] **Step 3: Find the ESC handler**

Run: `Grep "Escape" volcano-globe (7).html` and `Grep "keydown" volcano-globe (7).html`
There should be an existing handler that responds to ESC (currently used for the legend info card and panel close).

- [ ] **Step 4: Add eruption clear to the ESC handler**

In the ESC handler body (`if (e.key === 'Escape')` or equivalent), insert `clearEruptionZones();` before the existing close logic. Note: closing the panel via that handler will also call `closePanel`, which already clears zones — this redundancy is fine.

- [ ] **Step 5: Find the volcano-selection / lock-on path**

Run: `Grep "lockedVolcano\s*=" volcano-globe (7).html`
Locate the function that sets `lockedVolcano` (likely called `lockOnVolcano`, `selectVolcano`, or invoked from a click handler on cones).

- [ ] **Step 6: Insert `clearEruptionZones()` early in the lock-on path**

At the beginning of the volcano-selection function — *before* `renderPanel` is called — add unconditionally:

```js
clearEruptionZones();
```

Rationale: any path that goes through volcano selection (whether to a different volcano or the same one) re-renders the panel in standard mode. If we kept zones from a prior sim while showing the standard panel, the globe and panel would be out of sync (zones visible, but no banner / no Reset button). Always clearing keeps state coherent. To re-trigger a sim on the same volcano, the user clicks Simulate again.

Note: `spawnEruptionAt` (called from the Simulate button) already calls `clearEruptionZones()` first, and re-renders the panel in eruption mode immediately after — so there is no flash of stale standard-mode panel during a normal Simulate click.

- [ ] **Step 7: Verify static parse**

Run extraction `node --check`. Expected: no output.

- [ ] **Step 8: Manual verification (USER STEP)**

Reload. Test each cleanup path:

1. Click Vesuvius → Simulate → panel close button (×). Confirm zones disappear.
2. Click Vesuvius → Simulate → ESC. Confirm zones disappear.
3. Click Vesuvius → Simulate → click Krakatoa. Confirm Vesuvius zones disappear *before* Krakatoa's panel opens.
4. Click Vesuvius → Simulate → click Vesuvius again (same volcano). Confirm zones disappear and the standard panel returns. (To re-run, click Simulate again.)

---

## Task 8: Author 20 curated `ERUPTION_OVERRIDES` entries + EN aftereffects strings

**Files:**
- Modify: `volcano-globe (7).html` — populate `ERUPTION_OVERRIDES` (left as `{}` in Task 1) and append `eruption.<id>.aftereffects` keys to both i18n dicts.

- [ ] **Step 1: Replace the empty `ERUPTION_OVERRIDES = {};` with the curated set**

Replace `const ERUPTION_OVERRIDES = {};` (added in Task 1) with:

```js
const ERUPTION_OVERRIDES = {
  vesuvius: {
    zones: { innerKm: 7, middleKm: 30, outerKm: 100 },
    population: { inner: 700_000, middle: 3_100_000, outer: 6_000_000 },
    cities: {
      inner:  ['Torre del Greco', 'Ercolano', 'Pompei (modern town)'],
      middle: ['Naples', 'Salerno', 'Castellammare di Stabia'],
      outer:  ['Rome', 'Bari', 'Foggia']
    },
    aftereffects: 'eruption.vesuvius.aftereffects'
  },
  krakatoa: {
    zones: { innerKm: 10, middleKm: 50, outerKm: 250 },
    population: { inner: 5_000, middle: 800_000, outer: 25_000_000 },
    cities: {
      inner:  [],
      middle: ['Anyer', 'Carita', 'Kalianda', 'Sertung Island'],
      outer:  ['Jakarta', 'Bandung', 'Bandar Lampung', 'Singapore (ash)']
    },
    aftereffects: 'eruption.krakatoa.aftereffects'
  },
  tambora: {
    zones: { innerKm: 30, middleKm: 150, outerKm: 700 },
    population: { inner: 50_000, middle: 1_500_000, outer: 60_000_000 },
    cities: {
      inner:  ['Pekat', 'Sanggar (former settlements)'],
      middle: ['Bima', 'Mataram', 'Sumbawa Besar'],
      outer:  ['Bali (Denpasar)', 'Lombok', 'Surabaya']
    },
    aftereffects: 'eruption.tambora.aftereffects'
  },
  'st-helens': {
    zones: { innerKm: 20, middleKm: 60, outerKm: 200 },
    population: { inner: 5_000, middle: 200_000, outer: 4_000_000 },
    cities: {
      inner:  ['(Spirit Lake area, sparsely populated)'],
      middle: ['Castle Rock', 'Toledo', 'Cougar'],
      outer:  ['Portland, OR', 'Seattle, WA', 'Yakima, WA']
    },
    aftereffects: 'eruption.st-helens.aftereffects'
  },
  pinatubo: {
    zones: { innerKm: 15, middleKm: 60, outerKm: 250 },
    population: { inner: 30_000, middle: 1_500_000, outer: 30_000_000 },
    cities: {
      inner:  ['Aeta indigenous settlements'],
      middle: ['Angeles City', 'Olongapo', 'San Fernando (Pampanga)'],
      outer:  ['Manila', 'Quezon City', 'Baguio']
    },
    aftereffects: 'eruption.pinatubo.aftereffects'
  },
  eyjafjallajokull: {
    zones: { innerKm: 5, middleKm: 25, outerKm: 800 },
    population: { inner: 200, middle: 8_000, outer: 500_000_000 },
    cities: {
      inner:  ['(uninhabited glacier)'],
      middle: ['Hvolsvöllur', 'Vík'],
      outer:  ['Reykjavík', 'London', 'Paris', 'Berlin (aviation hubs)']
    },
    aftereffects: 'eruption.eyjafjallajokull.aftereffects'
  },
  fuji: {
    zones: { innerKm: 10, middleKm: 40, outerKm: 150 },
    population: { inner: 50_000, middle: 1_200_000, outer: 35_000_000 },
    cities: {
      inner:  ['Fujinomiya', 'Fujikawaguchiko'],
      middle: ['Numazu', 'Mishima', 'Gotemba'],
      outer:  ['Tokyo', 'Yokohama', 'Shizuoka City']
    },
    aftereffects: 'eruption.fuji.aftereffects'
  },
  etna: {
    zones: { innerKm: 8, middleKm: 25, outerKm: 80 },
    population: { inner: 100_000, middle: 600_000, outer: 2_500_000 },
    cities: {
      inner:  ['Nicolosi', 'Linguaglossa', 'Zafferana Etnea'],
      middle: ['Catania', 'Acireale'],
      outer:  ['Messina', 'Syracuse', 'Enna']
    },
    aftereffects: 'eruption.etna.aftereffects'
  },
  sakurajima: {
    zones: { innerKm: 5, middleKm: 20, outerKm: 70 },
    population: { inner: 5_000, middle: 700_000, outer: 2_500_000 },
    cities: {
      inner:  ['Sakurajima town'],
      middle: ['Kagoshima'],
      outer:  ['Kirishima', 'Miyazaki', 'Kumamoto (light ash)']
    },
    aftereffects: 'eruption.sakurajima.aftereffects'
  },
  kilauea: {
    zones: { innerKm: 5, middleKm: 20, outerKm: 60 },
    population: { inner: 2_000, middle: 50_000, outer: 200_000 },
    cities: {
      inner:  ['Pāhoa (lava-flow path)', 'Leilani Estates'],
      middle: ['Hilo (eastern outskirts)', 'Volcano Village'],
      outer:  ['Hilo', 'Kailua-Kona']
    },
    aftereffects: 'eruption.kilauea.aftereffects'
  },
  'mauna-loa': {
    zones: { innerKm: 15, middleKm: 50, outerKm: 150 },
    population: { inner: 5_000, middle: 80_000, outer: 250_000 },
    cities: {
      inner:  ['(saddle road area)'],
      middle: ['Hilo', 'Kailua-Kona', 'Captain Cook'],
      outer:  ['(entire island of Hawaiʻi)']
    },
    aftereffects: 'eruption.mauna-loa.aftereffects'
  },
  yellowstone: {
    zones: { innerKm: 80, middleKm: 400, outerKm: 1500 },
    population: { inner: 50_000, middle: 5_000_000, outer: 100_000_000 },
    cities: {
      inner:  ['(Yellowstone caldera, park interior)'],
      middle: ['Bozeman, MT', 'Idaho Falls, ID', 'Jackson, WY'],
      outer:  ['Salt Lake City', 'Denver', 'Minneapolis', 'Chicago (ashfall)']
    },
    aftereffects: 'eruption.yellowstone.aftereffects'
  },
  'campi-flegrei': {
    zones: { innerKm: 12, middleKm: 50, outerKm: 200 },
    population: { inner: 500_000, middle: 4_000_000, outer: 12_000_000 },
    cities: {
      inner:  ['Pozzuoli', 'Bacoli', 'Quarto'],
      middle: ['Naples', 'Caserta', 'Salerno'],
      outer:  ['Rome', 'Bari', 'Foggia']
    },
    aftereffects: 'eruption.campi-flegrei.aftereffects'
  },
  taal: {
    zones: { innerKm: 14, middleKm: 40, outerKm: 150 },
    population: { inner: 450_000, middle: 4_000_000, outer: 30_000_000 },
    cities: {
      inner:  ['Talisay', 'Tagaytay (south rim)', 'Agoncillo'],
      middle: ['Batangas City', 'Lipa', 'Calamba'],
      outer:  ['Manila', 'Quezon City']
    },
    aftereffects: 'eruption.taal.aftereffects'
  },
  merapi: {
    zones: { innerKm: 8, middleKm: 30, outerKm: 100 },
    population: { inner: 100_000, middle: 2_500_000, outer: 8_000_000 },
    cities: {
      inner:  ['Kaliurang', 'Kinahrejo (former)'],
      middle: ['Yogyakarta', 'Magelang', 'Klaten'],
      outer:  ['Semarang', 'Solo (Surakarta)']
    },
    aftereffects: 'eruption.merapi.aftereffects'
  },
  nyiragongo: {
    zones: { innerKm: 12, middleKm: 30, outerKm: 80 },
    population: { inner: 250_000, middle: 1_500_000, outer: 4_000_000 },
    cities: {
      inner:  ['Northern Goma neighborhoods'],
      middle: ['Goma', 'Gisenyi (Rwanda side)'],
      outer:  ['Kibuye', 'Bukavu', 'Sake']
    },
    aftereffects: 'eruption.nyiragongo.aftereffects'
  },
  hekla: {
    zones: { innerKm: 10, middleKm: 50, outerKm: 300 },
    population: { inner: 100, middle: 5_000, outer: 320_000 },
    cities: {
      inner:  ['(uninhabited highland)'],
      middle: ['Hella', 'Hvolsvöllur'],
      outer:  ['Reykjavík', 'Selfoss', 'Akureyri']
    },
    aftereffects: 'eruption.hekla.aftereffects'
  },
  erebus: {
    zones: { innerKm: 5, middleKm: 25, outerKm: 80 },
    population: { inner: 0, middle: 1_000, outer: 1_500 },
    cities: {
      inner:  ['(uninhabited)'],
      middle: ['McMurdo Station', 'Scott Base'],
      outer:  ['(Ross Island research stations)']
    },
    aftereffects: 'eruption.erebus.aftereffects'
  },
  cotopaxi: {
    zones: { innerKm: 10, middleKm: 40, outerKm: 130 },
    population: { inner: 5_000, middle: 1_500_000, outer: 6_000_000 },
    cities: {
      inner:  ['Latacunga (lahar path)'],
      middle: ['Quito (southern districts)', 'Sangolquí', 'Latacunga'],
      outer:  ['Quito (full metro)', 'Ambato', 'Riobamba']
    },
    aftereffects: 'eruption.cotopaxi.aftereffects'
  },
  unzen: {
    zones: { innerKm: 6, middleKm: 20, outerKm: 70 },
    population: { inner: 30_000, middle: 250_000, outer: 1_500_000 },
    cities: {
      inner:  ['Shimabara'],
      middle: ['Unzen (town)', 'Minamishimabara', 'Isahaya'],
      outer:  ['Nagasaki', 'Saga', 'Kumamoto']
    },
    aftereffects: 'eruption.unzen.aftereffects'
  }
};
```

- [ ] **Step 2: Add curated EN aftereffects strings**

In the EN dictionary, add these 20 keys (group at the bottom of the eruption-simulator block from Task 2):

```js
'eruption.vesuvius.aftereffects':
  'A modern Plinian eruption of Vesuvius would directly threaten the most densely populated active volcano region on Earth. The 700,000 residents within roughly 7 km of the cone — across Torre del Greco, Ercolano and the surrounding Red Zone — face survival times measured in minutes from pyroclastic density currents. Up to three million people across greater Naples sit inside the heavy-ashfall zone. Italian civil protection plans rely on a 72-hour evacuation window; an eruption with shorter notice would overwhelm available roads and exit corridors.',
'eruption.krakatoa.aftereffects':
  'A repeat of the 1883-class eruption of Krakatoa would generate ocean-crossing tsunami within minutes of paroxysmal collapse, threatening every coast on the Sunda Strait and reaching as far as the western coasts of Sumatra and Java within hours. Atmospheric injection of sulfate aerosols would dim global sunlight and cool average temperatures for one to three years, with measurable impacts on monsoon rainfall and Northern Hemisphere agriculture. Aviation across South-East Asia would halt for weeks.',
'eruption.tambora.aftereffects':
  'Tambora 1815 caused the "Year Without a Summer" of 1816 — global crop failure, famine across Europe and North America, and an estimated 100,000 deaths from the eruption and its climate aftershock combined. A modern repeat would arrive in a world feeding eight billion people on tightly coupled food systems; 2-3 °C of regional cooling for three years would cascade through grain markets, hydroelectric output, and disease vectors in ways the 1815 world could not approximate.',
'eruption.st-helens.aftereffects':
  'A repeat of the 18 May 1980 lateral blast would devastate the Toutle, Cowlitz and Lewis river valleys with lahars reaching the Columbia River. Ashfall a centimeter thick would blanket eastern Washington and parts of Idaho and Montana, grounding flights at Sea-Tac and Portland International for several days. The 1980 event killed 57; a modern repeat threatens larger populations now living in the Cowlitz County corridor.',
'eruption.pinatubo.aftereffects':
  'Pinatubo 1991 cooled global temperatures by 0.5 °C for 1992-1993 and pushed roughly 800,000 people into evacuation. A modern equivalent during typhoon season would again couple ash with monsoon rainfall to produce lahars that bury entire river systems for years afterward. Manila\'s 14 million residents would experience prolonged ashfall; aviation across the western Pacific would close for weeks.',
'eruption.eyjafjallajokull.aftereffects':
  'The 2010 eruption produced limited local damage but suspended European airspace for six days, costing airlines an estimated $1.7 billion and stranding ten million passengers. A repeat in current jet-stream conditions would again cripple transcontinental aviation; modern airline schedules and just-in-time supply chains are even more sensitive to multi-week closures than they were in 2010.',
'eruption.fuji.aftereffects':
  'A renewed Hōei-style eruption would deposit centimeters of ash across the Tokyo metropolitan area within hours, halting Shinkansen rail traffic, paralysing Haneda and Narita airports, and contaminating water reservoirs that serve 35 million people. Tokyo Bay industrial infrastructure — refineries, power plants, ports — would face long-duration shutdowns from abrasive ash damage to turbines and electronics.',
'eruption.etna.aftereffects':
  'Etna\'s frequent flank eruptions are among the best-monitored in the world; a paroxysmal lava flow towards Catania remains the principal long-term threat. Lava traveling on the existing 2002-2003 paths could reach inhabited Nicolosi within days. Catania-Fontanarossa airport routinely closes for hours-to-days during major ash events, disrupting ferry and air links for the entire eastern Mediterranean.',
'eruption.sakurajima.aftereffects':
  'Sakurajima dusts Kagoshima\'s 600,000 residents with ash on a near-daily basis already; a paroxysmal Plinian event analogous to 1914 would dump multiple centimeters across the city, contaminate the water supply, and cut Kagoshima Bay shipping. Lava flow paths would again threaten to bridge the volcano to the mainland in new directions.',
'eruption.kilauea.aftereffects':
  'A high-rate effusive event like 2018 would again destroy hundreds of homes in Lower Puna, send lava entering the ocean to produce hazardous laze plumes, and force long-term evacuation of Leilani Estates and adjacent subdivisions. Vog (volcanic smog) from sustained sulfur dioxide emissions would degrade air quality across all islands of Hawaiʻi.',
'eruption.mauna-loa.aftereffects':
  'Mauna Loa is the largest active volcano on Earth by volume. A high-volume northeast-rift eruption would send fast-moving ʻaʻā lava toward Hilo within days to weeks; the 1984 flow stopped 7 km short of the city. Severance of the Saddle Road would isolate Hilo from Kona and disrupt astronomy operations on the Mauna Kea summit. Sustained sulfur dioxide degassing would impact air quality across the Hawaiian island chain.',
'eruption.yellowstone.aftereffects':
  'A super-eruption from the Yellowstone caldera would be civilization-altering. Pyroclastic flows would obliterate everything within ~80 km of the caldera; meter-thick ashfall would render most of Montana, Wyoming, Idaho, and large parts of the Dakotas, Nebraska and Colorado uninhabitable for years. Multi-year stratospheric cooling of 5-10 °C would collapse Northern Hemisphere grain harvests for a decade. Probability per century is extremely low — but the consequence envelope justifies the planning attention.',
'eruption.campi-flegrei.aftereffects':
  'Campi Flegrei is currently in a multi-decade phase of bradyseismic ground uplift and is considered by many volcanologists a more pressing threat to Naples than Vesuvius itself. A renewed Monte Nuovo-class event (1538) inside the caldera would directly threaten 500,000 residents of Pozzuoli and the western Naples suburbs; a larger paroxysmal event approaching the Campanian Ignimbrite scale of 39,000 years ago would have continental climate implications.',
'eruption.taal.aftereffects':
  'Taal\'s 2020 eruption forced the evacuation of 450,000 people and contaminated the Manila water supply with ashfall as far as Metro Manila itself, 60 km north. A larger Plinian event from the main vent would project ash into the trans-Pacific air-traffic corridor, cutting Manila and Clark airports. The ~14 million residents of Metro Manila live well within the heavy-ashfall envelope.',
'eruption.merapi.aftereffects':
  'A 2010-class eruption produced pyroclastic flows that killed 350 people and forced 350,000 to evacuate. The 2.5 million residents of greater Yogyakarta sit within the southern lahar corridor. Ash from a paroxysmal event would close Yogyakarta International and disrupt the rice harvest cycle across central Java for one or more seasons.',
'eruption.nyiragongo.aftereffects':
  'Nyiragongo is unique in hosting one of Earth\'s few persistent lava lakes and producing the fastest-moving lava flows on the planet, capable of reaching 60 km/h on its steep flanks. The 2002 and 2021 eruptions sent lava through northern Goma; a major flank eruption would directly threaten the urban centers of Goma (DRC) and Gisenyi (Rwanda), home to a combined ~1.5 million people. Tilted Lake Kivu carries dissolved CO₂ and methane that could be triggered to overturn — releasing a continent-scale gas plume.',
'eruption.hekla.aftereffects':
  'Hekla is famous for very short precursory periods — eruptions historically begin with under an hour\'s seismic warning. Modern Plinian events would deposit fluorine-rich ash across south-Iceland farms, killing livestock through chronic fluorosis, and would shut Keflavík International airport for several days, cutting Iceland\'s primary lifeline to Europe and North America.',
'eruption.erebus.aftereffects':
  'Mount Erebus is the southernmost active volcano on Earth and threatens no civilian population — McMurdo and Scott Base host roughly 1,000-1,500 personnel during the Antarctic summer. A major paroxysmal eruption would, however, complicate research-station logistics and Antarctic flight operations for an entire season, given that the U.S. Antarctic Program flies in and out via Phoenix Airfield only 35 km from the cone.',
'eruption.cotopaxi.aftereffects':
  'Cotopaxi is one of the highest active volcanoes in the world (~5,900 m) and one of the most heavily glaciated. The principal hazard is glacial-melt lahars that can travel down the Río Cutuchi and Río Pita valleys, reaching Latacunga in roughly 30 minutes and threatening southern districts of Quito within an hour. The 1877 eruption produced lahars that destroyed Latacunga twice and left deposits as far as the Pacific. The 2015 unrest crisis triggered evacuation drills for over 300,000 residents.',
'eruption.unzen.aftereffects':
  'The 1990-1995 dome-collapse eruption of Unzen killed 43 people, including volcanologists Maurice and Katia Krafft, and forced extended evacuation of Shimabara. A renewed dome-collapse event would again threaten Shimabara directly with pyroclastic density currents; the city\'s post-1990 hazard zoning has reduced exposure but not eliminated it. Lahars in the Mizunashi River system have been a continuing post-eruption hazard for decades.',
```

- [ ] **Step 3: Add RO stub aftereffects keys**

Mirror in the RO dictionary by either translating each paragraph or adding a fallback. The `t()` function in this codebase already falls back to EN when a key is missing — so the simplest correct path is to add `// TODO: RO translation` comments and skip RO entries entirely for these 20 curated paragraphs in phase 1. Do this:

In the RO dictionary, after the existing eruption RO keys, append:

```js
// TODO: RO translation — phase 1 ships EN fallback for the 20 curated aftereffects paragraphs.
// (No keys here — t('eruption.<id>.aftereffects') falls back to the EN dictionary.)
```

Confirm fallback works: `Grep "function t\\b" volcano-globe (7).html` — if `t()` does NOT fall back to EN on missing key, you must add stub RO entries that re-use the EN strings:

```js
'eruption.vesuvius.aftereffects': 'A modern Plinian eruption of Vesuvius...',  // TODO: RO
// ... 19 more ...
```

- [ ] **Step 4: Verify static parse**

Run extraction `node --check`. Expected: no output.

- [ ] **Step 5: Manual verification (USER STEP)**

Reload. Click each of the 20 curated volcanoes (any active volcano on the list). Confirm:
- The Simulate button still works.
- The damage report shows the curated populations and city lists rather than rough estimates.
- The aftereffects paragraph is the curated one (specific to that volcano), not the templated one.
- For Vesuvius specifically, the Inner zone radius reads "7 km" not "15 km".

Then click an active volcano NOT in the curation list (e.g. Stromboli, Bromo, Klyuchevskaya). Confirm:
- The damage report still renders.
- The radii match `ERUPTION_VEI_RADII[v.vei]`.
- The aftereffects paragraph is the templated tier paragraph plus any conditional clauses (tsunami / lahar / climate / aviation).
- The "Cities & landmarks affected" section is *absent* (correct — no curation).
- The population footnote reads "Estimated from country-average population density."

---

## Task 9: End-to-end verification

**Files:**
- Read: `volcano-globe (7).html`

- [ ] **Step 1: Static parse**

```bash
node --check <(awk '/<script>/,/<\/script>/' "C:/Users/Tudor/Desktop/Magmascope/volcano-globe (7).html" | sed '1d;$d')
```

Expected: no output (clean parse). If you get errors, locate the line and fix before continuing.

- [ ] **Step 2: Headless DOM probe**

```bash
msedge --headless --disable-gpu --virtual-time-budget=10000 --dump-dom "file:///C:/Users/Tudor/Desktop/Magmascope/volcano-globe%20(7).html" > _probe.html
```

Open `_probe.html` and confirm:
- `id="statTotal"` shows `226`
- `id="statActive"` shows `163`
- `id="loaderOverlay"` (or equivalent) is hidden / has `display: none`

If stats are blank or the loader is still visible, runtime initialization is failing — open the file in a regular browser and read the dev console.

- [ ] **Step 3: Memory-leak smoke test**

In the dev console with the file loaded:

```js
const v = VOLCANO_DATA.find(x => x.id === 'vesuvius');
const baseline = globe.scene().children.length;
for (let i = 0; i < 50; i++) {
  spawnEruptionAt(v);
  clearEruptionZones();
}
console.log(globe.scene().children.length - baseline);  // → 0
console.log(activeEruption);                            // → null
```

Expected: 0, null. Any drift means `clearEruptionZones` is leaking.

- [ ] **Step 4: VEI tier coverage check**

```js
// Confirm every VEI level renders correctly.
for (let vei = 0; vei <= 8; vei++) {
  const v = VOLCANO_DATA.find(x => x.status === 'Active' && x.vei === vei);
  if (!v) { console.log(`VEI ${vei}: no active volcano in dataset`); continue; }
  spawnEruptionAt(v);
  console.log(`VEI ${vei}: ${v.name} →`, getZoneRadiiFor(v));
  clearEruptionZones();
}
```

Expected: each line prints sensible km radii matching the table in the spec. (Some VEI tiers may be absent in the dataset — that's fine, the simulator doesn't need to handle a tier that has no representatives.)

- [ ] **Step 5: i18n round-trip check**

```js
setLanguage('ro');
const v = VOLCANO_DATA.find(x => x.id === 'vesuvius');
spawnEruptionAt(v);
renderPanel(v, { mode: 'eruption' });
// Visually inspect: banner, zone names, chip labels, footer should all be Romanian.
clearEruptionZones();
setLanguage('en');
```

- [ ] **Step 6: User manual visual sign-off (USER STEP)**

This is the gate that cannot be automated in this environment (SwiftShader screenshots fail; per memory).

User must visually confirm, in a real browser:

1. Selecting an active volcano shows the Simulate button below the safety section.
2. Clicking Simulate animates three concentric rings outward over ~1.8 s, the cone briefly tints red, the panel re-renders with the damage report.
3. The damage report contains: tier banner with VEI label and Reset button; zone table with three rows; population chips; cities list (curated only); aftereffects prose; footer disclaimer.
4. Reset button removes the rings and restores the standard panel.
5. Closing the panel with × or ESC removes the rings.
6. Selecting a different volcano while a sim is running removes the previous rings before the new panel opens.
7. Dormant and Extinct volcanoes never show the Simulate button.
8. Romanian language toggle translates all simulator UI labels.

If any item fails, the corresponding earlier task is incomplete — return to it.

---

## Self-Review

Run after the last task is implemented; this is for the engineer who wrote the code, not for the planner.

**1. Spec coverage** — every section of the spec maps to a task:

| Spec section | Task |
|---|---|
| Goal / non-goals | (whole plan) |
| User flow | Task 6 |
| Architecture (constants, helpers, state) | Tasks 1, 3, 4 |
| Hazard zone model (radii, colors) | Task 1 |
| Curated overrides schema | Task 1 (skeleton) + Task 8 (data) |
| Phase 1 curation list (20 volcanoes) | Task 8 (note: Toba substituted with Campi Flegrei because Toba is not in `VOLCANO_DATA`) |
| Spherical-cap rendering | Task 3 |
| Animation | Task 4 |
| Cone pulse | Task 4 (`pulseConeFor`/`restoreConeFor`) |
| Cleanup `clearEruptionZones` | Tasks 4 (impl) + 7 (wired into hooks) |
| Damage-report panel | Task 6 |
| i18n keys | Tasks 2 + 8 |
| Edge cases & invariants | Tasks 4 + 7 + 9 |
| Verification plan | Task 9 |

**2. Placeholder scan** — search for `TODO`, `TBD`, `__placeholder__`, "implement later". Found:
- `// TODO: RO translation` in Task 8 — INTENTIONAL (RO translation is explicit phase-2 deferral per the spec).
- No other placeholders.

**3. Type consistency** — function signatures and field names are consistent across tasks:
- `getZoneRadiiFor(v)` returns `{ innerKm, middleKm, outerKm }` everywhere.
- `getPopulationFor(v)` returns `{ inner, middle, outer }` everywhere.
- `getCitiesFor(v)` returns `{ inner: string[], middle: string[], outer: string[] }` or `null`.
- `clearEruptionZones()` and `spawnEruptionAt(v)` are called with consistent signatures from Tasks 4, 6, 7, 9.
- `activeEruption` shape is consistent: `{ volcanoId, group, caps, startTime, animFrameId, originalConeEmissive }`.

No inconsistencies found.

---

## Phase 2 (out of scope)

- Translate the 20 curated EN aftereffects paragraphs into Romanian.
- Expand `ERUPTION_OVERRIDES` past 20 volcanoes after the user tests phase 1.
- Wind-aware directional plumes; lava-flow paths along terrain; tsunami arrival rings.
- Other planets (priority queue #8).
