---

description: "Task list template for feature implementation"
---

# Tasks: Champ de Données Environnementales Garmin (Qualité de l'Air et Pollens)

**Input**: Design documents from `/specs/001-pollen-air-datafield/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (tous présents)

**Tests**: Les tâches de test ci-dessous sont **obligatoires**, et non optionnelles — la
constitution du projet impose le Principe IV (Test-First, NON-NÉGOCIABLE) et le Principe V
(Tests d'Intégration Exhaustifs, NON-NÉGOCIABLE). Chaque tâche de test DOIT être écrite et
observée en échec avant sa tâche d'implémentation correspondante.

**Organization**: Les tâches sont groupées par user story (spec.md) pour permettre une
implémentation et une validation indépendantes de chacune.

**Correction d'architecture** (research.md §9, découverte lors de `/speckit-implement`) : FR-006
exige deux applications Connect IQ installées séparément, pas deux vues d'une seule application
(un `manifest.xml` ne déclare qu'un `<iq:application>`). Le code commun vit dans un **Monkey
Barrel** (`barrel/EnvironmentalCore/`), référencé par les deux applications
(`air-quality-field/`, `pollen-field/`). `plan.md` et `contracts/` ont été mis à jour en
conséquence.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut s'exécuter en parallèle (fichiers différents, pas de dépendance non résolue)
- **[Story]**: User story concernée (US1, US2, US3)
- Chemins de fichiers exacts inclus dans chaque description

## Path Conventions

Trois projets Connect IQ à la racine du dépôt (cf. plan.md, Project Structure) :
`barrel/EnvironmentalCore/` (code et tests partagés), `air-quality-field/` (application #1),
`pollen-field/` (application #2).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialisation des 3 projets Connect IQ (1 Barrel + 2 applications)

- [X] T001 Créer la structure des 3 projets Connect IQ — `barrel/EnvironmentalCore/`
      (`manifest.xml`, `monkey.jungle`, `source/`, `tests/`), `air-quality-field/`
      (`manifest.xml`, `monkey.jungle`, `source/`, `resources/{strings,drawables,layouts}/`,
      `tests/`), `pollen-field/` (structure identique) — conformément à plan.md § Project
      Structure
- [X] T002 Configurer le manifeste du Barrel `barrel/EnvironmentalCore/manifest.xml` (type
      Barrel, produits supportés incluant `edge530`) et son `barrel/EnvironmentalCore/monkey.jungle`
      (`project.manifest = manifest.xml`), conformément à research.md §9
- [X] T003 [P] Configurer `air-quality-field/manifest.xml` (id d'application, device `edge530`,
      `minApiLevel` 3.3.0, `type="datafield"`, `<iq:barrels><iq:depends
      name="EnvironmentalCore" .../></iq:barrels>`) et `air-quality-field/monkey.jungle`
      (`base.barrelPath = ../barrel/EnvironmentalCore/monkey.jungle`), sans encore déclarer
      d'entry point fonctionnel — dépend de T002
- [X] T004 [P] Configurer `pollen-field/manifest.xml` et `pollen-field/monkey.jungle` de la même
      façon — dépend de T002

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Code partagé du Barrel `EnvironmentalCore` (entités, cache, client réseau, service
en arrière-plan) que LES DEUX applications utilisent

**⚠️ CRITICAL**: Aucune user story ne peut démarrer avant la fin de cette phase

### Tests Foundational (écrire et observer l'échec AVANT l'implémentation)

- [X] T005 [P] Test unitaire des invariants du Relevé Environnemental (transitions d'état
      `A_JOUR`/`INDISPONIBLE`, cohérence score global/détail par type) dans
      `barrel/EnvironmentalCore/tests/EnvironmentalReadingTest.mc` (data-model.md)
- [X] T006 [P] Test unitaire du cache `EnvironmentalReadingStore` (lecture/écriture, transition
      vers `INDISPONIBLE`) dans `barrel/EnvironmentalCore/tests/EnvironmentalReadingStoreTest.mc`
      (data-model.md, research.md §5)
- [X] T007 [P] Test unitaire de la construction de requête et de la gestion d'erreurs génériques
      du client Open-Meteo (statut HTTP ≠ 200, JSON invalide, timeout, absence de position GPS
      exploitable (FR-010) → `INDISPONIBLE`) dans
      `barrel/EnvironmentalCore/tests/OpenMeteoAirQualityClientTest.mc`
      (contracts/open-meteo-air-quality.md)
- [X] T008 [P] Test d'intégration en simulateur : perte de connectivité prolongée puis
      rétablissement (Scénario 4 de quickstart.md), incluant la vérification qu'aucune exception
      non gérée n'interrompt l'activité en cours (FR-009), dans
      `barrel/EnvironmentalCore/tests/EnvironmentalBackgroundDelegateTest.mc`

### Implémentation Foundational

- [X] T009 Implémenter les entités Relevé Environnemental et Type de Pollen dans
      `barrel/EnvironmentalCore/source/EnvironmentalReading.mc` (data-model.md) — rend T005 vert
- [X] T010 Implémenter `EnvironmentalReadingStore` (`Toybox.Application.Storage`) dans
      `barrel/EnvironmentalCore/source/EnvironmentalReadingStore.mc` (research.md §5) — dépend
      de T009 ; rend T006 vert
- [X] T011 Implémenter le squelette d'`OpenMeteoAirQualityClient` (construction de la requête
      HTTPS complète avec tous les paramètres `hourly`, validation générique de la réponse) dans
      `barrel/EnvironmentalCore/source/OpenMeteoAirQualityClient.mc`
      (contracts/open-meteo-air-quality.md) — dépend de T009 ; rend T007 vert
- [X] T012 Implémenter `EnvironmentalBackgroundDelegate` (`ServiceDelegate`,
      `onTemporalEvent()`, écriture dans le cache via `EnvironmentalReadingStore`), y compris
      l'absence de position GPS au démarrage (FR-010) : ne déclenche aucune requête réseau et
      marque le relevé `INDISPONIBLE`, dans
      `barrel/EnvironmentalCore/source/EnvironmentalBackgroundDelegate.mc` (research.md §3,
      FR-003, FR-010) — dépend de T010, T011 ; rend T008 vert

**Checkpoint**: Barrel `EnvironmentalCore` prêt — les deux applications peuvent démarrer

---

## Phase 3: User Story 1 - Consulter la qualité de l'air en temps réel (Priority: P1) 🎯 MVP

**Goal**: Livrer l'application Connect IQ `air-quality-field`, affichant l'indice de qualité de
l'air (European AQI) correspondant à la position actuelle (FR-001,
contracts/garmin-datafields.md Champ 1)

**Independent Test**: Compiler et démarrer l'application `air-quality-field` seule dans le
simulateur et vérifier qu'une valeur cohérente avec la position simulée s'affiche en moins de 3
secondes (Scénario 1 de quickstart.md)

### Tests for User Story 1 (écrire et observer l'échec AVANT l'implémentation) ⚠️

- [X] T013 [P] [US1] Test unitaire d'extraction de l'European AQI depuis
      `hourly.european_aqi[]` dans `barrel/EnvironmentalCore/tests/OpenMeteoAirQualityClientTest.mc`
- [X] T014 [P] [US1] Test d'intégration du Scénario 1 de quickstart.md (affichage qualité de
      l'air à la position courante) dans `air-quality-field/tests/AirQualityFieldIntegrationTest.mc`

### Implementation for User Story 1

- [X] T015 [US1] Étendre `OpenMeteoAirQualityClient` pour extraire `indice_qualite_air` (entrée
      `hourly.time[]`/`hourly.european_aqi[]` la plus proche de l'heure courante) dans
      `barrel/EnvironmentalCore/source/OpenMeteoAirQualityClient.mc` — dépend de T011, T013
- [X] T016 [P] [US1] Créer le layout d'affichage dans
      `air-quality-field/resources/layouts/air_quality_field.xml`
- [X] T017 [P] [US1] Créer `air-quality-field/resources/strings/strings.xml` (nom de
      l'application, libellé « Indisponible », conformément au Principe I)
- [X] T018 [US1] Implémenter `AirQualityFieldApp` (`Application.AppBase`, enregistre le
      Background Service au démarrage) dans `air-quality-field/source/AirQualityFieldApp.mc` —
      dépend de T003
- [X] T019 [US1] Implémenter `AirQualityFieldView` (lecture seule du cache, affichage de la
      valeur ou de l'état « indisponible », aucun appel réseau dans `compute()`/`onUpdate()`)
      dans `air-quality-field/source/AirQualityFieldView.mc` (contracts/garmin-datafields.md
      Champ 1) — dépend de T015, T016, T018, T014
- [X] T020 [US1] Finaliser `air-quality-field/manifest.xml` (entry point, icône, libellé,
      permission `Background`) — l'enregistrement du service en arrière-plan lui-même est
      entièrement piloté par le code (`Background.registerForTemporalEvent()` dans
      `AirQualityFieldApp.initialize()`, sans élément manifeste dédié) — dépend de T017, T019

**Checkpoint**: `air-quality-field` compile et fonctionne indépendamment — MVP livrable en tant
qu'application autonome installable sur l'Edge 530

---

## Phase 4: User Story 2 - Consulter un score de pollens (Priority: P2)

**Goal**: Livrer l'application Connect IQ `pollen-field`, affichant un score de pollens global
agrégé et un détail par type de pollen (FR-002, FR-002a, contracts/garmin-datafields.md Champ 2)

**Independent Test**: Compiler et démarrer l'application `pollen-field` seule dans le simulateur
en période de pollinisation et vérifier l'affichage du score global et du détail par type ;
répéter hors zone de couverture et vérifier l'état d'absence de donnée explicite (Scénario 2 de
quickstart.md)

### Tests for User Story 2 (écrire et observer l'échec AVANT l'implémentation) ⚠️

- [X] T021 [P] [US2] Test unitaire d'extraction des six variables `*_pollen` et du calcul du
      `score_pollen_global` dans `barrel/EnvironmentalCore/tests/OpenMeteoAirQualityClientTest.mc`
- [X] T022 [P] [US2] Test d'intégration du Scénario 2 de quickstart.md (score global + détail
      par type, et absence de donnée hors zone) dans
      `pollen-field/tests/PollenFieldIntegrationTest.mc`

### Implementation for User Story 2

- [X] T023 [US2] Étendre `OpenMeteoAirQualityClient` pour extraire les six variables `*_pollen`
      et calculer `score_pollen_global` (traiter toute valeur `null` comme absente pour le type
      concerné, sans invalider le relevé) dans
      `barrel/EnvironmentalCore/source/OpenMeteoAirQualityClient.mc`
      (contracts/open-meteo-air-quality.md) — dépend de T015, T021
- [X] T024 [P] [US2] Créer le layout d'affichage (score global + accès au détail par type) dans
      `pollen-field/resources/layouts/pollen_field.xml`
- [X] T025 [P] [US2] Créer `pollen-field/resources/strings/strings.xml` (nom de l'application,
      libellés « Indisponible », « Pas de donnée pollen », conformément au Principe I)
- [X] T026 [US2] Implémenter `PollenFieldApp` (`Application.AppBase`, enregistre le Background
      Service) dans `pollen-field/source/PollenFieldApp.mc` — dépend de T004
- [X] T027 [US2] Implémenter `PollenFieldView` (lecture seule du cache ; distinction entre état
      « indisponible » et « aucune donnée pollen pour cette zone/saison » ; aucun appel réseau
      dans `compute()`/`onUpdate()`) dans `pollen-field/source/PollenFieldView.mc`
      (contracts/garmin-datafields.md Champ 2) — dépend de T023, T024, T026, T022
- [X] T028 [US2] Finaliser `pollen-field/manifest.xml` (entry point, icône, libellé, permission
      `Background`) — dépend de T025, T027

**Checkpoint**: `air-quality-field` ET `pollen-field` fonctionnent indépendamment — deux
applications installables séparément (FR-006)

---

## Phase 5: User Story 3 - Recevoir des données toujours pertinentes en déplacement (Priority: P3)

**Goal**: Actualiser automatiquement les valeurs affichées dans les deux applications en
fonction du déplacement et du temps écoulé, sans intervention de l'utilisateur (FR-003, SC-002)

**Independent Test**: Pour chaque application, parcourir une distance significative et laisser
s'écouler plus de 15 minutes simulées pendant une activité, puis vérifier que le champ se met à
jour sans action utilisateur (Scénario 3 de quickstart.md)

### Tests for User Story 3 (écrire et observer l'échec AVANT l'implémentation) ⚠️

- [X] T029 [P] [US3] Test unitaire de l'intervalle d'actualisation enregistré (900 s = 15 min,
      research.md §12 : seul mécanisme de déclenchement disponible sur la plateforme, satisfait
      « temps écoulé OU distance significative » en pratique aux vitesses d'une sortie vélo)
      dans `barrel/EnvironmentalCore/tests/EnvironmentalBackgroundDelegateTest.mc`
- [X] T030 [P] [US3] Test d'intégration du Scénario 3 de quickstart.md pour `air-quality-field`
      dans `air-quality-field/tests/AirQualityFieldIntegrationTest.mc`
- [X] T031 [P] [US3] Test d'intégration du Scénario 3 de quickstart.md pour `pollen-field` dans
      `pollen-field/tests/PollenFieldIntegrationTest.mc`

### Implementation for User Story 3

- [X] T032 [US3] Exposer explicitement la constante d'intervalle d'actualisation et confirmer
      (research.md §12) qu'aucune logique de distance supplémentaire n'est nécessaire ni
      possible sur la plateforme dans
      `barrel/EnvironmentalCore/source/EnvironmentalBackgroundDelegate.mc` — dépend de T012, T029
- [X] T033 [US3] Vérifier/adapter `AirQualityFieldView` pour refléter automatiquement toute
      nouvelle valeur du cache, sans action utilisateur, dans
      `air-quality-field/source/AirQualityFieldView.mc` — dépend de T019, T030, T032
- [X] T034 [US3] Vérifier/adapter `PollenFieldView` pour refléter automatiquement toute nouvelle
      valeur du cache, sans action utilisateur, dans `pollen-field/source/PollenFieldView.mc` —
      dépend de T027, T031, T032

**Checkpoint**: Les trois user stories sont désormais indépendamment fonctionnelles, dans les
deux applications

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Vérifications transverses exigées par la constitution avant toute fusion

- [X] T035 [P] Revue de code dédiée : confirmer qu'aucun appel réseau ni opération bloquante
      n'existe dans `compute()`/`onUpdate()` de `air-quality-field/source/AirQualityFieldView.mc`
      et `pollen-field/source/PollenFieldView.mc` (FR-007, SC-004, research.md §3)
- [ ] T036 [P] Exécuter et documenter le Scénario 5 de quickstart.md (absence de dégradation de
      l'échantillonnage GPS) pour les deux applications dans le simulateur Connect IQ
- [X] T037 [P] Revue de sécurité : HTTPS systématique, absence de secret stocké sur l'appareil,
      validation stricte des réponses JSON avant utilisation (Principe II) sur
      `barrel/EnvironmentalCore/source/OpenMeteoAirQualityClient.mc` et
      `barrel/EnvironmentalCore/source/EnvironmentalBackgroundDelegate.mc`
- [X] T038 [P] Vérifier que le SDK Connect IQ et l'API Level utilisés en pratique correspondent
      aux versions documentées dans research.md §2 et à l'architecture Barrel de research.md §9
      (Principe III)
- [X] T039 [P] Relire l'ensemble de la prose du projet (spec, plan, commentaires narratifs de
      code, `resources/strings/strings.xml` des deux applications) pour conformité au français
      (Principe I)
- [ ] T040 Valider manuellement l'installation des deux applications sur l'appareil Garmin Edge
      530 physique, exécuter la checklist de validation manuelle finale de quickstart.md, et
      recueillir un retour informel de 3 à 5 utilisateurs testeurs sur leur compréhension des
      valeurs affichées sans documentation externe (SC-003) — dépend de T020, T028, T033, T034

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Aucune dépendance — peut démarrer immédiatement
- **Foundational (Phase 2)**: Dépend de la fin du Setup — BLOQUE toutes les user stories
- **User Stories (Phase 3+)**: Dépendent toutes de la fin de Foundational
  - US1 (P1) peut démarrer dès Foundational terminé
  - US2 (P2) peut démarrer dès Foundational terminé (indépendante de US1, mais réutilise la
    partie parsing d'`OpenMeteoAirQualityClient` étendue par T015 de US1 — voir note ci-dessous)
  - US3 (P3) peut démarrer dès Foundational terminé, mais ses tests d'intégration valident un
    comportement observable seulement une fois US1 et/ou US2 présentes
- **Polish (Phase 6)**: Dépend des user stories que l'on souhaite livrer

**Note d'indépendance** : T023 (US2) dépend techniquement de T015 (US1) car les deux étendent le
même fichier `barrel/EnvironmentalCore/source/OpenMeteoAirQualityClient.mc`. Cette dépendance
est une dépendance de fichier partagé (le Barrel), pas une dépendance fonctionnelle entre
applications : `pollen-field` reste une application installable et testable indépendamment de
`air-quality-field` (FR-006), à condition que T015 ait été fusionné au préalable dans le Barrel.

### User Story Dependencies

- **User Story 1 (P1)**: Après Foundational — aucune dépendance sur les autres stories
- **User Story 2 (P2)**: Après Foundational (et après T015 de US1 pour le fichier client partagé
  du Barrel, cf. note ci-dessus) — indépendamment testable et livrable en tant qu'application
  séparée
- **User Story 3 (P3)**: Après Foundational — s'appuie sur les applications créées par US1/US2
  pour être observée, mais n'ajoute aucune nouvelle dépendance fonctionnelle bloquante

### Within Each User Story

- Les tests sont écrits et DOIVENT échouer avant l'implémentation (Principe IV)
- Entités/cache avant client réseau ; client réseau avant service en arrière-plan ; service en
  arrière-plan avant vues d'affichage
- Story complète avant de passer à la priorité suivante

### Parallel Opportunities

- T003, T004 (Setup, manifestes des 2 applications) en parallèle
- T005, T006, T007, T008 (tests Foundational du Barrel) en parallèle
- T013, T014 (tests US1) en parallèle ; T016, T017 en parallèle avec T015
- T021, T022 (tests US2) en parallèle ; T024, T025 en parallèle avec T023
- T029, T030, T031 (tests US3) en parallèle
- T035, T036, T037, T038, T039 (Polish) en parallèle

---

## Parallel Example: Foundational

```bash
# Lancer les 4 tests Foundational du Barrel ensemble :
Task: "Test unitaire des invariants du Relevé Environnemental dans barrel/EnvironmentalCore/tests/EnvironmentalReadingTest.mc"
Task: "Test unitaire du cache EnvironmentalReadingStore dans barrel/EnvironmentalCore/tests/EnvironmentalReadingStoreTest.mc"
Task: "Test unitaire du client Open-Meteo (erreurs génériques, absence de position) dans barrel/EnvironmentalCore/tests/OpenMeteoAirQualityClientTest.mc"
Task: "Test d'intégration perte de connectivité et non-interruption (Scénario 4) dans barrel/EnvironmentalCore/tests/EnvironmentalBackgroundDelegateTest.mc"
```

## Parallel Example: User Story 1

```bash
# Lancer les tests de la User Story 1 ensemble :
Task: "Test unitaire extraction European AQI dans barrel/EnvironmentalCore/tests/OpenMeteoAirQualityClientTest.mc"
Task: "Test d'intégration Scénario 1 dans air-quality-field/tests/AirQualityFieldIntegrationTest.mc"

