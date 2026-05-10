# Magmascope — React Restructure Design

**Date:** 2026-05-08  
**Scope:** Strict 1:1 port of `volcano-globe (7).html` (~7300 lines) into a Vite + React project. No feature additions. Visual output must be pixel-identical.

---

## 1. Goals & Constraints

- Split the monolithic HTML file into maintainable, feature-organized React components.
- Preserve every existing feature: Globe.gl 3D markers, clustering, search/filter, info panel, safety section, legend info card, HUD, EN/RO i18n, loading screen.
- All hard constraints from the original file remain in force:
  - **Never call `customLayerData(filtered)`** — toggles `obj.visible` on existing meshes instead.
  - **Never swap `ringsData` during lock-on** — rings stay disabled (`ringsData([])`).
  - **CORS-safe texture URLs** — Three.js textures must come from unpkg/jsDelivr.
  - Globe radius = 100 Three.js units.
  - `clusterCones[]` are in `globe.scene()`, not in the customLayer.

---

## 2. Build Tooling

- **Vite + React** (`npm create vite@latest magmascope -- --template react`)
- **Three.js and Globe.gl stay on CDN** via `<script>` tags in `index.html` — avoids bundling WebGL code through Vite, which has caused build issues with Globe.gl.
- No TypeScript, no additional state management libraries.
- Google Fonts loaded via `<link>` in `index.html`.

---

## 3. Project Structure

```
magmascope/
  index.html                  ← Vite entry; CDN script tags for Three.js + Globe.gl; Google Fonts link
  src/
    main.jsx                  ← imports global CSS, renders <App />
    App.jsx                   ← context providers + layout composition
    data/
      volcanoes.js            ← VOLCANO_DATA array (226 objects, verbatim)
      i18n.js                 ← I18N dict + t(key, lang) + tFallback(prefix, value, lang) as pure functions
      monitoring.js           ← MONITORING_AGENCIES + HAZARDS_BY_TYPE objects
    hooks/
      useGlobe.js             ← Globe.gl init, 3D markers, clustering, raycasting, search filter
      useSearch.js            ← search query filtering + suggestion generation logic
    context/
      LanguageContext.jsx     ← currentLang + setLanguage (persisted to localStorage)
      GlobeContext.jsx        ← selectedVolcano, lockVolcano, unlockVolcano, isLoaded, searchQuery
    components/
      GlobeContainer/
        GlobeContainer.jsx    ← mount <div> ref, calls useGlobe, renders nothing visible
      Header/
        Header.jsx
        Header.css
      SearchBar/
        SearchBar.jsx
        SearchBar.css
      Stats/
        Stats.jsx             ← site count + active count readouts
      InfoPanel/
        InfoPanel.jsx
        InfoPanel.css
        SafetySection.jsx
        SafetySection.css
      Legend/
        Legend.jsx
        Legend.css
        LegendInfoCard.jsx
        LegendInfoCard.css
      HUD/
        HUD.jsx
        HUD.css
      Loader/
        Loader.jsx
        Loader.css
      LanguageSwitcher/
        LanguageSwitcher.jsx
        LanguageSwitcher.css
    styles/
      tokens.css              ← :root CSS custom properties (design tokens only)
      global.css              ← reset, html/body, body::before grid, body::after vignette, #globeViz
  README.md
```

---

## 4. Data Layer

Three files, no logic — pure exports of the constants from the original script block.

- **`volcanoes.js`** — `export const VOLCANO_DATA = [ … ]`
- **`i18n.js`** — `export const I18N = { en: {…}, ro: {…} }` plus:
  - `export function t(key, lang)` — looks up `I18N[lang][key]`, falls back to `I18N.en[key]`, then `key`
  - `export function tFallback(prefix, value, lang)` — tries `prefix.value`, falls back to `value`
  - Functions take `lang` as a parameter (no global state) so they're pure and testable
- **`monitoring.js`** — `export const MONITORING_AGENCIES` + `export const HAZARDS_BY_TYPE`

---

## 5. Contexts

### LanguageContext
```
currentLang: 'en' | 'ro'          // initialized from localStorage, falls back to browser lang
setLanguage(lang): void            // saves to localStorage, triggers re-render
```
All components that render translated text read `currentLang` here and pass it to `t()`.

### GlobeContext
```
selectedVolcano: VolcanoObject | null
lockVolcano(volcano): void          // sets selectedVolcano; useGlobe watches it to swap materials + camera
unlockVolcano(): void               // clears selectedVolcano; useGlobe watches it to restore materials
isLoaded: boolean                   // true once globe's onGlobeReady fires
searchQuery: string
setSearchQuery(q): void
```
Both contexts wrap `App` at the root so the full component tree can read from them.

---

## 6. `useGlobe` Hook

Called once in `GlobeContainer`. Mount-once pattern (`useEffect` with `[]` deps).

