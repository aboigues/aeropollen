# Contrat : Champs de Données Garmin Exposés à l'Utilisateur

**Feature**: `001-pollen-air-datafield` | **Date** : 2026-08-04

Ce contrat décrit l'interface exposée à l'utilisateur final (et à la plateforme Garmin Connect
IQ) par la fonctionnalité, conformément à FR-006 : deux champs de données distincts, chacun
sélectionnable indépendamment par l'utilisateur via la configuration standard du compteur.

**Correction d'architecture (research.md §9)** : chaque champ est une **application Connect IQ
installée séparément** (`aeropollen-air-quality-field` et `aeropollen-pollen-field`), pas deux vues d'une même
application — un `manifest.xml` Connect IQ ne peut déclarer qu'un seul `<iq:application>`. Les
deux applications partagent leur code via le Barrel `AeroPollenCore`, mais exécutent chacune
leur propre Background Service et leur propre cache `Application.Storage` (isolé par
application).

## Champ 1 — Qualité de l'Air (application `aeropollen-air-quality-field`)

- **Rôle** : afficher `Relevé Environnemental.indice_qualite_air` (European AQI) pour la
  position courante (User Story 1, FR-001).
- **États d'affichage** :
  - `A_JOUR` → valeur numérique de l'indice.
  - `INDISPONIBLE` → libellé explicite d'indisponibilité (FR-005), jamais une valeur numérique
    ni un champ vide sans explication.
- **Contrainte de lecture** : la valeur affichée est lue depuis le cache local
  (`Application.Storage`, research.md §5) ; ce champ ne déclenche jamais lui-même de requête
  réseau (FR-007).

## Champ 2 — Pollens (application `aeropollen-pollen-field`)

- **Rôle** : afficher `Relevé Environnemental.score_pollen_global` en vue principale, avec accès
  au détail par `Type de Pollen` (FR-002/FR-002a, User Story 2).
- **États d'affichage** :
  - `A_JOUR` avec au moins un type renseigné → score global affiché.
  - `A_JOUR` mais aucun type renseigné pour la zone/saison → libellé explicite d'absence de
    donnée pollen (Edge Case spec.md, Acceptance Scenario 2 de User Story 2), distinct de l'état
    `INDISPONIBLE` global.
  - `INDISPONIBLE` → libellé explicite d'indisponibilité (FR-005).
- **Contrainte de lecture** : identique au Champ 1 — lecture seule depuis le cache local, jamais
  de requête réseau synchrone depuis le rendu (FR-007).

## Garanties communes aux deux champs

- **Lisibilité** (FR-008) : format adapté à une consultation rapide sur écran de petite taille
  (valeurs numériques ou libellés courts, pas de texte long).
- **Non-dégradation du tracking** (FR-007, SC-004) : aucun des deux champs n'effectue d'opération
  bloquante ou coûteuse dans son cycle de rendu (`compute()`/`onUpdate()`).
- **Délai d'affichage initial** (SC-001) : dès qu'une position GPS est disponible et qu'un relevé
  est en cache (même issu d'une activité précédente), la valeur s'affiche en moins de 3 secondes ;
  en l'absence de tout relevé en cache, l'état `INDISPONIBLE` est affiché immédiatement plutôt que
  de laisser un écran vide en attente.
- **Indépendance de sélection** (FR-006) : chaque champ correspond à une application Connect IQ
  installée séparément, ajoutée, retirée ou repositionnée indépendamment par l'utilisateur sur
  ses écrans d'activité, sans dépendre de l'installation ou de l'activation de l'autre champ.