# En parallèle de l'implémentation du client, créer le layout et les strings :
Task: "Créer le layout air-quality-field/resources/layouts/air_quality_field.xml"
Task: "Créer air-quality-field/resources/strings/strings.xml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Terminer la Phase 1 : Setup
2. Terminer la Phase 2 : Foundational (CRITIQUE — bloque toutes les stories)
3. Terminer la Phase 3 : User Story 1 (`air-quality-field`)
4. **ARRÊTER ET VALIDER** : tester `air-quality-field` indépendamment (Scénario 1 de
   quickstart.md)
5. Installer sur l'Edge 530 physique pour démonstration si prêt

### Incremental Delivery

1. Setup + Foundational → Barrel prêt
2. User Story 1 → `air-quality-field` livrée et validée indépendamment (MVP !)
3. User Story 2 → `pollen-field` livrée et validée indépendamment
4. User Story 3 → actualisation automatique validée sur les deux applications
5. Polish & Cross-Cutting → portes de qualité de la constitution avant toute fusion humaine

### Parallel Team Strategy

Avec plusieurs contributeurs :

1. L'équipe termine Setup + Foundational (Barrel) ensemble
2. Une fois Foundational terminé :
   - Contributeur A : User Story 1 (`air-quality-field`)
   - Contributeur B : User Story 2 (`pollen-field`, après fusion de T015 dans le Barrel)
   - Contributeur C : User Story 3 (sur les deux applications)
3. Les stories se complètent et s'intègrent indépendamment

---

## Notes

- [P] = fichiers différents, pas de dépendance non résolue
- [Story] relie chaque tâche à sa user story pour la traçabilité
- Chaque user story doit rester indépendamment complétable et testable
- Vérifier que chaque test échoue avant d'implémenter la tâche correspondante (Principe IV)
- Committer après chaque tâche ou groupe logique cohérent
- S'arrêter à chaque checkpoint pour valider la story indépendamment
- Aucune pull request ne doit être fusionnée par un agent IA (Gouvernance des Pull Requests,
  constitution) — chaque checkpoint prépare une revue humaine, pas une fusion automatique
