# StudiPlan - Flutter App

Die Flutter-App ist der mobile Begleiter zu [StudiPlan](../README.md).
Sie bietet dieselbe Planungsfunktionalitaet wie die Web-App, jedoch als native Android-App mit Serversynchronisierung.

## Features

- Anmeldung per Benutzername (optionales Passwort)
- Benutzerverwaltung: Benutzer anlegen, auflisten, einloggen
- Ersteinrichtung des Plans (Planname, Regelstudienzeit, Startsemester)
- Veranstaltungen mit Name, ECTS, Turnus (WS/SS/Beide), Klausurdatum, Beschreibung und Farbe
- Bestanden-Status und Note (1,0-5,0) pro Veranstaltung
- Muendliche-Pruefung-Markierung (Note standardmaessig 4,0)
- ECTS- und Notenstatistik im Header (gesamt geplant, bestanden, Durchschnittsnote)
- Notenstatistik pro Semester
- Parkplatz fuer noch nicht zugeordnete Veranstaltungen
- Veranstaltungen zwischen Semestern und Parkplatz verschieben
- Sortierung pro Semester nach Klausurdatum oder ECTS
- Semester ein-/ausklappbar
- Semester loeschbar (Veranstaltungen landen automatisch im Parkplatz)
- Import/Export des Plans als JSON-Datei
- Automatische Synchronisierung mit dem Server alle 30 Sekunden
- Lokale Persistenz via `SharedPreferences` (auch offline nutzbar)
- Server-URL konfigurierbar ueber einen Einstellungsdialog
- Dark-Mode-Design

## Screenshots

### Anmelden
Beim Start meldet man sich mit einem bestehenden Benutzer an oder legt einen neuen an. Die Server-URL ist jederzeit ueber den Einstellungsbutton konfigurierbar.

