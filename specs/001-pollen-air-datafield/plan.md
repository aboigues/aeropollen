# Implementation Plan: Champ de Données Environnementales Garmin (Qualité de l'Air et Pollens)

**Branch**: `001-pollen-air-datafield` | **Date**: 2026-08-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-pollen-air-datafield/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Application Garmin Connect IQ (Monkey C) exposant deux champs de données distincts pour
compteur GPS — qualité de l'air (European AQI) et pollens (score global + détail par type) —
calculés à partir de la position et de l'heure exactes de l'utilisateur via l'API Open-Meteo Air
Quality. Un Background Service interroge la source externe à intervalle régulier (≥ 15 min) et
met en cache le résultat localement (`Application.Storage`) ; les vues des champs de données ne
font que lire ce cache, garantissant l'absence d'impact sur l'enregistrement GPS principal. En
cas d'échec d'actualisation (connectivité, erreur API, absence de donnée), un état
« indisponible » explicite est affiché plutôt qu'une ancienne valeur.

## Technical Context

**Language/Version**: Monkey C, compilé avec le Connect IQ SDK 9.2.0 (version installée et
vérifiée localement le 2026-08-04, cf. research.md §2), ciblant un `minApiLevel` 3.3.0 (API
Level requis par l'Edge 530).

**Primary Dependencies**: Toybox core APIs du Connect IQ SDK — `Toybox.Communications`
(`makeWebRequest` HTTPS), `Toybox.Application.Storage`, `Toybox.Background`
(`ServiceDelegate`/`onTemporalEvent`), `Toybox.Position`, `Toybox.WatchUi`,
`Toybox.Test` (framework de tests unitaires). Aucune bibliothèque tierce.

**Storage**: `Toybox.Application.Storage` (magasin clé-valeur local de l'appareil) pour le
dernier Relevé Environnemental en cache ; pas de base de données ni de fichier structuré
(research.md §5).

**Testing**: Tests unitaires via `Toybox.Test` (`(:test)` + `monkeydo`) écrits avant le code ;
tests d'intégration de bout en bout dans le simulateur Connect IQ (scénarios quickstart.md) ;
validation manuelle complémentaire sur l'appareil Edge 530 physique de test (research.md §6).

**Target Platform**: Garmin Edge 530 (Connect IQ API Level 3.3+), application de type Data
Field.

**Project Type**: Application embarquée mono-projet (Connect IQ Data Field) — pas de séparation
frontend/backend, pas de service serveur propre.

**Performance Goals**: Premier affichage en cache < 3 s après acquisition GPS (SC-001) ;
actualisation au moins toutes les 15 min tant que la connectivité est disponible (SC-002) ;
aucune opération réseau ou bloquante dans les cycles `compute()`/`onUpdate()` des champs de
données (research.md §3).

**Constraints**: Pas de connectivité autonome — dépendance au téléphone apparié via Bluetooth
(Garmin Connect Mobile) pour tout accès Internet ; couverture des données de pollen limitée à
l'Europe et à la saison pollinique (limite de la source externe) ; usage non commercial de
l'API Open-Meteo (pas de clé API, respect du fair use) ; budget mémoire du Data Field imposé et
vérifié par le compilateur Connect IQ à la compilation (research.md, Synthèse).

**Scale/Scope**: Application mono-utilisateur, mono-appareil de test (Edge 530) ; deux champs de
données Garmin distincts et indépendamment sélectionnables (FR-006) ; une seule source de
données externe active (Open-Meteo).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / Section | Gate | Statut |
|---|---|---|
| I. Langue Française | Toute la documentation de la fonctionnalité (spec, plan, research, data-model, contracts, quickstart) est rédigée en français ; seuls les identifiants de code Monkey C resteront en anglais par convention technique. | **PASS** |
| II. Sécurité et Fiabilité (NON-NÉGOCIABLE) | Tout appel réseau en HTTPS ; aucune donnée sensible/secret stocké sur l'appareil (pas de clé API requise) ; erreurs gérées explicitement aux frontières (réponse API, absence de connectivité) via l'état `INDISPONIBLE` (FR-005) ; aucune opération réseau ne bloque le tracking GPS (FR-007). | **PASS** |
| III. Dépendances Récentes et Stables | SDK Connect IQ 9.2.0 (version installée et vérifiée activement le 2026-08-04) et API Level minimal 3.3.0 documentés et justifiés dans research.md §2. | **PASS** |
| IV. Test-First (NON-NÉGOCIABLE) | quickstart.md définit les scénarios de bout en bout à traduire en tests (unitaires `Toybox.Test` + intégration simulateur) **avant** le code ; à appliquer strictement lors de `/speckit-tasks` et `/speckit-implement`. | **PASS** (gate de conception ; application vérifiée à l'implémentation) |
| V. Tests d'Intégration Exhaustifs | Chaque partie (service réseau, cache de stockage, les deux vues de champ de données, gestion d'erreur) couverte par un scénario dédié dans quickstart.md (Scénarios 1-5). | **PASS** |
| Gouvernance des Pull Requests | Aucune fusion de PR par un agent IA prévue ni requise par ce plan ; toute PR sera préparée pour revue humaine. | **PASS** (rappel, pas d'action de conception requise) |
| Qualité et Portes de Validation | Les 5 portes (E2E, intégration, revue sécurité, dépendances à jour, prose en français) sont toutes couvertes par les artefacts de cette phase de conception. | **PASS** |

Aucune violation constitutionnelle identifiée : la section **Complexity Tracking** reste vide.

## Project Structure

### Documentation (this feature)

```text
specs/001-pollen-air-datafield/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   ├── open-meteo-air-quality.md
│   └── garmin-datafields.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

**Correction d'architecture (research.md §9)** : Connect IQ ne permet qu'un seul
`<iq:application>` par `manifest.xml` — deux champs de données indépendamment sélectionnables
(FR-006) nécessitent donc **deux applications Connect IQ distinctes**, partageant leur code
commun via un **Monkey Barrel** (`AeroPollenCore`).

```text
barrel/AeroPollenCore/            # Monkey Barrel : code partagé par les 2 applications
├── manifest.xml                     # Manifeste de type Barrel (annotations, produits supportés)
├── monkey.jungle                    # project.manifest = manifest.xml
├── source/
│   ├── EnvironmentalReading.mc            # Modèle "Relevé Environnemental" (data-model.md)
│   ├── EnvironmentalReadingStore.mc       # Lecture/écriture du cache Application.Storage
│   ├── OpenMeteoAirQualityClient.mc       # Requête + parsing (contracts/open-meteo-air-quality.md)
│   └── EnvironmentalBackgroundDelegate.mc # ServiceDelegate : onTemporalEvent -> appel Open-Meteo
└── tests/
    ├── EnvironmentalReadingTest.mc
    ├── EnvironmentalReadingStoreTest.mc
    ├── OpenMeteoAirQualityClientTest.mc
    └── EnvironmentalBackgroundDelegateTest.mc

aeropollen-air-quality-field/                   # Application Connect IQ #1 : champ "Qualité de l'Air"
├── manifest.xml                     # <iq:application type="datafield"> + <iq:barrels>
├── monkey.jungle                    # project.manifest + base.barrelPath -> ../barrel/AeroPollenCore
├── resources/
│   ├── strings/                     # Libellés français (dont "Indisponible")
│   ├── drawables/                   # Icône du champ (menu de sélection Garmin)
│   └── layouts/air_quality_field.xml
├── source/
│   ├── AirQualityFieldApp.mc        # Point d'entrée Application.AppBase
│   └── AirQualityFieldView.mc       # Vue : lecture cache uniquement (contracts/garmin-datafields.md Champ 1)
└── tests/
    └── AirQualityFieldIntegrationTest.mc  # Scénarios d'intégration simulateur (quickstart.md)

aeropollen-pollen-field/                        # Application Connect IQ #2 : champ "Pollens"
├── manifest.xml
├── monkey.jungle
├── resources/
│   ├── strings/
│   ├── drawables/
│   └── layouts/pollen_field.xml
├── source/
│   ├── PollenFieldApp.mc
│   └── PollenFieldView.mc           # Vue : lecture cache (contracts/garmin-datafields.md Champ 2)
└── tests/
    └── PollenFieldIntegrationTest.mc      # Scénarios d'intégration simulateur (quickstart.md)
```

**Structure Decision**: Trois projets Connect IQ à la racine du dépôt (pas de séparation
frontend/backend au sens web — il s'agit d'applications embarquées exécutées sur l'appareil
Garmin) : un Monkey Barrel (`barrel/AeroPollenCore/`) portant tout le code et les tests
partagés, et deux applications minces (`aeropollen-air-quality-field/`, `aeropollen-pollen-field/`) qui référencent ce
Barrel et n'ajoutent que leur point d'entrée, leur vue d'affichage et leurs ressources propres.
Chaque application exécute son propre Background Service et son propre cache local
(`Application.Storage` étant isolé par application, research.md §9). Les tests colocalisés
utilisent le framework natif `Toybox.Test`, conformément à research.md §6. La documentation de
planification reste dans `specs/001-pollen-air-datafield/` comme imposé par le workflow Spec
Kit.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Aucune violation constitutionnelle n'a été identifiée pour cette fonctionnalité ; cette section
est intentionnellement laissée sans entrée.
