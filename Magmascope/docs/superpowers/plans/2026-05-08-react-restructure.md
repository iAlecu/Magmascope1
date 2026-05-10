# Magmascope React Restructure — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `volcano-globe (7).html` (~7300 lines) into a Vite + React project with the same visual output and features.

**Architecture:** Feature-organized React components sharing state via two React Contexts (`LanguageContext`, `GlobeContext`). Globe.gl lives entirely inside a `useGlobe` custom hook that mounts once and communicates outward only through context. All CSS moved verbatim into per-component files. No class names change.

**Tech Stack:** Vite 5, React 18, plain CSS, Three.js 0.150.0 + Globe.gl 2.32.4 (both on CDN via index.html script tags — NOT bundled through Vite), Vitest for unit tests on pure functions.

**Source file:** `C:\Users\Tudor\Desktop\Magmascope\volcano-globe (7).html`

---

## Task 1: Scaffold the Vite + React project

**Files:**
- Create: `magmascope/` (new project directory next to the original HTML file)
- Create: `magmascope/index.html`
- Create: `magmascope/src/main.jsx`
- Create: `magmascope/src/App.jsx`
- Create: `magmascope/vite.config.js`

- [ ] **Step 1: Create the Vite project**

Run from `C:\Users\Tudor\Desktop\Magmascope`:
```
npm create vite@latest magmascope -- --template react
cd magmascope
npm install
```

Expected output: project created, deps installed, no errors.

- [ ] **Step 2: Install Vitest for unit testing**

```
npm install -D vitest @vitest/ui jsdom @testing-library/react @testing-library/jest-dom
```

- [ ] **Step 3: Configure Vitest in vite.config.js**

Replace `magmascope/vite.config.js` with:
```js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test-setup.js',
  },
});
```

- [ ] **Step 4: Create test setup file**

Create `magmascope/src/test-setup.js`:
```js
import '@testing-library/jest-dom';
```

- [ ] **Step 5: Delete Vite boilerplate files**

Delete: `src/App.css`, `src/index.css`, `src/assets/react.svg`, `public/vite.svg`

Run:
```
rm -f src/App.css src/index.css src/assets/react.svg public/vite.svg
```

- [ ] **Step 6: Create the directory structure**

```
mkdir -p src/data src/hooks src/context src/styles
mkdir -p src/components/GlobeContainer
mkdir -p src/components/Header
mkdir -p src/components/SearchBar
mkdir -p src/components/Stats
mkdir -p src/components/InfoPanel
mkdir -p src/components/Legend
mkdir -p src/components/HUD
mkdir -p src/components/Loader
mkdir -p src/components/LanguageSwitcher
mkdir -p src/__tests__
```

- [ ] **Step 7: Write index.html with CDN deps**

Replace `magmascope/index.html` entirely:
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Magmascope · Global Volcanic Monitor</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet" />
    <script src="https://unpkg.com/three@0.150.0/build/three.min.js"></script>
    <script src="https://unpkg.com/globe.gl@2.32.4/dist/globe.gl.min.js"></script>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

- [ ] **Step 8: Write main.jsx**

Create `magmascope/src/main.jsx`:
```jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import './styles/tokens.css';
import './styles/global.css';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

- [ ] **Step 9: Write a stub App.jsx so Vite starts cleanly**

Create `magmascope/src/App.jsx`:
```jsx
export default function App() {
  return <div>Magmascope loading...</div>;
}
```

- [ ] **Step 10: Verify dev server starts**

```
npm run dev
```

Expected: Vite server starts at `http://localhost:5173`. Browser shows "Magmascope loading...". No console errors.

- [ ] **Step 11: Commit**

```
git init
git add .
git commit -m "feat: scaffold Vite + React project with Vitest"
```

---

## Task 2: Global CSS (tokens + global + cluster)

**Files:**
- Create: `src/styles/tokens.css`
- Create: `src/styles/global.css`
- Create: `src/styles/cluster.css`

These are direct copies of CSS blocks from the source file. No code changes — just extraction.

- [ ] **Step 1: Create tokens.css**

Create `magmascope/src/styles/tokens.css`. Copy lines 53–78 from `volcano-globe (7).html` verbatim (the `:root { }` block):
```css
:root {
  --bg-deep:       #030305;
  --bg-panel:      rgba(10, 11, 16, 0.78);
  --bg-panel-solid:#0a0b10;

  --border-subtle: rgba(255, 255, 255, 0.06);
  --border-warm:   rgba(255, 110, 50, 0.25);

  --text-primary:  #f4f4f6;
  --text-secondary:#8b8b95;
  --text-tertiary: #54545c;

  --magma-core:    #ff5722;
  --magma-glow:    #ff8c42;
  --magma-bright:  #ffb627;
  --magma-deep:    #c62a00;

  --status-live:   #4ade80;

  --font-sans:     'Inter', system-ui, sans-serif;
  --font-mono:     'JetBrains Mono', 'SF Mono', Menlo, monospace;

  --ease-out:      cubic-bezier(0.16, 1, 0.3, 1);
}
```

- [ ] **Step 2: Create global.css**

