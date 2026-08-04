# Guide de Validation (Quickstart) : Champ de Données Environnementales Garmin

**Feature**: `001-pollen-air-datafield` | **Date** : 2026-08-04

Ce guide décrit comment valider de bout en bout que la fonctionnalité fonctionne, sans détailler
l'implémentation. Il s'appuie sur `data-model.md` et les contrats du dossier `contracts/`.
Conformément au Principe IV (Test-First) de la constitution, les scénarios ci-dessous DOIVENT
être traduits en tests automatisés (unitaires et d'intégration en simulateur) **avant**
l'écriture du code de production correspondant.

## Prérequis

- Connect IQ SDK 8.3.x installé (SDK Manager Garmin), avec le device **Edge 530** téléchargé
  dans le SDK Manager (research.md §2).
- Simulateur Connect IQ fonctionnel (`connectiq` + `monkeydo`).
- Accès réseau sortant disponible pour le simulateur (pour les scénarios utilisant un appel réel
  à l'API Open-Meteo) ou un jeu de réponses JSON simulées pour les scénarios hors-ligne.
- Un appareil **Garmin Edge 530** physique apparié à un smartphone via Garmin Connect Mobile,
  pour l'étape de validation manuelle finale.

## Scénario 1 — Qualité de l'air affichée à la position courante (User Story 1, P1)

**Correspond à** : FR-001, SC-001, contracts/garmin-datafields.md (Champ 1)

1. Compiler et lancer l'application dans le simulateur Connect IQ pour le device `edge530`.
2. Définir dans le simulateur une position GPS simulée connue (ex. Paris : 48.8566, 2.3522) et
   démarrer une activité.
3. Déclencher (ou attendre) le premier cycle du Background Service.
4. **Résultat attendu** : le Champ « Qualité de l'Air » affiche une valeur numérique d'indice en
   moins de 3 secondes après acquisition de la position simulée, cohérente avec une requête
   Open-Meteo pour ces coordonnées (contracts/open-meteo-air-quality.md).

## Scénario 2 — Score de pollens global et détail par type (User Story 2, P2)

**Correspond à** : FR-002, FR-002a, contracts/garmin-datafields.md (Champ 2)

1. Reprendre les étapes 1-3 du Scénario 1 avec une position simulée en Europe, en période de
   pollinisation (ex. printemps).
2. **Résultat attendu** : le Champ « Pollens » affiche un score global agrégé ; le détail par
   type de pollen (aulne, bouleau, graminées, armoise, olivier, ambroisie) est accessible et
   cohérent avec les valeurs `hourly.*_pollen` retournées par l'API pour cette position.
3. Répéter avec une position simulée **hors zone de couverture pollen** (ex. hors Europe).
4. **Résultat attendu** : le Champ « Pollens » indique explicitement l'absence de donnée pour la
   zone, sans afficher de score erroné ni d'écran vide (Edge Case spec.md).

## Scénario 3 — Actualisation automatique en cours de déplacement (User Story 3, P3)

**Correspond à** : FR-003, SC-002

1. Démarrer une activité avec une position simulée initiale.
2. Faire avancer le temps simulé au-delà de l'intervalle d'actualisation (≥ 15 min) et/ou
   déplacer significativement la position simulée.
3. **Résultat attendu** : le Background Service déclenche une nouvelle requête vers Open-Meteo
   et les deux champs reflètent les nouvelles valeurs, sans action de l'utilisateur.

## Scénario 4 — Perte de connectivité → état « indisponible » (FR-005, SC-005)

1. Démarrer une activité avec une position simulée, obtenir un premier relevé valide (comme au
   Scénario 1).
2. Simuler une perte de connectivité (téléphone non apparié / requête réseau en échec) au moment
   du cycle d'actualisation suivant.
3. **Résultat attendu** : les deux champs passent à l'état « indisponible » explicite ; **aucune**
   ancienne valeur numérique ne doit rester affichée sans indication claire de non-fiabilité
   (data-model.md, transition `A_JOUR` → `INDISPONIBLE`).
4. Rétablir la connectivité simulée et attendre le cycle suivant.
5. **Résultat attendu** : les champs repassent automatiquement à l'état « à jour » avec des
   valeurs actualisées.

## Scénario 5 — Absence de dégradation de l'enregistrement GPS (FR-007, SC-004)

1. Démarrer une activité de plusieurs minutes dans le simulateur avec les champs de données
   actifs, en déclenchant plusieurs cycles d'actualisation réseau.
2. **Résultat attendu** : la fréquence d'échantillonnage GPS de l'activité enregistrée reste
   identique à celle observée sans les champs de données activés (aucun appel réseau ne doit
   passer par le cycle `compute()`/`onUpdate()`, conformément à research.md §3).

## Validation manuelle finale sur appareil physique

Une fois les scénarios 1 à 5 verts en simulateur :

1. Installer l'application sur l'Edge 530 physique via le connecteur Garmin ou le SDK Manager.
2. Ajouter les deux champs de données sur un écran d'activité (validant indépendamment FR-006).
3. Effectuer une courte sortie réelle (ou une simulation statique en extérieur) et vérifier
   visuellement la lisibilité des valeurs (FR-008) ainsi que la cohérence des valeurs avec la
   position réelle.
4. Consigner tout écart avec les scénarios 1 à 5 avant de considérer la fonctionnalité prête
   pour revue (Qualité et Portes de Validation, constitution).