**Responsibilities:**
1. Calls `Globe()(mountRef.current)` to initialize Globe.gl with Earth textures + atmosphere
2. Builds all 226 volcano cone markers (Three.js `ConeGeometry` groups) via the existing `buildVolcanoMarker()` logic, stores them in a `Map<id, group>`
3. Runs clustering (`buildClusters()`, `updateClusterVisibility()`) and adds cluster cones to `globe.scene()`
4. Sets up the raycaster + mousemove/click event listeners for hover tooltip and volcano selection
5. On click → calls `GlobeContext.lockVolcano(volcano)` (sets React state); a separate `useEffect` watching `selectedVolcano` handles the Three.js material swap and `globe.pointOfView()` call
6. Watches `GlobeContext.searchQuery` in a separate `useEffect` — toggles `mesh.visible` on existing objects
7. Calls `GlobeContext.setIsLoaded(true)` in `onGlobeReady` callback
8. Cleans up event listeners and resize observer on unmount

**Returns:** nothing. All outward state flows through `GlobeContext`.

---

## 7. Components

### `App.jsx`
Composes the full layout:
```jsx
<LanguageContext.Provider>
  <GlobeContext.Provider>
    <LanguageSwitcher />
    <Header />           {/* contains SearchBar + Stats */}
    <GlobeContainer />
    <InfoPanel />
    <Legend />
    <HUD />
    <Loader />
  </GlobeContext.Provider>
</LanguageContext.Provider>
```

### `Header`
Renders `.header` shell containing `<SearchBar />` and `<Stats />`. Stateless.

### `SearchBar`
Reads `searchQuery`/`setSearchQuery` from `GlobeContext` and `currentLang` from `LanguageContext`.  
Calls `useSearch(searchQuery, volcanoes)` to generate suggestion list.  
Handles keyboard navigation (arrow keys, Enter, Escape) for the autocomplete dropdown.  
On suggestion select → calls `GlobeContext.lockVolcano(volcano)`.

### `Stats`
Imports `VOLCANO_DATA` directly (counts are static). Renders `<span id="statCount">` (total) and `<span id="statActive">` (status === 'Active' count).

### `InfoPanel`
Reads `selectedVolcano` from `GlobeContext`, `currentLang` from `LanguageContext`.  
Slides in/out via CSS class toggle based on `selectedVolcano !== null`.  
Renders panel content as JSX (replacing the old `renderPanel()` innerHTML injection).  
Fetches Wikipedia image via `fetchVolcanoImage(wikiTitle)` in a local `useEffect`; result stored in local component state with a module-level `imageCache` Map to avoid redundant fetches.  
Renders `<SafetySection volcano={selectedVolcano} />` inline.

### `SafetySection`
Pure presentational component. Takes `volcano` prop, reads `currentLang` from context.  
Renders hazard chips, agency link, advice text. Returns `null` for extinct non-notable volcanoes.

### `Legend`
Renders the VEI dot scale. Manages open/close state for `LegendInfoCard` locally (no context needed — it's self-contained).

### `LegendInfoCard`
Reads `currentLang` from `LanguageContext`. Renders status swatches + VEI 0-8 ladder as JSX. Re-renders automatically on language change (no manual `rerenderI18nDynamic` needed).

### `HUD`
Reads `selectedVolcano` from `GlobeContext`. Shows/hides via `aria-hidden` + CSS. Renders crosshair corners, scan line, and readout text.

### `Loader`
Reads `isLoaded` from `GlobeContext`. Fades out (CSS transition) when `isLoaded` is `true`.

### `LanguageSwitcher`
Reads `currentLang` + `setLanguage` from `LanguageContext`. Renders EN/RO buttons.

---

## 8. CSS Organization

No class names change. CSS is moved verbatim, split by component.

| File | Rules moved from original |
|---|---|
| `styles/tokens.css` | `:root { … }` block |
| `styles/global.css` | `*, html, body, body::before, body::after, #globeViz, #globeViz:active` |
| `Header.css` | `.header`, `.brand`, `.brand-dot`, `.title`, `.title-eyebrow`, `.title-main`, `@keyframes pulse-dot` |
| `SearchBar.css` | `.search-container`, `#volcanoSearch`, `.search-icon`, `.search-clear`, `.search-suggestions`, `.search-suggestion`, `.suggestion-*` |
| `InfoPanel.css` | `.info-panel`, `.panel-inner`, `.panel-*`, `.meta-*`, `.desc-*`, `.volcano-img-*` |
| `SafetySection.css` | `.safety-block`, `.safety-*` |
| `Legend.css` | `.legend`, `.legend-*`, `@keyframes pulse-cataclysmic`, `@keyframes pulse-significant` |
| `LegendInfoCard.css` | `.legend-info-card`, `.legend-info-*`, `.swatch-*` |
| `HUD.css` | `.hud`, `.hud-corner`, `.hud-scan-line`, `.hud-center-dot`, `.hud-readout` |
| `Loader.css` | `.loader`, `.loader-text` |
| `LanguageSwitcher.css` | `.lang-switcher` |

---

## 9. README

The README will document:
- Prerequisites (Node 18+)
- Install: `npm install`
- Dev server: `npm run dev` (Vite, opens at `http://localhost:5173`)
- Build: `npm run build`
- Preview build: `npm run preview`
- Note on Globe.gl CDN dependency (why it's not bundled)

---

## 10. Out of Scope

The following items from the priority queue are **not** part of this restructure:

- Eruption video clips on splash screen
- Romanian translation review
- Eruption Simulator (particle system)
- Additional planets (Mars / Io / Venus)

These will be built as new features on top of the React codebase.