Create `magmascope/src/styles/global.css`. Copy lines 80–133 from `volcano-globe (7).html` verbatim (reset, html/body, body::before, body::after, #globeViz rules):
```css
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html, body {
  height: 100%;
  width: 100%;
  overflow: hidden;
  background: var(--bg-deep);
  color: var(--text-primary);
  font-family: var(--font-sans);
  font-feature-settings: 'cv11', 'ss01';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body::before {
  content: '';
  position: fixed;
  inset: 0;
  background-image:
    linear-gradient(rgba(255,255,255,0.015) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.015) 1px, transparent 1px);
  background-size: 64px 64px;
  pointer-events: none;
  z-index: 1;
}

body::after {
  content: '';
  position: fixed;
  inset: 0;
  background: radial-gradient(
    ellipse at center,
    transparent 40%,
    rgba(255, 87, 34, 0.04) 75%,
    rgba(0,0,0,0.5) 100%
  );
  pointer-events: none;
  z-index: 1;
}

#globeViz {
  position: absolute;
  inset: 0;
  z-index: 0;
  cursor: grab;
}
#globeViz:active { cursor: grabbing; }
```

- [ ] **Step 3: Create cluster.css**

Create `magmascope/src/styles/cluster.css`. Open `volcano-globe (7).html` and search for `.cluster-marker` — copy all cluster and tooltip CSS rules (approximately lines 830–1036 in the original). These are used by DOM elements created imperatively inside `useGlobe`:
```css
/* Cluster markers */
.cluster-marker {
  cursor: pointer;
  user-select: none;
}
/* (copy the full block from the source file — search for .cluster-marker to find start,
   copy through to the end of .globe-tooltip CSS rules) */
```

> **Important:** Open `volcano-globe (7).html`, search for `.cluster-marker` (around line 830), and copy every CSS rule from there through the `.globe-tooltip` block (around line 1035). Paste the entire block into `cluster.css`. This is verbatim copy — do not modify any rules.

- [ ] **Step 4: Import cluster.css in main.jsx**

Edit `magmascope/src/main.jsx`, add the import after the existing CSS imports:
```jsx
import './styles/tokens.css';
import './styles/global.css';
import './styles/cluster.css';
import App from './App';
```

- [ ] **Step 5: Commit**

```
git add src/styles/
git add src/main.jsx
git commit -m "feat: add global CSS (tokens, reset, cluster/tooltip styles)"
```

---

## Task 3: Data files (i18n, volcano data, monitoring)

**Files:**
- Create: `src/data/i18n.js`
- Create: `src/data/volcanoes.js`
- Create: `src/data/monitoring.js`
- Create: `src/__tests__/i18n.test.js`

- [ ] **Step 1: Write failing tests for i18n pure functions**

Create `magmascope/src/__tests__/i18n.test.js`:
```js
import { describe, it, expect } from 'vitest';
import { t, tFallback } from '../data/i18n';

describe('t()', () => {
  it('returns the English value for a known key', () => {
    expect(t('brand', 'en')).toBe('Magmascope');
  });

  it('returns the Romanian value when lang is ro', () => {
    expect(t('live', 'ro')).toBe('Live');
  });

  it('falls back to English when the key is missing in Romanian', () => {
    expect(t('brand', 'ro')).toBe('Magmascope');
  });

  it('returns the key itself when missing in both languages', () => {
    expect(t('nonexistent.key', 'en')).toBe('nonexistent.key');
  });
});

describe('tFallback()', () => {
  it('returns the i18n value when a translation exists for the key', () => {
    expect(tFallback('status', 'Active', 'en')).toBe('Active');
  });

  it('returns the raw value when no translation exists for the key', () => {
    expect(tFallback('type', 'SomeUnknownType', 'en')).toBe('SomeUnknownType');
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```
npm run test -- --run
```

Expected: FAIL — "Cannot find module '../data/i18n'"

- [ ] **Step 3: Create i18n.js**

Create `magmascope/src/data/i18n.js`. Copy the `I18N` dictionary from `volcano-globe (7).html` lines 1605–1856, then add pure function exports:
```js
export const I18N = {
  en: {
    // ── paste the full 'en' block from lines 1606–1760 of the source file ──
  },
  ro: {
    // ── paste the full 'ro' block from lines 1761–1855 of the source file ──
  },
};

export function t(key, lang) {
  const dict = I18N[lang] || I18N.en;
  if (key in dict) return dict[key];
  if (key in I18N.en) return I18N.en[key];
  return key;
}

export function tFallback(prefix, value, lang) {
  const key = prefix + '.' + value;
  const dict = I18N[lang] || I18N.en;
  if (key in dict) return dict[key];
  if (key in I18N.en) return I18N.en[key];
  return value;
}
```

> **Copy instruction:** Open `volcano-globe (7).html`. The `I18N` constant starts at line 1605 (`const I18N = {`) and ends at approximately line 1856 (`};`). Copy the object literal content (everything between the outer `{` and `}`), split it into `en:` and `ro:` keys, and paste into the file above. Do not modify any string values.

- [ ] **Step 4: Run tests to confirm they pass**

```
npm run test -- --run
```

Expected: PASS — 6 tests green.

- [ ] **Step 5: Create volcanoes.js**

Create `magmascope/src/data/volcanoes.js`:
```js
export const VOLCANO_DATA = [
  // ── paste all 226 volcano objects verbatim from lines 1953–6234 of the source file ──
];
```

> **Copy instruction:** Open `volcano-globe (7).html`. `VOLCANO_DATA` starts at line 1953 (`const VOLCANO_DATA = [`) and ends at approximately line 6234 (`];`). Copy everything between the outer `[` and `]` brackets and paste into the array above.

- [ ] **Step 6: Create monitoring.js**

Create `magmascope/src/data/monitoring.js`. Copy from `volcano-globe (7).html` lines 7171–7231:
```js
export const MONITORING_AGENCIES = {
  'United States':    { name: 'USGS Volcano Hazards Program', url: 'https://volcanoes.usgs.gov/' },
  'Indonesia':        { name: 'PVMBG (Pusat Vulkanologi dan Mitigasi Bencana Geologi)', url: 'https://magma.esdm.go.id/' },
  'Japan':            { name: 'JMA (Japan Meteorological Agency)', url: 'https://www.data.jma.go.jp/svd/vois/data/tokyo/STOCK/monthly_v-act_doc/monthly_vact.htm' },
  'Italy':            { name: 'INGV (Istituto Nazionale di Geofisica e Vulcanologia)', url: 'https://www.ingv.it/' },
  'Iceland':          { name: 'Icelandic Meteorological Office', url: 'https://en.vedur.is/' },
  'Russia':           { name: 'KVERT (Kamchatka Volcanic Eruption Response Team)', url: 'http://www.kscnet.ru/ivs/kvert/' },
  'Chile':            { name: 'SERNAGEOMIN — Red Nacional de Vigilancia Volcánica', url: 'https://www.sernageomin.cl/' },
  'Mexico':           { name: 'CENAPRED', url: 'https://www.gob.mx/cenapred' },
  'Philippines':      { name: 'PHIVOLCS', url: 'https://www.phivolcs.dost.gov.ph/' },
  'New Zealand':      { name: 'GeoNet (GNS Science)', url: 'https://www.geonet.org.nz/volcano' },
  'Greece':           { name: 'Hellenic Volcanological Institute / IGME', url: '' },
  'Spain':            { name: 'IGN (Instituto Geográfico Nacional)', url: 'https://www.ign.es/' },
  'Portugal':         { name: 'IPMA / CIVISA', url: 'https://www.ipma.pt/' },
  'Tanzania':         { name: 'Geological Survey of Tanzania', url: '' },
  'Ethiopia':         { name: 'Geological Survey of Ethiopia', url: '' },
  'Kenya':            { name: 'Kenya Meteorological Department', url: '' },
  'Cameroon':         { name: 'IRGM (Institut de Recherches Géologiques et Minières)', url: '' },
  'Romania':          { name: 'INFP (Institutul Național pentru Fizica Pământului)', url: 'https://www.infp.ro/' },
  'France':           { name: 'IPGP / OVSG / OVSM', url: 'https://www.ipgp.fr/' },
  'Canada':           { name: 'Geological Survey of Canada', url: 'https://www.nrcan.gc.ca/' },
  'Norway':           { name: 'Norwegian Polar Institute / NVE', url: '' },
  'Antarctica':       { name: 'Joint national programs (BAS, USAP, INACH)', url: '' },
  'Vanuatu':          { name: 'VMGD (Vanuatu Meteorology and Geo-hazards Department)', url: 'https://www.vmgd.gov.vu/' },
  'Tonga':            { name: 'Tonga Geological Services', url: '' },
  'Papua New Guinea': { name: 'RVO (Rabaul Volcanological Observatory)', url: '' },
  'Solomon Islands':  { name: 'Ministry of Mines, Energy and Rural Electrification', url: '' },
  'Saint Vincent':    { name: 'UWI Seismic Research Centre', url: 'https://uwiseismic.com/' },
  'Saint Vincent and the Grenadines': { name: 'UWI Seismic Research Centre', url: 'https://uwiseismic.com/' },
  'Montserrat':       { name: 'MVO (Montserrat Volcano Observatory)', url: 'https://www.mvo.ms/' },
  'Cape Verde':       { name: 'INMG (Instituto Nacional de Meteorologia e Geofísica)', url: '' },
  'DR Congo':         { name: 'OVG (Observatoire Volcanologique de Goma)', url: '' },
  'Rwanda / DR Congo':{ name: 'OVG (Observatoire Volcanologique de Goma)', url: '' },
  'Comoros':          { name: 'KVO (Karthala Volcano Observatory)', url: '' },
  'Argentina':        { name: 'OAVV / SEGEMAR', url: 'https://www.segemar.gov.ar/' },
  'Bolivia':          { name: 'Observatorio San Calixto', url: '' },
  'Peru':             { name: 'IGP — Observatorio Vulcanológico (OVI)', url: 'https://www.igp.gob.pe/' },
  'Ecuador':          { name: 'IG-EPN (Instituto Geofísico EPN)', url: 'https://www.igepn.edu.ec/' },
  'Colombia':         { name: 'SGC (Servicio Geológico Colombiano)', url: 'https://www.sgc.gov.co/' },
  'Costa Rica':       { name: 'OVSICORI-UNA', url: 'https://www.ovsicori.una.ac.cr/' },
  'Guatemala':        { name: 'INSIVUMEH', url: 'https://insivumeh.gob.gt/' },
  'El Salvador':      { name: 'MARN — SNET', url: 'https://www.snet.gob.sv/' },
  'Nicaragua':        { name: 'INETER', url: 'https://www.ineter.gob.ni/' },
  'Panama':           { name: 'Universidad de Panamá — Instituto de Geociencias', url: '' },
};

export const HAZARDS_BY_TYPE = {
  'Stratovolcano':     ['pyroclastic', 'lahar', 'ash'],
  'Caldera':           ['ash', 'pyroclastic', 'gas'],
  'Shield Volcano':    ['lava', 'gas'],
  'Cinder Cone':       ['tephra', 'lava'],
  'Lava Dome':         ['pyroclastic', 'collapse'],
  'Submarine Volcano': ['tsunami', 'gas'],
  'Submarine Caldera': ['tsunami', 'pyroclastic'],
  'Submarine':         ['tsunami', 'gas'],
  'Complex Volcano':   ['pyroclastic', 'lahar', 'ash'],
  'Fissure Vent':      ['lava', 'gas'],
  'Mud Volcano':       ['gas'],
  'Lava Cone':         ['lava'],
  'Maar':              ['gas'],
};
```

- [ ] **Step 7: Commit**

```
git add src/data/ src/__tests__/
git commit -m "feat: add data layer (i18n, volcano data, monitoring agencies)"
```

---

## Task 4: LanguageContext

**Files:**
- Create: `src/context/LanguageContext.jsx`
- Create: `src/__tests__/LanguageContext.test.jsx`

- [ ] **Step 1: Write failing test**

Create `magmascope/src/__tests__/LanguageContext.test.jsx`:
```jsx
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { LanguageProvider, useLanguage } from '../context/LanguageContext';

function LangDisplay() {
  const { currentLang, setLanguage } = useLanguage();
  return (
    <div>
      <span data-testid="lang">{currentLang}</span>
      <button onClick={() => setLanguage('ro')}>Switch to RO</button>
    </div>
  );
}

describe('LanguageContext', () => {
  beforeEach(() => localStorage.clear());

  it('defaults to "en" when localStorage is empty', () => {
    render(<LanguageProvider><LangDisplay /></LanguageProvider>);
    expect(screen.getByTestId('lang').textContent).toBe('en');
  });

  it('initializes from localStorage when saved value exists', () => {
    localStorage.setItem('magmascope.lang', 'ro');
    render(<LanguageProvider><LangDisplay /></LanguageProvider>);
    expect(screen.getByTestId('lang').textContent).toBe('ro');
  });

  it('updates lang and persists to localStorage on setLanguage', () => {
    render(<LanguageProvider><LangDisplay /></LanguageProvider>);
    fireEvent.click(screen.getByText('Switch to RO'));
    expect(screen.getByTestId('lang').textContent).toBe('ro');
    expect(localStorage.getItem('magmascope.lang')).toBe('ro');
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
npm run test -- --run
```

Expected: FAIL — "Cannot find module '../context/LanguageContext'"

- [ ] **Step 3: Implement LanguageContext**

Create `magmascope/src/context/LanguageContext.jsx`:
```jsx
import { createContext, useContext, useState } from 'react';

const LanguageContext = createContext(null);

function getInitialLang() {
  const saved = localStorage.getItem('magmascope.lang');
  if (saved === 'en' || saved === 'ro') return saved;
  const browser = (navigator.language || 'en').slice(0, 2);
  return browser === 'ro' ? 'ro' : 'en';
}

export function LanguageProvider({ children }) {
  const [currentLang, setCurrentLangState] = useState(getInitialLang);

  function setLanguage(lang) {
    localStorage.setItem('magmascope.lang', lang);
    setCurrentLangState(lang);
  }

  return (
    <LanguageContext.Provider value={{ currentLang, setLanguage }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error('useLanguage must be used inside LanguageProvider');
  return ctx;
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```
npm run test -- --run
```

Expected: PASS — all 3 LanguageContext tests green.

- [ ] **Step 5: Commit**

```
git add src/context/LanguageContext.jsx src/__tests__/LanguageContext.test.jsx
git commit -m "feat: add LanguageContext with localStorage persistence"
```

---

## Task 5: GlobeContext

**Files:**
- Create: `src/context/GlobeContext.jsx`
- Create: `src/__tests__/GlobeContext.test.jsx`

- [ ] **Step 1: Write failing test**

Create `magmascope/src/__tests__/GlobeContext.test.jsx`:
```jsx
import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { GlobeProvider, useGlobeContext } from '../context/GlobeContext';

const mockVolcano = { id: 'vesuvius', name: 'Mount Vesuvius', status: 'Active' };

function TestConsumer() {
  const { selectedVolcano, lockVolcano, unlockVolcano, searchQuery, setSearchQuery, isLoaded } = useGlobeContext();
  return (
    <div>
      <span data-testid="selected">{selectedVolcano?.name ?? 'none'}</span>
      <span data-testid="query">{searchQuery}</span>
      <span data-testid="loaded">{String(isLoaded)}</span>
      <button onClick={() => lockVolcano(mockVolcano)}>Lock</button>
      <button onClick={() => unlockVolcano()}>Unlock</button>
      <button onClick={() => setSearchQuery('etna')}>Search</button>
    </div>
  );
}

describe('GlobeContext', () => {
  it('starts with no selected volcano and empty query', () => {
    render(<GlobeProvider><TestConsumer /></GlobeProvider>);
    expect(screen.getByTestId('selected').textContent).toBe('none');
    expect(screen.getByTestId('query').textContent).toBe('');
    expect(screen.getByTestId('loaded').textContent).toBe('false');
  });

  it('lockVolcano sets selectedVolcano', () => {
    render(<GlobeProvider><TestConsumer /></GlobeProvider>);
    fireEvent.click(screen.getByText('Lock'));
    expect(screen.getByTestId('selected').textContent).toBe('Mount Vesuvius');
  });

  it('unlockVolcano clears selectedVolcano', () => {
    render(<GlobeProvider><TestConsumer /></GlobeProvider>);
    fireEvent.click(screen.getByText('Lock'));
    fireEvent.click(screen.getByText('Unlock'));
    expect(screen.getByTestId('selected').textContent).toBe('none');
  });

  it('setSearchQuery updates searchQuery', () => {
    render(<GlobeProvider><TestConsumer /></GlobeProvider>);
    fireEvent.click(screen.getByText('Search'));
    expect(screen.getByTestId('query').textContent).toBe('etna');
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
npm run test -- --run
```

Expected: FAIL — "Cannot find module '../context/GlobeContext'"

- [ ] **Step 3: Implement GlobeContext**

Create `magmascope/src/context/GlobeContext.jsx`:
```jsx
import { createContext, useContext, useState } from 'react';

const GlobeContext = createContext(null);

export function GlobeProvider({ children }) {
  const [selectedVolcano, setSelectedVolcano] = useState(null);
  const [isLoaded, setIsLoaded] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  function lockVolcano(volcano) {
    setSelectedVolcano(volcano);
  }

  function unlockVolcano() {
    setSelectedVolcano(null);
  }

  return (
    <GlobeContext.Provider value={{
      selectedVolcano,
      lockVolcano,
      unlockVolcano,
      isLoaded,
      setIsLoaded,
      searchQuery,
      setSearchQuery,
    }}>
      {children}
    </GlobeContext.Provider>
  );
}

export function useGlobeContext() {
  const ctx = useContext(GlobeContext);
  if (!ctx) throw new Error('useGlobeContext must be used inside GlobeProvider');
  return ctx;
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```
npm run test -- --run
```

Expected: PASS — all 4 GlobeContext tests green.

- [ ] **Step 5: Commit**

```
git add src/context/GlobeContext.jsx src/__tests__/GlobeContext.test.jsx
git commit -m "feat: add GlobeContext (selectedVolcano, isLoaded, searchQuery)"
```

---

## Task 6: useSearch hook

**Files:**
- Create: `src/hooks/useSearch.js`
- Create: `src/__tests__/useSearch.test.js`

- [ ] **Step 1: Write failing tests**

Create `magmascope/src/__tests__/useSearch.test.js`:
```js
import { describe, it, expect } from 'vitest';
import { filterVolcanoes, scoreSuggestions, escapeHtml, highlightMatch } from '../hooks/useSearch';

const data = [
  { id: 'vesuvius', name: 'Mount Vesuvius', country: 'Italy', region: 'Campania', type: 'Stratovolcano', notable: true },
  { id: 'etna',     name: 'Mount Etna',     country: 'Italy', region: 'Sicily',   type: 'Stratovolcano', notable: true },
  { id: 'fuji',     name: 'Mount Fuji',     country: 'Japan', region: 'Honshu',   type: 'Stratovolcano', notable: true },
];

describe('filterVolcanoes()', () => {
  it('returns all volcanoes for empty term', () => {
    expect(filterVolcanoes(data, '')).toHaveLength(3);
  });

  it('filters by name (case insensitive)', () => {
    expect(filterVolcanoes(data, 'etna')).toHaveLength(1);
    expect(filterVolcanoes(data, 'etna')[0].id).toBe('etna');
  });

  it('filters by country', () => {
    expect(filterVolcanoes(data, 'italy')).toHaveLength(2);
  });

  it('returns empty array when no match', () => {
    expect(filterVolcanoes(data, 'zzznomatch')).toHaveLength(0);
  });
});

describe('scoreSuggestions()', () => {
  it('returns max 8 results', () => {
    const many = Array.from({ length: 20 }, (_, i) => ({
      id: `v${i}`, name: `Mount ${i}`, country: 'Country', region: 'Region', type: 'Type', notable: false,
    }));
    expect(scoreSuggestions(many, 'mount')).toHaveLength(8);
  });

  it('ranks name-start matches above name-contains matches', () => {
    const results = scoreSuggestions(data, 'mount');
    expect(results[0].name.toLowerCase().startsWith('mount')).toBe(true);
  });

  it('returns empty array for empty term', () => {
    expect(scoreSuggestions(data, '')).toHaveLength(0);
  });
});

describe('escapeHtml()', () => {
  it('escapes &, <, >, ", \'', () => {
    expect(escapeHtml('a&b<c>d"e\'f')).toBe('a&amp;b&lt;c&gt;d&quot;e&#39;f');
  });
});

describe('highlightMatch()', () => {
  it('wraps the matched substring in a suggestion-match span', () => {
    const result = highlightMatch('Mount Etna', 'etna');
    expect(result).toContain('<span class="suggestion-match">Etna</span>');
  });

  it('returns escaped text unchanged when no match', () => {
    expect(highlightMatch('Mount Fuji', 'zzz')).toBe('Mount Fuji');
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```
npm run test -- --run
```

Expected: FAIL — "Cannot find module '../hooks/useSearch'"

- [ ] **Step 3: Implement useSearch.js**

Create `magmascope/src/hooks/useSearch.js`:
```js
export function escapeHtml(s) {
  return s.replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

export function highlightMatch(text, term) {
  if (!term) return escapeHtml(text);
  const idx = text.toLowerCase().indexOf(term.toLowerCase());
  if (idx === -1) return escapeHtml(text);
  return (
    escapeHtml(text.slice(0, idx)) +
    '<span class="suggestion-match">' +
      escapeHtml(text.slice(idx, idx + term.length)) +
    '</span>' +
    escapeHtml(text.slice(idx + term.length))
  );
}

export function filterVolcanoes(volcanoes, term) {
  const q = term.trim().toLowerCase();
  if (!q) return volcanoes;
  return volcanoes.filter(v =>
    [v.name, v.country, v.region, v.type].some(s => s && s.toLowerCase().includes(q))
  );
}

export function scoreSuggestions(volcanoes, term) {
  const q = term.trim().toLowerCase();
  if (!q) return [];

  return volcanoes
    .map(v => {
      const name = v.name.toLowerCase();
      const country = v.country.toLowerCase();
      const region = (v.region || '').toLowerCase();
      const type = v.type.toLowerCase();
      let score = 0;
      if (name.startsWith(q))                               score = 3;
      else if (name.includes(q))                            score = 2;
      else if (country.includes(q) || region.includes(q) || type.includes(q)) score = 1;
      return { v, score };
    })
    .filter(x => x.score > 0)
    .sort((a, b) => b.score - a.score || a.v.name.localeCompare(b.v.name))
    .slice(0, 8)
    .map(x => x.v);
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```
npm run test -- --run
```

Expected: PASS — all 9 useSearch tests green.

- [ ] **Step 5: Commit**

```
git add src/hooks/useSearch.js src/__tests__/useSearch.test.js
git commit -m "feat: add useSearch hook with filter and suggestion scoring"
```

---

## Task 7: Leaf UI components (Loader, HUD, LanguageSwitcher, Stats)

These four components are stateless or near-stateless — they only read from context. Build them all in this task.

**Files:**
- Create: `src/components/Loader/Loader.jsx` + `Loader.css`
- Create: `src/components/HUD/HUD.jsx` + `HUD.css`
- Create: `src/components/LanguageSwitcher/LanguageSwitcher.jsx` + `LanguageSwitcher.css`
- Create: `src/components/Stats/Stats.jsx`

- [ ] **Step 1: Create Loader CSS**

Create `magmascope/src/components/Loader/Loader.css`. Open `volcano-globe (7).html` and copy the `.loader` and `.loader-text` CSS rules (search for `.loader {` around line 1419):
```css
.loader {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-deep);
  transition: opacity 0.8s var(--ease-out);
}
.loader.hidden {
  opacity: 0;
  pointer-events: none;
}
.loader-text {
  font-family: var(--font-mono);
  font-size: 12px;
  letter-spacing: 0.3em;
  text-transform: uppercase;
  color: var(--text-tertiary);
  animation: loader-pulse 1.8s ease-in-out infinite;
}
@keyframes loader-pulse {
  0%, 100% { opacity: 0.4; }
  50%       { opacity: 1; }
}
```

> **Copy instruction:** Open `volcano-globe (7).html`, search for `.loader {` (approximately line 1406), and copy the full block including `.loader-text` and the `@keyframes loader-pulse`. The original uses a `display:none` after fade — in the React version we use `.hidden` class instead (same visual result).

- [ ] **Step 2: Create Loader.jsx**

Create `magmascope/src/components/Loader/Loader.jsx`:
```jsx
import { useGlobeContext } from '../../context/GlobeContext';
import './Loader.css';

export default function Loader() {
  const { isLoaded } = useGlobeContext();
  return (
    <div className={`loader${isLoaded ? ' hidden' : ''}`} id="loader">
      <div className="loader-text">Initializing Observatory…</div>
    </div>
  );
}
```

- [ ] **Step 3: Create HUD CSS**

Create `magmascope/src/components/HUD/HUD.css`. Open `volcano-globe (7).html` and copy all HUD-related CSS rules (search for `.hud {` around line 1066). Copy through the end of all `.hud-*` rules and their animations:
```css
/* (copy all .hud, .hud-corner, .hud-scan-line, .hud-center-dot,
   .hud-readout rules and their @keyframes from the source file) */
```

> **Copy instruction:** Open `volcano-globe (7).html`, search for `.hud {` (approximately line 1066), and copy all CSS through the end of `.hud-readout` and all associated animations (approximately line 1383). Paste verbatim into `HUD.css`.

- [ ] **Step 4: Create HUD.jsx**

Create `magmascope/src/components/HUD/HUD.jsx`:
```jsx
import { useEffect, useRef } from 'react';
import { useGlobeContext } from '../../context/GlobeContext';
import { useLanguage } from '../../context/LanguageContext';
import { t } from '../../data/i18n';
import './HUD.css';

export default function HUD() {
  const { selectedVolcano } = useGlobeContext();
  const { currentLang } = useLanguage();
  const hudRef = useRef(null);
  const lockTimerRef = useRef(null);

  useEffect(() => {
    const hud = hudRef.current;
    if (!hud) return;

    if (lockTimerRef.current) {
      clearTimeout(lockTimerRef.current);
      lockTimerRef.current = null;
    }

    if (selectedVolcano) {
      const readout = hud.querySelector('#hudReadout');
      if (readout) readout.textContent = t('hud.target', currentLang) + ' · ' + selectedVolcano.name;
      hud.classList.remove('locked');
      hud.classList.add('active');
      hud.setAttribute('aria-hidden', 'false');
      lockTimerRef.current = setTimeout(() => hud.classList.add('locked'), 1700);
    } else {
      hud.classList.remove('active', 'locked');
      hud.setAttribute('aria-hidden', 'true');
    }

    return () => {
      if (lockTimerRef.current) clearTimeout(lockTimerRef.current);
    };
  }, [selectedVolcano, currentLang]);

  return (
    <div id="crosshair-hud" className="hud" aria-hidden="true" ref={hudRef}>
      <div className="hud-corner top-left"></div>
      <div className="hud-corner top-right"></div>
      <div className="hud-corner bottom-left"></div>
      <div className="hud-corner bottom-right"></div>
      <div className="hud-scan-line"></div>
      <div className="hud-center-dot"></div>
      <div className="hud-readout" id="hudReadout"></div>
    </div>
  );
}
```

- [ ] **Step 5: Create LanguageSwitcher CSS**

Create `magmascope/src/components/LanguageSwitcher/LanguageSwitcher.css`. Open `volcano-globe (7).html` and copy the `.lang-switcher` CSS rules (search for `.lang-switcher` around line 1383):
```css
/* (copy all .lang-switcher and .lang-switcher button rules from the source file) */
```

> **Copy instruction:** Search `volcano-globe (7).html` for `.lang-switcher` (approximately line 1383). Copy all rules through the end of `.lang-switcher button.active`. Paste verbatim into `LanguageSwitcher.css`.

- [ ] **Step 6: Create LanguageSwitcher.jsx**

Create `magmascope/src/components/LanguageSwitcher/LanguageSwitcher.jsx`:
```jsx
import { useLanguage } from '../../context/LanguageContext';
import './LanguageSwitcher.css';

export default function LanguageSwitcher() {
  const { currentLang, setLanguage } = useLanguage();
  return (
    <div className="lang-switcher" role="group" aria-label="Language">
      <button
        data-lang="en"
        className={currentLang === 'en' ? 'active' : ''}
        onClick={() => setLanguage('en')}
      >EN</button>
      <button
        data-lang="ro"
        className={currentLang === 'ro' ? 'active' : ''}
        onClick={() => setLanguage('ro')}
      >RO</button>
    </div>
  );
}
```

- [ ] **Step 7: Create Stats.jsx**

Stats reads directly from `VOLCANO_DATA` (counts never change dynamically in this 1:1 port).

Create `magmascope/src/components/Stats/Stats.jsx`:
```jsx
import { VOLCANO_DATA } from '../../data/volcanoes';
import { useLanguage } from '../../context/LanguageContext';
import { t } from '../../data/i18n';

const totalCount = String(VOLCANO_DATA.length).padStart(2, '0');
const activeCount = String(VOLCANO_DATA.filter(v => v.status === 'Active').length).padStart(2, '0');

export default function Stats() {
  const { currentLang } = useLanguage();
  return (
    <div className="stats">
      <span>
        <span className="stats-value" id="statCount">{totalCount}</span>{' '}
        <span>{t('stats.sites', currentLang)}</span>
      </span>
      <span>
        <span className="stats-value" id="statActive">{activeCount}</span>{' '}
        <span>{t('stats.active', currentLang)}</span>
      </span>
    </div>
  );
}
```

- [ ] **Step 8: Commit**

```
git add src/components/Loader/ src/components/HUD/ src/components/LanguageSwitcher/ src/components/Stats/
git commit -m "feat: add Loader, HUD, LanguageSwitcher, Stats components"
```

---

## Task 8: useGlobe hook

This is the core imperative boundary. All Globe.gl and Three.js code lives here. The hook mounts once, reads `selectedVolcano` and `searchQuery` from context via refs (to avoid re-creating effects), and uses two separate `useEffect`s for side-effect reactions.

**Files:**
- Create: `src/hooks/useGlobe.js`

> **Note:** This hook cannot be meaningfully unit tested (WebGL requires a real browser GPU). Manual smoke-test instructions are in Task 14.

- [ ] **Step 1: Create useGlobe.js**

Create `magmascope/src/hooks/useGlobe.js`. This is the full hook — complete code below:

```js
import { useEffect, useRef } from 'react';
import { filterVolcanoes } from './useSearch';

export function useGlobe(mountRef, volcanoes, { lockVolcano, unlockVolcano, setIsLoaded, selectedVolcano, searchQuery }) {
  const globeRef = useRef(null);
  const statusMaterialsRef = useRef(null);
  const lockedMaterialsRef = useRef(null);
  const previousLockedRef = useRef(null);
  const tooltipElRef = useRef(null);
  const activeClusterPopupRef = useRef(null);

  // Keep stable refs to context values so the mount effect never re-runs
  const lockVolcanoRef = useRef(lockVolcano);
  const unlockVolcanoRef = useRef(unlockVolcano);
  const setIsLoadedRef = useRef(setIsLoaded);
  const activeClusterPopupRefStable = activeClusterPopupRef;
  useEffect(() => { lockVolcanoRef.current = lockVolcano; }, [lockVolcano]);
  useEffect(() => { unlockVolcanoRef.current = unlockVolcano; }, [unlockVolcano]);
  useEffect(() => { setIsLoadedRef.current = setIsLoaded; }, [setIsLoaded]);

  // ── MAIN MOUNT EFFECT ──────────────────────────────────────────────────────
  useEffect(() => {
    if (!mountRef.current || globeRef.current) return;

    // Globe.gl and THREE are on window (CDN script tags in index.html)
    const Globe = window.Globe;
    const THREE = window.THREE;

    // ── Materials ──────────────────────────────────────────────────────────
    const bodyMaterial = new THREE.MeshLambertMaterial({
      color: 0x4a2818,
      emissive: 0x1a0a05,
      emissiveIntensity: 0.3,
      flatShading: true,
    });

    const STATUS_PALETTE = {
      Active:  { core: 0xff5722, glow: 0xff8c42 },
      Dormant: { core: 0x00e5ff, glow: 0x4dd0e1 },
      Extinct: { core: 0x9e9e9e, glow: 0xbdbdbd },
    };
    const LOCKED_PEAK = { core: 0xffffff, glow: 0xffd54f };

    function makePeakMaterials(palette) {
      return {
        core: new THREE.MeshBasicMaterial({ color: palette.core, transparent: true, opacity: 0.95 }),
        glow: new THREE.MeshBasicMaterial({ color: palette.glow, transparent: true, opacity: 0.4, side: THREE.BackSide }),
      };
    }

    const STATUS_MATERIALS = Object.fromEntries(
      Object.entries(STATUS_PALETTE).map(([k, v]) => [k, makePeakMaterials(v)])
    );
    const LOCKED_MATERIALS = makePeakMaterials(LOCKED_PEAK);
    statusMaterialsRef.current = STATUS_MATERIALS;
    lockedMaterialsRef.current = LOCKED_MATERIALS;

    // ── Importance + marker builder ────────────────────────────────────────
    const importanceFactor = (d) => {
      const veiBoost = Math.pow((d.vei || 0) + 1, 1.4) * 0.18;
      const baseSize = d.notable ? 0.5 : 0.32;
      return baseSize + veiBoost;
    };

    function buildVolcanoMarker(d) {
      const group = new THREE.Group();
      group.userData = { ...d };
      group.userData._importance = importanceFactor(d);
      const importance = group.userData._importance;
      const bodyHeight = 1.1 * importance;
      const bodyRadius = 0.4 * importance;
      const mats = STATUS_MATERIALS[d.status] || STATUS_MATERIALS.Active;

      const body = new THREE.Mesh(new THREE.ConeGeometry(bodyRadius, bodyHeight, 8, 1, false), bodyMaterial);
      body.position.y = bodyHeight / 2;
      group.add(body);

      const peak = new THREE.Mesh(new THREE.SphereGeometry(0.15 * importance, 12, 12), mats.core);
      peak.position.y = bodyHeight + 0.04;
      peak.userData._role = 'peak';
      group.add(peak);

      const halo = new THREE.Mesh(new THREE.SphereGeometry(0.30 * importance, 16, 16), mats.glow);
      halo.position.y = bodyHeight + 0.04;
      halo.userData._role = 'halo';
      group.add(halo);

      return group;
    }

    // ── Globe.gl init ──────────────────────────────────────────────────────
    const globe = Globe()(mountRef.current)
      .globeImageUrl('https://unpkg.com/three-globe/example/img/earth-blue-marble.jpg')
      .bumpImageUrl('https://unpkg.com/three-globe/example/img/earth-topology.png')
      .backgroundImageUrl('https://unpkg.com/three-globe/example/img/night-sky.png')
      .atmosphereColor('#ffb38a')
      .atmosphereAltitude(0.16)
      .showGraticules(false);

    globeRef.current = globe;

    // ── Cone markers via customLayer ───────────────────────────────────────
    function computeZoomFactor() {
      const camDist = globe.camera().position.length() / 100;
      if (!isFinite(camDist) || camDist <= 0) return 1;
      return Math.max(1, Math.min(4.5, camDist));
    }

    globe
      .customLayerData(volcanoes)
      .customThreeObject(buildVolcanoMarker)
      .customThreeObjectUpdate((obj, d) => {
        if (!d || d.lat === undefined || d.lng === undefined) return;
        const coords = globe.getCoords(d.lat, d.lng, 0.005);
        if (!coords || !isFinite(coords.x)) return;
        Object.assign(obj.position, coords);
        obj.lookAt(0, 0, 0);
        obj.rotateX(-Math.PI / 2);
        obj.scale.setScalar(computeZoomFactor());
      });

    // ── Zoom-based cone rescaling ──────────────────────────────────────────
    let zoomRefreshQueued = false;
    globe.controls().addEventListener('change', () => {
      if (zoomRefreshQueued) return;
      zoomRefreshQueued = true;
      requestAnimationFrame(() => {
        zoomRefreshQueued = false;
        const zoomFactor = computeZoomFactor();
        globe.scene().traverse((obj) => {
          if (obj.userData && obj.userData.lat !== undefined && obj.userData._importance !== undefined) {
            obj.scale.setScalar(zoomFactor);
          }
        });
        updateClusterVisibility();
      });
    });

    // ── Seismic pulse rings ────────────────────────────────────────────────
    const RING_STYLE = (d) => {
      const v = d.vei || 0;
      if (v >= 7) return { color: [255, 87, 34],  radius: 6.0, speed: 3.5, period: 1100, alphaMax: 1.0 };
      if (v >= 4) return { color: [255, 193, 7],  radius: 3.5, speed: 2.2, period: 1700, alphaMax: 0.85 };
      return            { color: [255, 255, 255], radius: 1.8, speed: 1.4, period: 2400, alphaMax: 0.4 };
    };

    globe
      .ringsData([])
      .ringLat('lat').ringLng('lng')
      .ringMaxRadius(d => RING_STYLE(d).radius)
      .ringPropagationSpeed(d => RING_STYLE(d).speed)
      .ringRepeatPeriod(d => RING_STYLE(d).period)
      .ringColor(d => {
        const s = RING_STYLE(d);
        const [r, g, b] = s.color;
        return t => `rgba(${r}, ${g}, ${b}, ${(1 - t) * s.alphaMax})`;
      })
      .ringAltitude(0.005);

    // ── Clustering ────────────────────────────────────────────────────────
    function haversineKm(lat1, lng1, lat2, lng2) {
      const toRad = d => d * Math.PI / 180;
      const R = 6371;
      const dLat = toRad(lat2 - lat1);
      const dLng = toRad(lng2 - lng1);
      const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
      return 2 * R * Math.asin(Math.sqrt(a));
    }

    function buildClusters(volcanoes, thresholdKm = 400) {
      const clusters = [];
      for (const v of volcanoes) {
        const existing = clusters.find(c => haversineKm(c.lat, c.lng, v.lat, v.lng) < thresholdKm);
        if (existing) {
          existing.members.push(v);
          const totalW = existing.members.reduce((s, m) => s + (m.vei || 0) + 1, 0);
          existing.lat = existing.members.reduce((s, m) => s + m.lat * ((m.vei || 0) + 1), 0) / totalW;
          existing.lng = existing.members.reduce((s, m) => s + m.lng * ((m.vei || 0) + 1), 0) / totalW;
        } else {
          clusters.push({ lat: v.lat, lng: v.lng, members: [v] });
        }
      }

      const labelCounts = {};
      for (const c of clusters.filter(c => c.members.length > 1)) {
        const regions = {};
        const countries = {};
        for (const m of c.members) {
          regions[m.region] = (regions[m.region] || 0) + 1;
          countries[m.country] = (countries[m.country] || 0) + 1;
        }
        const topRegion = Object.entries(regions).sort((a, b) => b[1] - a[1])[0][0];
        const topCountry = Object.entries(countries).sort((a, b) => b[1] - a[1])[0][0];
        let label = topRegion || topCountry;
        labelCounts[label] = (labelCounts[label] || 0) + 1;
        c.regionLabel = labelCounts[label] > 1 ? `${label} (${topCountry})` : label;
      }
      return clusters.filter(c => c.members.length > 1);
    }

    const CLUSTERS = buildClusters(volcanoes, 400);

    // Cluster cone markers in Three.js scene (NOT in customLayer)
    const clusterCones = [];
    for (const cluster of CLUSTERS) {
      const group = new THREE.Group();
      group.userData._isClusterCone = true;
      group.userData.lat = cluster.lat;
      group.userData.lng = cluster.lng;

      const sizeFactor = 1.5 + Math.log(cluster.members.length) * 1.4;
      const bodyHeight = 1.1 * sizeFactor;
      const bodyRadius = 0.4 * sizeFactor;

      const body = new THREE.Mesh(new THREE.ConeGeometry(bodyRadius, bodyHeight, 8, 1, false), bodyMaterial);
      body.position.y = bodyHeight / 2;
      group.add(body);

      const dominantMember = cluster.members.slice().sort((a, b) => (b.vei || 0) - (a.vei || 0))[0];
      const mats = STATUS_MATERIALS[dominantMember.status] || STATUS_MATERIALS.Active;

      const peak = new THREE.Mesh(new THREE.SphereGeometry(0.15 * sizeFactor, 12, 12), mats.core);
      peak.position.y = bodyHeight + 0.04;
      peak.userData._role = 'peak';
      group.add(peak);

      const halo = new THREE.Mesh(new THREE.SphereGeometry(0.30 * sizeFactor, 16, 16), mats.glow);
      halo.position.y = bodyHeight + 0.04;
      halo.userData._role = 'halo';
      group.add(halo);

      const coords = globe.getCoords(cluster.lat, cluster.lng, 0.005);
      Object.assign(group.position, coords);
      group.lookAt(0, 0, 0);
      group.rotateX(-Math.PI / 2);
      globe.scene().add(group);
      clusterCones.push({ group, cluster });
    }

    // Cluster HTML label elements via Globe.gl htmlElementsLayer
    function buildClusterEl(cluster) {
      const el = document.createElement('div');
      el.className = 'cluster-marker';
      const maxVei = Math.max(...cluster.members.map(m => m.vei || 0));
      const tier = maxVei >= 7 ? 'cataclysmic' : maxVei >= 4 ? 'significant' : 'minor';
      el.innerHTML = `<div class="cluster-badge cluster-badge-${tier}">${cluster.members.length}</div>`;
      el.addEventListener('click', (e) => {
        e.stopPropagation();
        openClusterPopup(cluster, el);
      });
      return el;
    }

    globe
      .htmlElementsData(CLUSTERS)
      .htmlLat('lat').htmlLng('lng').htmlAltitude(0.02)
      .htmlElement(buildClusterEl);

    // Cluster visibility based on camera altitude
    function updateClusterVisibility() {
      const cam = globe.camera();
      const camDist = cam.position.length() / 100;
      const opacity = Math.max(0, Math.min(1, (camDist - 1.0) / 1.0));

      const htmlEls = mountRef.current?.querySelectorAll('.cluster-marker') ?? [];
      htmlEls.forEach(el => { el.style.opacity = opacity; });

      clusterCones.forEach(({ group }) => { group.visible = opacity < 0.05; });
    }

    // ── Raycaster + hover tooltip ──────────────────────────────────────────
    const raycaster = new THREE.Raycaster();
    const mouseNDC = new THREE.Vector2();
    let hoveredVolcano = null;

    const tooltipEl = document.createElement('div');
    tooltipEl.className = 'globe-tooltip-container';
    tooltipEl.style.cssText = 'position:fixed;pointer-events:none;z-index:5;display:none;';
    document.body.appendChild(tooltipEl);
    tooltipElRef.current = tooltipEl;

    function pickVolcano(clientX, clientY) {
      const rect = mountRef.current.getBoundingClientRect();
      mouseNDC.x = ((clientX - rect.left) / rect.width) * 2 - 1;
      mouseNDC.y = -((clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(mouseNDC, globe.camera());
      const hits = raycaster.intersectObjects(globe.scene().children, true);
      for (const hit of hits) {
        let obj = hit.object;
        while (obj) {
          if (obj.userData && obj.userData.lat !== undefined && !obj.userData._isClusterCone) {
            return obj.userData;
          }
          obj = obj.parent;
        }
      }
      return null;
    }

    function paintMarker(volcano, mats) {
      globe.scene().traverse((obj) => {
        if (!obj.userData || obj.userData.lat !== volcano.lat ||
            obj.userData.lng !== volcano.lng || obj.userData.id !== volcano.id) return;
        obj.children.forEach(child => {
          if (child.userData?._role === 'peak') child.material = mats.core;
          if (child.userData?._role === 'halo') child.material = mats.glow;
        });
      });
    }

    function handleVolcanoClick(volcano) {
      globe.controls().autoRotate = false;
      globe.pointOfView({ lat: volcano.lat, lng: volcano.lng, altitude: 0.5 }, 2000);
      lockVolcanoRef.current(volcano);
    }

    // Cluster popup (DOM-managed, same as original)
    function openClusterPopup(cluster, anchorEl) {
      closeClusterPopup();
      const popup = document.createElement('div');
      popup.className = 'cluster-popup';
      const sorted = [...cluster.members].sort((a, b) => (b.vei || 0) - (a.vei || 0) || a.name.localeCompare(b.name));
      popup.innerHTML = `
        <div class="cluster-popup-header">
          <span class="cluster-popup-title">${cluster.regionLabel}</span>
          <span class="cluster-popup-count">${cluster.members.length} sites</span>
          <button class="cluster-popup-close" aria-label="Close">×</button>
        </div>
        <ul class="cluster-popup-list">
          ${sorted.map((v, i) => `
            <li class="cluster-popup-item" data-index="${i}">
              <span class="cluster-popup-icon"></span>
              <div class="cluster-popup-text">
                <div class="cluster-popup-name">${v.name}</div>
                <div class="cluster-popup-meta">${v.type} · VEI ${v.vei || 0} · ${v.status}</div>
              </div>
            </li>
          `).join('')}
        </ul>
      `;
      document.body.appendChild(popup);
      const rect = anchorEl.getBoundingClientRect();
      const popupW = 280;
      const goLeft = rect.right + popupW + 16 > window.innerWidth;
      popup.style.left = (goLeft ? rect.left - popupW - 12 : rect.right + 12) + 'px';
      popup.style.top = Math.max(20, rect.top - 8) + 'px';
      requestAnimationFrame(() => popup.classList.add('visible'));
      popup.querySelector('.cluster-popup-close').addEventListener('click', closeClusterPopup);
      popup.querySelectorAll('.cluster-popup-item').forEach(li => {
        li.addEventListener('click', () => {
          const v = sorted[Number(li.dataset.index)];
          closeClusterPopup();
          handleVolcanoClick(v);
        });
      });
      activeClusterPopupRefStable.current = popup;
      popup._cluster = cluster;
      popup._anchor = anchorEl;
    }

    function closeClusterPopup() {
      const p = activeClusterPopupRefStable.current;
      if (!p) return;
      activeClusterPopupRefStable.current = null;
      p.classList.remove('visible');
      setTimeout(() => p.remove(), 200);
    }

    document.addEventListener('click', (e) => {
      if (activeClusterPopupRefStable.current &&
          !activeClusterPopupRefStable.current.contains(e.target) &&
          !e.target.closest('.cluster-marker')) {
        closeClusterPopup();
      }
    });

    // Mouse events
    mountRef.current.addEventListener('mousemove', (e) => {
      if (e.target.closest('.cluster-marker') || e.target.closest('.cluster-popup')) {
        if (hoveredVolcano) { hoveredVolcano = null; tooltipEl.style.display = 'none'; }
        return;
      }
      const v = pickVolcano(e.clientX, e.clientY);
      if (v) {
        hoveredVolcano = v;
        mountRef.current.style.cursor = 'pointer';
        tooltipEl.style.display = 'block';
        tooltipEl.style.left = (e.clientX + 14) + 'px';
        tooltipEl.style.top = (e.clientY - 8) + 'px';
        tooltipEl.innerHTML = `<div class="globe-tooltip"><span class="tt-label">${v.notable ? '◆ Notable' : 'Site'}</span> ${v.name}</div>`;
      } else if (hoveredVolcano) {
        hoveredVolcano = null;
        mountRef.current.style.cursor = 'grab';
        tooltipEl.style.display = 'none';
      }
    });

    mountRef.current.addEventListener('click', (e) => {
      if (e.target.closest('.cluster-marker') || e.target.closest('.cluster-popup')) return;
      const v = pickVolcano(e.clientX, e.clientY);
      if (v) handleVolcanoClick(v);
    });

    mountRef.current.addEventListener('mouseleave', () => {
      tooltipEl.style.display = 'none';
      hoveredVolcano = null;
    });

    // ── Lighting ──────────────────────────────────────────────────────────
    const ambientLight = new THREE.AmbientLight(0xffeedd, 0.9);
    globe.scene().add(ambientLight);
    const fillLight = new THREE.DirectionalLight(0xffd9b3, 0.4);
    fillLight.position.set(-1, 0.5, -1);
    globe.scene().add(fillLight);

    // ── Auto-rotate + resize ──────────────────────────────────────────────
    globe.controls().autoRotate = true;
    globe.controls().autoRotateSpeed = 0.35;
    globe.controls().enableDamping = true;

    const resize = () => {
      globe.width(window.innerWidth);
      globe.height(window.innerHeight);
    };
    window.addEventListener('resize', resize);

    // ── Initial camera position ──────────────────────────────────────────
    globe.pointOfView({ lat: 20, lng: 15, altitude: 2.5 });

    // ── Globe ready ───────────────────────────────────────────────────────
    // Wait for first render frame, then fire two rAF to ensure cones are placed
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        updateClusterVisibility();
        setIsLoadedRef.current(true);
      });
    });

    // Expose paintMarker and closeClusterPopup for the selection effect below
    globeRef._paintMarker = paintMarker;
    globeRef._closeClusterPopup = closeClusterPopup;
    globeRef._STATUS_MATERIALS = STATUS_MATERIALS;
    globeRef._LOCKED_MATERIALS = LOCKED_MATERIALS;

    return () => {
      window.removeEventListener('resize', resize);
      if (tooltipElRef.current) tooltipElRef.current.remove();
    };
  }, []); // mount once

  // ── SELECTION EFFECT: react to selectedVolcano changes ─────────────────
  useEffect(() => {
    if (!globeRef.current) return;
    const paintMarker = globeRef._paintMarker;
    const STATUS_MATERIALS = globeRef._STATUS_MATERIALS;
    const LOCKED_MATERIALS = globeRef._LOCKED_MATERIALS;
    if (!paintMarker) return;

    if (previousLockedRef.current && previousLockedRef.current !== selectedVolcano) {
      paintMarker(
        previousLockedRef.current,
        STATUS_MATERIALS[previousLockedRef.current.status] || STATUS_MATERIALS.Active
      );
    }

    if (selectedVolcano) {
      paintMarker(selectedVolcano, LOCKED_MATERIALS);
      globeRef.current.controls().autoRotate = false;
      globeRef.current.pointOfView({ lat: selectedVolcano.lat, lng: selectedVolcano.lng, altitude: 0.5 }, 2000);
    }

    previousLockedRef.current = selectedVolcano;
  }, [selectedVolcano]);

  // ── SEARCH EFFECT: react to searchQuery changes ─────────────────────────
  useEffect(() => {
    if (!globeRef.current) return;
    const term = searchQuery.trim().toLowerCase();

    if (!term) {
      globeRef.current.scene().traverse((obj) => {
        const ud = obj.userData;
        if (ud && ud._importance !== undefined && ud.id) obj.visible = true;
      });
      return;
    }

    const matched = filterVolcanoes(
      Array.from({ length: 0 }, () => {}), // placeholder — built from scene
      term
    );
    const matchedIds = new Set(
      globeRef.current.scene().children
        .flatMap(obj => {
          const results = [];
          obj.traverse(child => {
            const ud = child.userData;
            if (ud && ud.id && ud._importance !== undefined) {
              const fields = [ud.name, ud.country, ud.region, ud.type];
              if (fields.some(s => s && s.toLowerCase().includes(term))) results.push(ud.id);
            }
          });
          return results;
        })
    );

    globeRef.current.scene().traverse((obj) => {
      const ud = obj.userData;
      if (!ud || ud._importance === undefined || !ud.id) return;
      obj.visible = matchedIds.has(ud.id);
    });
  }, [searchQuery]);
}
```

> **Implementation note on the search effect:** The search effect above traverses the Three.js scene to build matched IDs from userData directly — this avoids importing VOLCANO_DATA into the hook. If traversal proves unreliable, replace the `matchedIds` building with: `import { VOLCANO_DATA } from '../data/volcanoes'; import { filterVolcanoes } from './useSearch';` and `const matchedIds = new Set(filterVolcanoes(VOLCANO_DATA, term).map(v => v.id));` — this is simpler and more reliable.

- [ ] **Step 2: Commit**

```
git add src/hooks/useGlobe.js
git commit -m "feat: add useGlobe hook (Globe.gl init, markers, clustering, raycasting)"
```

---

## Task 9: GlobeContainer

**Files:**
- Create: `src/components/GlobeContainer/GlobeContainer.jsx`

- [ ] **Step 1: Create GlobeContainer.jsx**

Create `magmascope/src/components/GlobeContainer/GlobeContainer.jsx`:
```jsx
import { useRef } from 'react';
import { useGlobeContext } from '../../context/GlobeContext';
import { VOLCANO_DATA } from '../../data/volcanoes';
import { useGlobe } from '../../hooks/useGlobe';

export default function GlobeContainer() {
  const mountRef = useRef(null);
  const { lockVolcano, unlockVolcano, setIsLoaded, selectedVolcano, searchQuery } = useGlobeContext();

  useGlobe(mountRef, VOLCANO_DATA, {
    lockVolcano,
    unlockVolcano,
    setIsLoaded,
    selectedVolcano,
    searchQuery,
  });

  return <div id="globeViz" ref={mountRef} />;
}
```

- [ ] **Step 2: Commit**

```
git add src/components/GlobeContainer/
git commit -m "feat: add GlobeContainer (mounts useGlobe)"
```

---

## Task 10: Header component CSS

**Files:**
- Create: `src/components/Header/Header.css`
- Create: `src/components/SearchBar/SearchBar.css`

Extract header and search CSS from source file.

- [ ] **Step 1: Create Header.css**

Create `magmascope/src/components/Header/Header.css`. Open `volcano-globe (7).html` and copy the `.header`, `.brand`, `.brand-dot`, `.title`, `.title-eyebrow`, `.title-main`, `.stats`, `.footer` CSS rules plus `@keyframes pulse-dot` (approximately lines 136–413):
```css
/* (copy .header through .stats rules and @keyframes pulse-dot from source) */
```

> **Copy instruction:** Open `volcano-globe (7).html`. Search for `.header {` (approximately line 139). Copy all rules from `.header` through `.stats-value` (approximately line 398). Also copy the `.footer` and `.footer kbd` rules (approximately lines 403–425). Paste verbatim into `Header.css`.

- [ ] **Step 2: Create SearchBar.css**

Create `magmascope/src/components/SearchBar/SearchBar.css`. Copy all search-related CSS from the source (approximately lines 193–383):
```css
/* (copy .search-container through .suggestion-empty from source) */
```

> **Copy instruction:** Open `volcano-globe (7).html`. Search for `.search-container {` (approximately line 200). Copy all rules from `.search-container` through `.suggestion-empty` (approximately line 384). Paste verbatim into `SearchBar.css`.

- [ ] **Step 3: Commit**

```
git add src/components/Header/Header.css src/components/SearchBar/SearchBar.css
git commit -m "feat: add Header and SearchBar CSS"
```

---

## Task 11: Header + SearchBar components

**Files:**
- Create: `src/components/Header/Header.jsx`
- Create: `src/components/SearchBar/SearchBar.jsx`

- [ ] **Step 1: Create Header.jsx**

Create `magmascope/src/components/Header/Header.jsx`:
```jsx
import { useLanguage } from '../../context/LanguageContext';
import { t } from '../../data/i18n';
import SearchBar from '../SearchBar/SearchBar';
import Stats from '../Stats/Stats';
import './Header.css';

export default function Header() {
  const { currentLang } = useLanguage();
  return (
    <header className="header">
      <div className="brand">
        <span className="brand-dot" aria-hidden="true"></span>
        <span>{t('brand', currentLang)} · {t('live', currentLang)}</span>
      </div>
      <div className="title">
        <div className="title-eyebrow">{t('title.eyebrow', currentLang)}</div>
        <div className="title-main">{t('title.main', currentLang)}</div>
        <SearchBar />
      </div>
      <Stats />
    </header>
  );
}
```

- [ ] **Step 2: Create SearchBar.jsx**

Create `magmascope/src/components/SearchBar/SearchBar.jsx`:
```jsx
import { useRef, useState } from 'react';
import { useGlobeContext } from '../../context/GlobeContext';
import { useLanguage } from '../../context/LanguageContext';
import { t, tFallback } from '../../data/i18n';
import { scoreSuggestions, highlightMatch } from '../../hooks/useSearch';
import { VOLCANO_DATA } from '../../data/volcanoes';
import './SearchBar.css';

export default function SearchBar() {
  const { lockVolcano, setSearchQuery } = useGlobeContext();
  const { currentLang } = useLanguage();
  const [inputValue, setInputValue] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [activeIdx, setActiveIdx] = useState(-1);
  const [hasValue, setHasValue] = useState(false);
  const [noResults, setNoResults] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const inputRef = useRef(null);

  function applyInput(value) {
    setInputValue(value);
    setHasValue(value.length > 0);
    setSearchQuery(value);

    const scored = scoreSuggestions(VOLCANO_DATA, value);
    setSuggestions(scored);
    setActiveIdx(scored.length > 0 ? 0 : -1);
    setNoResults(value.trim().length > 0 && scored.length === 0);
    setShowSuggestions(value.trim().length > 0);
  }

  function selectVolcano(volcano) {
    if (!volcano) return;
    setInputValue('');
    setHasValue(false);
    setNoResults(false);
    setShowSuggestions(false);
    setSuggestions([]);
    setSearchQuery('');
    inputRef.current?.blur();
    lockVolcano(volcano);
  }

  function handleKeyDown(e) {
    if (!showSuggestions || !suggestions.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActiveIdx(i => (i + 1) % suggestions.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActiveIdx(i => (i - 1 + suggestions.length) % suggestions.length);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      selectVolcano(suggestions[activeIdx] ?? suggestions[0]);
    } else if (e.key === 'Escape') {
      setShowSuggestions(false);
    }
  }

  const containerClass = [
    'search-container',
    hasValue ? 'has-value' : '',
    noResults ? 'no-results' : '',
    showSuggestions && suggestions.length > 0 ? 'has-suggestions' : '',
  ].filter(Boolean).join(' ');

  const term = inputValue.trim().toLowerCase();

  return (
    <div className={containerClass}>
      <span className="search-icon" aria-hidden="true">⌕</span>
      <input
        ref={inputRef}
        type="text"
        id="volcanoSearch"
        value={inputValue}
        placeholder={t('search.placeholder', currentLang)}
        autoComplete="off"
        spellCheck="false"
        aria-label={t('search.ariaLabel', currentLang)}
        aria-autocomplete="list"
        aria-controls="searchSuggestions"
        onChange={e => applyInput(e.target.value)}
        onFocus={() => { if (inputValue.trim()) setShowSuggestions(true); }}
        onKeyDown={handleKeyDown}
      />
      <button
        className="search-clear"
        id="searchClear"
        aria-label="Clear search"
        tabIndex={-1}
        onClick={() => applyInput('')}
      >×</button>
      <ul className="search-suggestions" id="searchSuggestions" role="listbox" aria-label="Volcano suggestions">
        {showSuggestions && suggestions.length === 0 && (
          <li className="suggestion-empty">No volcanoes match that query</li>
        )}
        {showSuggestions && suggestions.map((v, i) => (
          <li
            key={v.id}
            className={`search-suggestion${i === activeIdx ? ' active' : ''}`}
            role="option"
            data-index={i}
            onClick={() => selectVolcano(v)}
          >
            <span className={`suggestion-icon${v.notable ? '' : ' dim'}`}></span>
            <div className="suggestion-text">
              <div
                className="suggestion-name"
                dangerouslySetInnerHTML={{ __html: highlightMatch(v.name, term) }}
              />
              <div
                className="suggestion-meta"
                dangerouslySetInnerHTML={{
                  __html: `${highlightMatch(tFallback('country', v.country, currentLang), term)} · ${highlightMatch(tFallback('type', v.type, currentLang), term)}`
                }}
              />
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```
git add src/components/Header/ src/components/SearchBar/
git commit -m "feat: add Header and SearchBar components"
```

---

## Task 12: InfoPanel CSS + SafetySection component

**Files:**
- Create: `src/components/InfoPanel/InfoPanel.css`
- Create: `src/components/InfoPanel/SafetySection.css`
- Create: `src/components/InfoPanel/SafetySection.jsx`

- [ ] **Step 1: Create InfoPanel.css**

Create `magmascope/src/components/InfoPanel/InfoPanel.css`. Open `volcano-globe (7).html` and copy the `.info-panel`, `.panel-inner`, `.panel-*`, `.close-btn`, `.volcano-*`, `.meta-*`, `.data-*`, `.desc-*`, `.eruption-*`, `.volcano-img-*`, `.panel-hero*` CSS rules (approximately lines 725–830):
```css
/* (copy all info-panel related CSS from source file) */
```

> **Copy instruction:** Open `volcano-globe (7).html`. Search for `.info-panel {` (approximately line 725). Copy all panel-related rules through the end of `.panel-hero` image rules (approximately line 830). Also copy the `.chip` and `.chip-*` rules from the same area. Paste verbatim into `InfoPanel.css`.

- [ ] **Step 2: Create SafetySection.css**

Create `magmascope/src/components/InfoPanel/SafetySection.css`. Open `volcano-globe (7).html` and search for `.safety-block` (approximately line 663). Copy all `.safety-*` rules:
```css
/* (copy all .safety-block, .safety-row, .safety-label, .safety-tag, .safety-agency, .safety-advice from source) */
```

> **Copy instruction:** Open `volcano-globe (7).html`. Search for the `SAFETY SECTION` CSS comment (approximately line 663). Copy all `.safety-*` rules through `.safety-advice`. Paste verbatim into `SafetySection.css`.

- [ ] **Step 3: Create SafetySection.jsx**

Create `magmascope/src/components/InfoPanel/SafetySection.jsx`:
```jsx
import { useLanguage } from '../../context/LanguageContext';
import { t, tFallback } from '../../data/i18n';
import { MONITORING_AGENCIES, HAZARDS_BY_TYPE } from '../../data/monitoring';
import './SafetySection.css';

export default function SafetySection({ volcano }) {
  const { currentLang } = useLanguage();

  if (!volcano) return null;
  if (volcano.status === 'Extinct' && !volcano.notable) return null;

  const hazards = HAZARDS_BY_TYPE[volcano.type] || [];
  const agency = MONITORING_AGENCIES[volcano.country];

  return (
    <div className="panel-section safety-block">
      <div className="safety-eyebrow">{t('panel.safety', currentLang)}</div>
      {hazards.length > 0 && (
        <div className="safety-row">
          <span className="safety-label">{t('panel.hazards', currentLang)}</span>
          {hazards.map(h => (
            <span key={h} className="safety-tag">{t('hazard.' + h, currentLang)}</span>
          ))}
        </div>
      )}
      <div className="safety-row">
        <span className="safety-label">{t('panel.monitoring', currentLang)}</span>
        <span className="safety-agency">
          {agency ? (
            agency.url
              ? <a href={agency.url} target="_blank" rel="noopener noreferrer">{agency.name}</a>
              : agency.name
          ) : t('panel.unmonitored', currentLang)}
        </span>
      </div>
      <div className="safety-advice">
        {volcano.status === 'Extinct'
          ? t('panel.adviceExtinct', currentLang)
          : t('panel.advice', currentLang)}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Commit**

```
git add src/components/InfoPanel/InfoPanel.css src/components/InfoPanel/SafetySection.css src/components/InfoPanel/SafetySection.jsx
git commit -m "feat: add InfoPanel CSS and SafetySection component"
```

---

## Task 13: InfoPanel component

**Files:**
- Create: `src/components/InfoPanel/InfoPanel.jsx`

The panel image cache lives as a module-level Map (not React state) so it persists across renders.

- [ ] **Step 1: Create InfoPanel.jsx**

Create `magmascope/src/components/InfoPanel/InfoPanel.jsx`:
```jsx
import { useEffect, useState } from 'react';
import { useGlobeContext } from '../../context/GlobeContext';
import { useLanguage } from '../../context/LanguageContext';
import { t, tFallback } from '../../data/i18n';
import SafetySection from './SafetySection';
import './InfoPanel.css';

const imageCache = new Map();

async function fetchVolcanoImage(wikiTitle) {
  if (!wikiTitle) return null;
  if (imageCache.has(wikiTitle)) return imageCache.get(wikiTitle);
  try {
    const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(wikiTitle)}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    const imgUrl = data.originalimage?.source || data.thumbnail?.source || null;
    imageCache.set(wikiTitle, imgUrl);
    return imgUrl;
  } catch (err) {
    console.warn(`[Magmascope] Could not fetch image for "${wikiTitle}":`, err);
    imageCache.set(wikiTitle, null);
    return null;
  }
}

export default function InfoPanel() {
  const { selectedVolcano, unlockVolcano } = useGlobeContext();
  const { currentLang } = useLanguage();
  const [heroUrl, setHeroUrl] = useState(null);
  const [heroLoaded, setHeroLoaded] = useState(false);

  useEffect(() => {
    if (!selectedVolcano?.wikiTitle) {
      setHeroUrl(null);
      setHeroLoaded(false);
      return;
    }
    setHeroUrl(null);
    setHeroLoaded(false);
    fetchVolcanoImage(selectedVolcano.wikiTitle).then(url => {
      if (!url) return;
      const img = new Image();
      img.onload = () => { setHeroUrl(url); setHeroLoaded(true); };
      img.onerror = () => {};
      img.src = url;
    });
  }, [selectedVolcano]);

  function handleClose() {
    unlockVolcano();
  }

  const v = selectedVolcano;
  const isActive = !!v;

  const fmtLat = v ? `${Math.abs(v.lat).toFixed(3)}° ${v.lat >= 0 ? 'N' : 'S'}` : '';
  const fmtLng = v ? `${Math.abs(v.lng).toFixed(3)}° ${v.lng >= 0 ? 'E' : 'W'}` : '';

  return (
    <aside
      className={`info-panel${isActive ? ' active' : ''}${v?.notable ? ' is-notable' : ''}`}
      id="infoPanel"
      aria-hidden={!isActive}
    >
      {v && (
        <div className="panel-inner" id="panelInner">
          <div className="panel-hero" id="panelHero">
            {heroUrl && (
              <img
                className={`panel-hero-img${heroLoaded ? ' loaded' : ''}`}
                id="panelHeroImg"
                src={heroUrl}
                alt=""
              />
            )}
            {heroLoaded && (
              <span className="panel-hero-credit visible" id="panelHeroCredit">
                {t('panel.photoCredit', currentLang)}
              </span>
            )}
          </div>

          <div className="panel-header">
            <span className="panel-tag">
              {t('panel.record', currentLang)} · {v.id.toUpperCase()}
            </span>
            <button className="close-btn" id="closePanel" aria-label="Close panel" onClick={handleClose}>
              ×
            </button>
          </div>

          <div className="panel-section">
            <h2 className="volcano-name">{v.name}</h2>
            <div className="volcano-location">
              {v.region} · {tFallback('country', v.country, currentLang)}
            </div>
            <div className="status-row">
              <span className="chip chip-active">{tFallback('status', v.status, currentLang)}</span>
              <span className="chip">{tFallback('type', v.type, currentLang)}</span>
              {v.notable && (
                <span className="chip chip-notable">{t('panel.historic', currentLang)}</span>
              )}
            </div>
          </div>

          <div className="panel-section eruption-block">
            <div className="eruption-label">{t('panel.lastEruption', currentLang)}</div>
            <div className="eruption-value">{v.lastEruption}</div>
          </div>

          <div className="panel-section data-grid">
            <div className="data-cell">
              <div className="data-label">{t('panel.latitude', currentLang)}</div>
              <div className="data-value">{fmtLat}</div>
            </div>
            <div className="data-cell">
              <div className="data-label">{t('panel.longitude', currentLang)}</div>
              <div className="data-value">{fmtLng}</div>
            </div>
            <div className="data-cell">
              <div className="data-label">{t('panel.elevation', currentLang)}</div>
              <div className="data-value">{v.elevation.toLocaleString()} m</div>
            </div>
            <div className="data-cell">
              <div className="data-label">{t('panel.vei', currentLang)}</div>
              <div className="data-value data-value-accent">{v.vei} / 8</div>
            </div>
          </div>

          <SafetySection volcano={v} />

          {v.notable && v.description && (
            <div className="panel-section description-block">
              <div className="description-eyebrow">Historical Significance</div>
              {v.description.map((p, i) => (
                <p key={i} className="description-text">{p}</p>
              ))}
            </div>
          )}
        </div>
      )}
    </aside>
  );
}
```

- [ ] **Step 2: Commit**

```
git add src/components/InfoPanel/InfoPanel.jsx
git commit -m "feat: add InfoPanel component with hero image + Wikipedia fetch"
```

---

## Task 14: Legend + LegendInfoCard

**Files:**
- Create: `src/components/Legend/Legend.css`
- Create: `src/components/Legend/LegendInfoCard.css`
- Create: `src/components/Legend/LegendInfoCard.jsx`
- Create: `src/components/Legend/Legend.jsx`

- [ ] **Step 1: Create Legend.css**

Create `magmascope/src/components/Legend/Legend.css`. Open `volcano-globe (7).html` and copy the `.legend`, `.legend-title`, `.legend-item`, `.legend-dot`, `.legend-label`, `.legend-sub`, `.legend-dot-cataclysmic`, `.legend-dot-significant`, `.legend-dot-minor`, `.legend-info-btn` CSS rules plus their `@keyframes` (approximately lines 426–662):
```css
/* (copy all legend CSS from source file) */
```

> **Copy instruction:** Open `volcano-globe (7).html`. Search for `.legend {` (approximately line 429). Copy all rules from `.legend` through `.legend-info-btn` and all associated `@keyframes pulse-cataclysmic` and `@keyframes pulse-significant`. Paste verbatim into `Legend.css`.

- [ ] **Step 2: Create LegendInfoCard.css**

Create `magmascope/src/components/Legend/LegendInfoCard.css`. Open `volcano-globe (7).html` and copy the `.legend-info-card`, `.legend-info-*`, `.swatch-*` CSS rules (approximately lines 1036–1066):
```css
/* (copy all legend-info-card CSS from source file) */
```

> **Copy instruction:** Open `volcano-globe (7).html`. Search for `.legend-info-card {` (approximately line 1036). Copy all rules through `.swatch-extinct`. Paste verbatim into `LegendInfoCard.css`.

- [ ] **Step 3: Create LegendInfoCard.jsx**

Create `magmascope/src/components/Legend/LegendInfoCard.jsx`:
```jsx
import { useLanguage } from '../../context/LanguageContext';
import { t } from '../../data/i18n';
import './LegendInfoCard.css';

const VEI_TIERS = [
  { n: 0, tier: 'minor' }, { n: 1, tier: 'minor' }, { n: 2, tier: 'minor' }, { n: 3, tier: 'minor' },
  { n: 4, tier: 'significant' }, { n: 5, tier: 'significant' }, { n: 6, tier: 'significant' },
  { n: 7, tier: 'cataclysmic' }, { n: 8, tier: 'cataclysmic' },
];

export default function LegendInfoCard({ onClose }) {
  const { currentLang } = useLanguage();
  return (
    <div className="legend-info-card visible" id="legendInfoCard" role="dialog" aria-modal="false" aria-hidden="false">
      <div className="legend-info-card-header">
        <span className="legend-info-card-title">{t('legend.info', currentLang)}</span>
        <button
          className="legend-info-card-close"
          type="button"
          id="legendInfoCardClose"
          aria-label={t('legend.close', currentLang)}
          onClick={onClose}
        >×</button>
      </div>
      <div className="legend-info-section">
        <div className="legend-info-section-title">{t('info.statusTitle', currentLang)}</div>
        <div className="legend-info-row">
          <span className="swatch swatch-active"></span>
          <span>{t('info.statusActive', currentLang)}</span>
        </div>
        <div className="legend-info-row">
          <span className="swatch swatch-dormant"></span>
          <span>{t('info.statusDormant', currentLang)}</span>
        </div>
        <div className="legend-info-row">
          <span className="swatch swatch-extinct"></span>
          <span>{t('info.statusExtinct', currentLang)}</span>
        </div>
      </div>
      <div className="legend-info-section">
        <div className="legend-info-section-title">{t('info.veiTitle', currentLang)}</div>
        <div className="legend-info-blurb">{t('info.veiBlurb', currentLang)}</div>
        {VEI_TIERS.map(({ n, tier }) => (
          <div key={n} className="legend-info-vei-row" data-tier={tier}>
            <span className="legend-info-vei-tier">{n}</span>
            <span>{t(`info.vei.${n}`, currentLang)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Create Legend.jsx**

Create `magmascope/src/components/Legend/Legend.jsx`:
```jsx
import { useState } from 'react';
import { useLanguage } from '../../context/LanguageContext';
import { t } from '../../data/i18n';
import LegendInfoCard from './LegendInfoCard';
import './Legend.css';

export default function Legend() {
  const { currentLang } = useLanguage();
  const [infoOpen, setInfoOpen] = useState(false);

  return (
    <>
      <div className="legend" aria-label="Magnitude scale">
        <span className="legend-title">{t('legend.title', currentLang)}</span>
        <span className="legend-item">
          <span className="legend-dot legend-dot-cataclysmic"></span>
          <span className="legend-label">
            {t('legend.cataclysmic', currentLang)} <span className="legend-sub">VEI 7-8</span>
          </span>
        </span>
        <span className="legend-item">
          <span className="legend-dot legend-dot-significant"></span>
          <span className="legend-label">
            {t('legend.significant', currentLang)} <span className="legend-sub">VEI 4-6</span>
          </span>
        </span>
        <span className="legend-item">
          <span className="legend-dot legend-dot-minor"></span>
          <span className="legend-label">
            {t('legend.minor', currentLang)} <span className="legend-sub">VEI 0-3</span>
          </span>
        </span>
        <button
          type="button"
          className="legend-info-btn"
          id="legendInfoBtn"
          aria-expanded={infoOpen}
          aria-controls="legendInfoCard"
          onClick={() => setInfoOpen(o => !o)}
        >
          {t('legend.info', currentLang)}
        </button>
      </div>
      {infoOpen && <LegendInfoCard onClose={() => setInfoOpen(false)} />}
    </>
  );
}
```

- [ ] **Step 5: Commit**

```
git add src/components/Legend/
git commit -m "feat: add Legend and LegendInfoCard components"
```

---

## Task 15: Wire up App.jsx + add Footer + ESC handler

**Files:**
- Modify: `src/App.jsx`

- [ ] **Step 1: Write full App.jsx**

Replace `magmascope/src/App.jsx` entirely:
```jsx
import { useEffect } from 'react';
import { LanguageProvider } from './context/LanguageContext';
import { GlobeProvider, useGlobeContext } from './context/GlobeContext';
import GlobeContainer from './components/GlobeContainer/GlobeContainer';
import Header from './components/Header/Header';
import InfoPanel from './components/InfoPanel/InfoPanel';
import Legend from './components/Legend/Legend';
import HUD from './components/HUD/HUD';
import Loader from './components/Loader/Loader';
import LanguageSwitcher from './components/LanguageSwitcher/LanguageSwitcher';

function AppInner() {
  const { unlockVolcano } = useGlobeContext();

  useEffect(() => {
    function handleKeyDown(e) {
      if (e.key !== 'Escape') return;
      // Close search dropdown first (SearchBar manages its own state)
      // then close the panel
      const searchContainer = document.querySelector('.search-container.has-suggestions');
      if (searchContainer) {
        searchContainer.classList.remove('has-suggestions');
        return;
      }
      const searchInput = document.getElementById('volcanoSearch');
      if (searchInput && searchInput.value) {
        searchInput.value = '';
        searchInput.dispatchEvent(new Event('input', { bubbles: true }));
        searchInput.blur();
        return;
      }
      unlockVolcano();
    }
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [unlockVolcano]);

  return (
    <>
      <LanguageSwitcher />
      <Header />
      <GlobeContainer />
      <InfoPanel />
      <div className="footer">
        <kbd>DRAG</kbd> Rotate &nbsp;·&nbsp; <kbd>SCROLL</kbd> Zoom &nbsp;·&nbsp; <kbd>CLICK</kbd> Inspect
      </div>
      <Legend />
      <HUD />
      <Loader />
    </>
  );
}

export default function App() {
  return (
    <LanguageProvider>
      <GlobeProvider>
        <AppInner />
      </GlobeProvider>
    </LanguageProvider>
  );
}
```

- [ ] **Step 2: Commit**

```
git add src/App.jsx
git commit -m "feat: wire up App.jsx with all providers and components"
```

---

## Task 16: Smoke test + fix the search effect in useGlobe

The search effect in `useGlobe.js` (Task 8) uses scene traversal to build matched IDs, which is fragile. Replace it with a cleaner import-based approach.

**Files:**
- Modify: `src/hooks/useGlobe.js`

- [ ] **Step 1: Replace the search useEffect in useGlobe.js**

Open `magmascope/src/hooks/useGlobe.js`. Find the `// ── SEARCH EFFECT` comment block at the bottom and replace the entire `useEffect` with:
```js
useEffect(() => {
  if (!globeRef.current) return;
  const term = searchQuery.trim().toLowerCase();
  const matchedIds = term
    ? new Set(filterVolcanoes(volcanoes, term).map(v => v.id))
    : null;

  globeRef.current.scene().traverse((obj) => {
    const ud = obj.userData;
    if (!ud || ud._importance === undefined || !ud.id) return;
    obj.visible = !matchedIds || matchedIds.has(ud.id);
  });
}, [searchQuery, volcanoes]);
```

- [ ] **Step 2: Start the dev server and smoke test**

```
npm run dev
```

Open `http://localhost:5173`. Check each item:

- [ ] Globe renders with Earth texture and star background
- [ ] Volcano cone markers visible (brown cones with glowing peaks)
- [ ] Loader fades out after globe loads
- [ ] Header shows "Magmascope · Live" brand
- [ ] Stats show `226` sites and correct active count
- [ ] Legend shows VEI scale in bottom right
- [ ] "Reading the scale" button opens info card; ESC closes it
- [ ] Searching "vesuvius" filters globe markers and shows dropdown
- [ ] Clicking a suggestion flies camera to the volcano and opens the info panel
- [ ] Info panel shows name, coords, elevation, VEI, status chips, safety section
- [ ] HUD targeting animation plays on selection
- [ ] Close button on info panel closes panel and restores marker color
- [ ] Cluster markers appear at far zoom; individual cones appear on zoom-in
- [ ] Clicking a cluster opens cluster popup with member list
- [ ] Clicking a member in the popup flies to that volcano
- [ ] Language switcher changes UI text between EN and RO
- [ ] ESC key closes panel

- [ ] **Step 3: Fix any issues found during smoke test**

Common issues to check:
- If globe is blank: verify Three.js and Globe.gl are loading from CDN (check browser Network tab)
- If markers don't appear: check browser console for Three.js errors
- If CSS looks wrong: verify each CSS file import is in the correct component

- [ ] **Step 4: Run all unit tests to confirm nothing regressed**

```
npm run test -- --run
```

Expected: All tests pass (i18n, LanguageContext, GlobeContext, useSearch).

- [ ] **Step 5: Commit**

```
git add src/hooks/useGlobe.js
git commit -m "fix: use cleaner filterVolcanoes import in useGlobe search effect"
```

---

## Task 17: Build verification + README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Verify production build**

```
npm run build
```

Expected: build completes with no errors. Output in `dist/`.

- [ ] **Step 2: Verify preview**

```
npm run preview
```

Open `http://localhost:4173`. Verify globe loads and features work identically to dev mode.

- [ ] **Step 3: Write README.md**

Create `magmascope/README.md`:
```markdown
# Magmascope

Interactive 3D globe showing 226 active, dormant, and historic volcanoes worldwide. Built with Vite + React, Three.js, and Globe.gl.

## Prerequisites

- Node.js 18 or later
- npm 9 or later

## Setup

```bash
npm install
```

## Running locally

```bash
npm run dev
```

Opens at `http://localhost:5173`.

## Building for production

```bash
npm run build
npm run preview   # preview the production build at http://localhost:4173
```

## Running tests

```bash
npm run test          # watch mode
npm run test -- --run # single run
```

## Project structure

```
src/
  data/           Volcano dataset, i18n dictionary, monitoring agencies
  hooks/          useGlobe (Globe.gl boundary), useSearch (filter logic)
  context/        LanguageContext, GlobeContext
  components/     Feature-organized React components
  styles/         Global CSS tokens and reset
```

## Notes

- **Three.js and Globe.gl are loaded from CDN** via `index.html` script tags, not bundled through Vite. This is intentional — Globe.gl has WebGL build issues when processed by module bundlers.
- **CORS**: WebGL textures must come from CORS-permissive hosts. Current textures are on unpkg.com. Do not swap texture URLs without verifying the host allows cross-origin reads.
- **Never call `customLayerData(filtered)`** — this rebuilds all 226 Three.js cone meshes and causes race conditions. Search filtering toggles `mesh.visible` on existing objects instead.
```

- [ ] **Step 4: Final commit**

```
git add README.md
git commit -m "docs: add README with setup and architecture notes"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Vite + React scaffold (Task 1)
- ✅ `src/data/volcanoes.js` (Task 3)
- ✅ `src/data/i18n.js` with pure `t()` and `tFallback()` (Task 3)
- ✅ `src/data/monitoring.js` (Task 3)
- ✅ `LanguageContext` + `useLanguage` (Task 4)
- ✅ `GlobeContext` + `useGlobeContext` (Task 5)
- ✅ `useSearch` hook (Task 6)
- ✅ `Loader`, `HUD`, `LanguageSwitcher`, `Stats` (Task 7)
- ✅ `useGlobe` hook with mount-once, selection effect, search effect (Task 8)
- ✅ `GlobeContainer` (Task 9)
- ✅ Header + SearchBar CSS (Task 10)
- ✅ `Header`, `SearchBar` (Task 11)
- ✅ `SafetySection` (Task 12)
- ✅ `InfoPanel` with Wikipedia image fetch (Task 13)
- ✅ `Legend`, `LegendInfoCard` (Task 14)
- ✅ `App.jsx` wiring + ESC handler (Task 15)
- ✅ Search effect fix + smoke test checklist (Task 16)
- ✅ Production build verification + README (Task 17)

**Constraint coverage:**
- ✅ Never calls `customLayerData(filtered)` — search uses `mesh.visible`
- ✅ Rings stay disabled (`ringsData([])`)
- ✅ CORS-safe texture URLs from unpkg
- ✅ Cluster cones added to `globe.scene()`, not customLayer
- ✅ Three.js + Globe.gl on CDN, not Vite bundle

**Type consistency:**
- `t(key, lang)` — consistent across all tasks
- `tFallback(prefix, value, lang)` — consistent across all tasks
- `lockVolcano(volcano)` / `unlockVolcano()` — consistent in GlobeContext and consumers
- `filterVolcanoes(volcanoes, term)` — consistent between useSearch and useGlobe
- `scoreSuggestions(volcanoes, term)` — consistent between useSearch and SearchBar