![Login-Bildschirm mit Benutzerliste](https://github.com/user-attachments/assets/2467ed86-43f0-45ec-b472-9251326b34c6)

### Semesteruebersicht
Die Hauptansicht zeigt alle Semester mit Veranstaltungskarten inklusive ECTS, Note, Klausurdatum und Bestandenstatus. Statistik-Chips im Header zeigen geplante und bestandene ECTS sowie die Durchschnittsnote. Veranstaltungen lassen sich per Langdruck in andere Semester oder den Parkplatz verschieben.

![Hauptansicht mit Semestern und ECTS-Statistik](https://github.com/user-attachments/assets/82de6d1f-2384-483f-ab55-202aba6d84ac)

### Veranstaltung anlegen
Ueber den Dialog koennen neue Veranstaltungen mit Name, ECTS, Turnus (WS/SS/Beide), Semester, Klausurdatum, Bestandenstatus, Note (Slider 1,0-5,0), muendliche-Pruefung-Markierung, Beschreibung und Farbe angelegt werden.

![Dialog zum Anlegen einer neuen Veranstaltung](https://github.com/user-attachments/assets/7717c6d5-a78e-457a-b4d6-2d10d4e5bbbe)

## Wichtige Planungsregel

Der Turnus (`WS`/`SS`/`Beide`) ist ein Hinweis und kein Blocker.
Eine Veranstaltung kann weiterhin in jedem Semester geplant werden; bei Abweichungen zeigt die App einen visuellen Warnhinweis auf der Veranstaltungskarte.

## Tech Stack

- Flutter 3.44 (Dart, SDK `>=3.10.0 <4.0.0`)
- Provider (State Management)
- http (REST-API-Client)
- shared_preferences (Lokale Persistenz)
- uuid (ID-Generierung)
- file_picker (JSON-Import)
- share_plus (JSON-Export)
- path_provider (Temporaere Dateien)

## Voraussetzungen

- Flutter SDK 3.x ([flutter.dev](https://flutter.dev/docs/get-started/install))
- Android SDK / Android Studio (fuer Android-Builds)
- Laufende Instanz des StudiPlan-Servers (siehe [Docker-Anleitung](../README.md#docker--docker-compose))

## Schnellstart

```bash
cd flutter_app
flutter pub get
flutter run
```

Die App fragt beim ersten Start nach der Server-URL. Diese kann jederzeit ueber den Einstellungsbutton auf dem Login-Bildschirm geaendert werden.

Standard-Server-URL (lokales Docker-Deployment): `http://localhost:3000`

## Verfuegbare Befehle

```bash
flutter pub get       # Abhaengigkeiten installieren
flutter run           # App auf verbundenem Geraet/Emulator starten
flutter build apk     # Release-APK bauen
flutter test          # Unit-Tests ausfuehren
flutter analyze       # Statische Code-Analyse (flutter_lints)
flutter build windows # Windows-App bauen (nur unter Windows)
flutter build linux   # Linux-App bauen (nur unter Linux)
```

### Desktop (Windows, Linux)

- Windows: Visual Studio 2022 mit der Workload "Desktopentwicklung mit C++". Ergebnis in `build/windows/x64/runner/Release/`, der ganze Ordner wird benötigt.
- Linux: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`. Ergebnis in `build/linux/x64/release/bundle/`. Für die Dateidialoge (Import/Export) muss `zenity` oder `kdialog` installiert sein.
- Der Workflow `.github/workflows/flutter-build-desktop.yml` baut beide und stellt sie als Artefakte bereit.
- Export speichert auf dem Desktop über einen Speichern-Dialog statt über das Teilen-Menü.

## Serverkonfiguration

Die App kommuniziert mit dem StudiPlan-Backend:

| Endpunkt | Methode | Beschreibung |
|---|---|---|
| `/api/users` | GET | Benutzerliste abrufen |
| `/api/login` | POST | Anmelden, Token erhalten |
| `/api/users` | POST | Neuen Benutzer anlegen |
| `/api/plan/{username}` | GET | Plan laden |
| `/api/plan/{username}` | POST | Plan speichern |

Alle Planendpunkte erfordern einen Bearer-Token im `Authorization`-Header.

## Projektstruktur

```text
flutter_app/
  lib/
    main.dart                     # App-Einstiegspunkt & Theme
    models/
      lecture.dart                # Veranstaltungsmodell
      semester.dart               # Semestermodell
      study_plan.dart             # Wurzelmodell des Plans
    providers/
      study_plan_provider.dart    # State Management (ChangeNotifier)
    screens/
      login_screen.dart           # Anmelde- und Benutzerverwaltung
      main_screen.dart            # Hauptansicht (Plan, Semester, Statistik)
    services/
      api_service.dart            # HTTP-API-Client
      storage_service.dart        # Lokale Persistenz
    widgets/
      lecture_card.dart           # Veranstaltungskarte
      semester_section.dart       # Semesterbereich mit Veranstaltungen
      parking_lot_section.dart    # Parkplatz fuer unzugeordnete Veranstaltungen
      add_lecture_dialog.dart     # Dialog: Veranstaltung anlegen/bearbeiten
      plan_setup_dialog.dart      # Dialog: Plan einrichten
      server_settings_dialog.dart # Dialog: Server-URL konfigurieren
  test/
    models_test.dart              # Unit-Tests fuer Modelle
  android/                        # Android-Build-Konfiguration
  pubspec.yaml                    # Abhaengigkeiten & Metadaten
```

## Tests

```bash
flutter test
```

Die Tests in `test/models_test.dart` pruefen:

- JSON-Serialisierung und `copyWith()` von `Lecture`
- Durchschnittsnotenberechnung in `Semester`
- ECTS-Aggregation in `StudyPlan`

## Disclaimer (Vibe-Coding)

Dieses Projekt ist vollstaendig "gevibecoded" entstanden, also mit starker KI-Unterstuetzung bei Architektur, Implementierung und Iteration.
Trotz funktionierender Builds und Tests kann es fachliche, technische oder sicherheitsrelevante Luecken geben.
Bitte vor produktivem Einsatz eine gruendliche manuelle Pruefung durchfuehren.

## Lizenz

MIT, siehe [`../LICENSE`](../LICENSE).
