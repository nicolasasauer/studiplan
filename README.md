# StudiumsPlaner

StudiumsPlaner ist eine Web-App zur Planung von Semestern und Klausuren mit Drag-and-drop.
Der Fokus liegt auf einer schnellen, visuellen Studienplanung mit Parkplatz-Logik fuer noch nicht zugeordnete Veranstaltungen.

## Features

- Ersteinrichtung beim ersten Start (Planname, Regelstudienzeit, Startsemester)
- Regelstudienzeit konfigurierbar (1–20 Semester), Standard: 6 Semester
- Planname direkt im Header bearbeitbar
- Veranstaltungen mit Name, ECTS, Klausurdatum, Turnus (WS/SS/Beide), Beschreibung und Farbe
- Bestanden-Status und Note (1,0–5,0) pro Veranstaltung erfassbar
- ECTS- und Notenstatistik im Header (gesamt geplant, bestanden, Durchschnittsnote)
- Notenstatistik pro Semester (bestandene ECTS, Durchschnittsnote)
- Drag-and-drop zwischen Semestern und Parkplatz
- Reihenfolge innerhalb eines Semesters per Drag-and-drop anpassbar
- Sortierung pro Semester nach Datum oder ECTS
- Semester ein-/ausklappbar
- Semester loeschbar (Veranstaltungen landen automatisch im Parkplatz)
- Bearbeiten und Loeschen von Veranstaltungen
- Parkplatz fuer noch nicht zugeordnete Veranstaltungen (erscheint nur wenn belegt)
- Import/Export des Plans als JSON-Datei
- Persistenz im Browser via `localStorage`; bei Docker-Deployment zusaetzlich server-seitig unter `/data/plan.json`

## Wichtige Planungsregel

Der Turnus (`WS`/`SS`/`Beide`) ist ein Hinweis und kein Blocker.
Eine Veranstaltung kann weiterhin in jedem Semester geplant werden; bei Abweichungen zeigt die UI einen visuellen Warnhinweis auf der Veranstaltungskarte.

## Tech Stack

- React 18
- TypeScript
- Vite
- Tailwind CSS
- Zustand
- react-beautiful-dnd
- lucide-react
- Express (Node.js-Backend fuer Docker-Deployment)
- express-rate-limit

## Voraussetzungen

- Node.js 20+
- npm 10+

## Schnellstart (Windows)

`setup.bat` per Doppelklick ausfuehren.

Das Skript:
1. prueft, ob Node.js installiert ist
2. installiert Abhaengigkeiten
3. startet den Dev-Server

## Manueller Start

```bash
npm install
npm run dev
```

Standard-URL: `http://localhost:5173`

## Verfuegbare Skripte

```bash
npm run dev        # Entwicklungsserver
npm run build      # TypeScript Build + Vite Production Build
npm run preview    # Vorschau des Production Builds
npm run lint       # ESLint
npm run typecheck  # TypeScript Check ohne Output
```

Optionales E2E-Skript (Playwright, "manual-like"):

```bash
node scripts/manual-like-e2e.mjs
```

Testreport wird in `test-results/manual-like-e2e-report.json` geschrieben.

## Docker & Docker Compose

### Mit Docker Compose starten (empfohlen)

Das mitgelieferte `docker-compose.yml` zieht das fertige Image direkt von der GitHub Container Registry:

```bash
docker-compose up -d
```

App laeuft dann auf `http://localhost:3000`

Stoppen:
```bash
docker-compose down
```

Daten werden in einem Docker-Volume (`studiumsplaner_data`) unter `/data/plan.json` gespeichert.

### Docker Image selber bauen

```bash
docker build -t studiumsplaner:latest .
docker run -p 3000:3000 studiumsplaner:latest
```

App laeuft auf `http://localhost:3000`

### Dockerfile-Details

- **Multi-Stage-Build**: Reduziert finale Image-Groesse
- **Build-Stage**: Node 20 Alpine baut TypeScript & Vite (`dist/`)
- **Runtime-Stage**: Node 20 Alpine startet den Express-Server (`server/index.js`), der die statischen Dateien ausliefert und den Plan unter `/api/plan` speichert
- **Health Check**: Ueberwacht Container-Status via `wget`

## PowerShell-Hinweis (Windows)

Falls in PowerShell der Fehler "script execution is disabled" erscheint:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

Alternativ `setup.bat` oder `cmd.exe` verwenden.

## Projektstruktur

```text
server/
  index.js            # Express-Server (API + statisches Hosting fuer Docker)
src/
  components/
    AddLectureModal.tsx
    LectureCard.tsx
    ParkingLot.tsx
    PlanSetupModal.tsx
    SemesterSection.tsx
    index.ts
  App.tsx
  store.ts
  types.ts
scripts/
  manual-like-e2e.mjs
```

## GitHub-Release-Checkliste

1. `npm run lint` ausfuehren
2. `npm run typecheck` ausfuehren
3. `npm run build` ausfuehren
4. README, Lizenz und Repository-Metadaten pruefen

## Disclaimer (Vibe-Coding)

Dieses Projekt ist vollstaendig "gevibecoded" ("vibe-coded") entstanden, also mit starker KI-Unterstuetzung bei Architektur, Implementierung und Iteration.
Trotz funktionierender Builds und Checks kann es fachliche, technische oder sicherheitsrelevante Luecken geben.
Bitte vor produktivem Einsatz eine gruendliche manuelle Pruefung durchfuehren.

## Open Source

Das Repository ist fuer eine oeffentliche GitHub-Veroeffentlichung vorbereitet mit:

- `LICENSE` (MIT)
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`

## Lizenz

MIT, siehe `LICENSE`.
