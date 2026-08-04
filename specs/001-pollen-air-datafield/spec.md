# Feature Specification: Champ de Données Environnementales Garmin (Qualité de l'Air et Pollens)

**Feature Branch**: `001-pollen-air-datafield`

**Created**: 2026-08-04

**Status**: Draft

**Input**: User description: "Le projet consiste à implémenter un data fields sur garmin (appareil de test Garmin Edge 530) capable de fournir plusieurs valeurs sur un compteur gps (comme l'IEA ou un score de tous les pollens) à l'heure et à l'endroit exacte en fonction d'une API externe comme open-meteo.com"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consulter la qualité de l'air en temps réel pendant une sortie (Priority: P1)

En tant que cycliste équipé d'un compteur GPS Garmin Edge 530, je veux voir l'indice de qualité
de l'air correspondant à ma position actuelle directement sur l'écran de mon compteur, afin de
prendre conscience du niveau de pollution que je respire pendant mon effort physique.

**Why this priority**: C'est la valeur la plus directement actionnable pour la sécurité et le
confort de l'utilisateur pendant l'effort ; elle constitue le minimum viable du produit.

**Independent Test**: Peut être testé en démarrant une activité sur le compteur avec le champ de
données actif, et en vérifiant qu'une valeur d'indice de qualité de l'air cohérente avec la
position réelle s'affiche à l'écran.

**Acceptance Scenarios**:

1. **Given** une activité en cours avec signal GPS acquis et connectivité disponible, **When**
   l'utilisateur consulte l'écran contenant le champ de données, **Then** l'indice de qualité de
   l'air correspondant à sa position géographique actuelle s'affiche.
2. **Given** l'utilisateur se déplace de manière significative pendant l'activité, **When** le
   système actualise les données, **Then** l'indice affiché est recalculé pour la nouvelle
   position.

---

### User Story 2 - Consulter un score de pollens pendant une sortie (Priority: P2)

En tant que cycliste sensible aux allergies, je veux voir un score lié aux pollens correspondant
à ma position actuelle sur mon compteur GPS, afin d'anticiper une éventuelle réaction allergique
pendant ou après ma sortie.

**Why this priority**: Complète la valeur d'usage de l'indice de qualité de l'air pour les
utilisateurs allergiques, mais n'est pas indispensable au fonctionnement minimal du produit.

**Independent Test**: Peut être testé en démarrant une activité avec le champ de données actif
en période de pollinisation, et en vérifiant qu'un score de pollens cohérent avec la position
réelle s'affiche à l'écran.

**Acceptance Scenarios**:

1. **Given** une activité en cours en période de pollinisation, **When** l'utilisateur consulte
   l'écran contenant le champ de données, **Then** un score de pollens correspondant à sa
   position géographique actuelle s'affiche.
2. **Given** aucune donnée de pollen disponible pour la zone géographique actuelle, **When** le
   système tente d'actualiser la valeur, **Then** l'utilisateur voit un état indiquant
   explicitement l'absence de donnée plutôt qu'une valeur erronée ou vide sans explication.

---

### User Story 3 - Recevoir des données toujours pertinentes pendant le déplacement (Priority: P3)

En tant que cycliste en mouvement, je veux que les valeurs affichées se mettent à jour
automatiquement au fil de mon déplacement et du temps qui passe, afin de disposer d'informations
réellement représentatives de l'endroit et du moment où je me trouve, plutôt que des données
figées depuis le début de la sortie.

**Why this priority**: Améliore la fiabilité perçue et la pertinence des deux premières
fonctionnalités, sans être bloquant pour une première version démontrable.

**Independent Test**: Peut être testé en parcourant une distance significative pendant une
activité et en vérifiant que les valeurs affichées évoluent en cohérence avec le changement de
position et l'écoulement du temps.

**Acceptance Scenarios**:

1. **Given** une activité de longue durée en cours, **When** le temps écoulé ou la distance
   parcourue dépasse le seuil d'actualisation défini, **Then** le système interroge à nouveau la
   source de données externe et met à jour les valeurs affichées.
2. **Given** une perte temporaire de connectivité pendant l'activité, **When** la connectivité
   est rétablie, **Then** le système actualise automatiquement les valeurs sans intervention de
   l'utilisateur.

---

### Edge Cases

- Que se passe-t-il si le compteur GPS n'a pas encore acquis de position au démarrage de
  l'activité (aucune coordonnée disponible pour interroger la source de données) ?
- Que se passe-t-il si le smartphone apparié n'a aucune connexion Internet disponible pendant
  l'activité ?
- Comment le système réagit-il si la source de données externe ne fournit aucune donnée de
  pollen pour la zone géographique actuelle (hors couverture ou hors saison) ?
- Comment le système réagit-il si la source de données externe est temporairement indisponible
  ou renvoie une erreur ?
- Que se passe-t-il en cas de changement rapide de zone géographique (grande vitesse, changement
  de région) nécessitant une nouvelle interrogation avant l'échéance normale d'actualisation ?
- Que se passe-t-il si les valeurs affichées deviennent obsolètes au-delà d'une durée raisonnable
  sans qu'aucune actualisation n'ait pu être effectuée ?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT afficher un indice de qualité de l'air correspondant à la position
  géographique actuelle de l'utilisateur pendant une activité en cours.
- **FR-002**: Le système DOIT afficher un score de pollens global agrégé, représentant le risque
  pollinique combiné à la position géographique actuelle de l'utilisateur pendant une activité
  en cours.
- **FR-002a**: Le système DOIT également fournir un score détaillé par type de pollen (par
  exemple bouleau, graminées, ambroisie) correspondant à la position géographique actuelle, en
  complément du score global.
- **FR-003**: Le système DOIT actualiser les valeurs affichées à intervalle régulier pendant
  l'activité afin de refléter les changements de position géographique et d'heure, à une
  fréquence par défaut d'au moins une fois toutes les 15 minutes.
- **FR-004**: Le système DOIT obtenir les données de qualité de l'air et de pollens auprès d'une
  source de données externe capable de fournir ces informations en fonction d'une position
  géographique et d'un horodatage précis (par exemple Open-Meteo).
- **FR-005**: Le système DOIT afficher un état "indisponible" explicite à la place de la valeur
  dès que les données ne peuvent plus être actualisées suite à une perte de connectivité
  prolongée, plutôt que de continuer à afficher une ancienne valeur pouvant induire en erreur.
- **FR-006**: Le système DOIT proposer plusieurs champs de données Garmin distincts et
  sélectionnables séparément (un dédié à la qualité de l'air, un dédié aux pollens), que
  l'utilisateur place librement sur ses écrans d'activité via la configuration standard du
  compteur.
- **FR-007**: Le système NE DOIT PAS dégrader la précision ni la continuité de l'enregistrement
  GPS principal de l'activité du fait de l'affichage des données environnementales.
- **FR-008**: Le système DOIT présenter les valeurs dans un format lisible en conditions d'usage
  sportif, adapté à une consultation rapide sur un écran de petite taille.
- **FR-009**: Le système NE DOIT JAMAIS générer d'exception non gérée ni interrompre
  l'enregistrement de l'activité en cours lorsque la source de données externe est indisponible
  ou renvoie une erreur — cette exigence porte sur la stabilité du système, distincte de FR-005
  qui porte sur l'état affiché à l'utilisateur.
- **FR-010**: Tant qu'aucune position GPS n'a été acquise depuis le démarrage de l'activité, le
  système DOIT afficher l'état « indisponible » sans tenter d'interroger la source de données
  externe (aucune coordonnée valide à transmettre).

### Key Entities

- **Position Géographique**: coordonnées (latitude, longitude) de l'utilisateur à un instant
  donné pendant l'activité, utilisées comme entrée pour interroger la source de données externe.
- **Relevé Environnemental**: ensemble de valeurs (indice de qualité de l'air, score de pollens
  global, scores par type de pollen) associé à une position géographique et à un horodatage
  précis, avec un état de disponibilité (à jour / indisponible).
- **Type de Pollen**: catégorie de pollen suivie (par exemple bouleau, graminées, ambroisie),
  possédant son propre score dans le relevé environnemental.
- **Source de Données Externe**: service tiers fournissant les données de qualité de l'air et de
  pollens en fonction d'une position géographique et d'un horodatage (par exemple Open-Meteo).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un utilisateur peut consulter la qualité de l'air actuelle à sa position sur son
  compteur GPS en moins de 3 secondes après acquisition du signal GPS au début de l'activité.
- **SC-002**: Les valeurs affichées sont actualisées au moins une fois toutes les 15 minutes
  pendant une activité en cours, tant que la connectivité est disponible.
- **SC-003**: 90 % des utilisateurs testés comprennent la signification des valeurs affichées
  (indice de qualité de l'air, score de pollens) sans consulter de documentation externe.
- **SC-004**: L'affichage des données environnementales n'entraîne aucune dégradation mesurable
  de la fréquence d'échantillonnage GPS de l'activité enregistrée.
- **SC-005**: Lorsque la connectivité est perdue pendant l'activité, l'utilisateur est informé de
  l'état "indisponible" des données dans 100 % des cas, sans jamais afficher une ancienne valeur
  sans indication de son caractère non fiable.

## Assumptions

- Le compteur Garmin Edge 530 est apparié via Bluetooth à un smartphone exécutant l'application
  Garmin Connect Mobile, ce qui permet au champ de données d'accéder à Internet pendant
  l'activité (l'appareil ne dispose pas de connectivité cellulaire ou Wi-Fi autonome pendant une
  sortie).
- La source de données externe (type Open-Meteo) fournit gratuitement des données de qualité de
  l'air et de pollens avec une résolution géographique suffisante (à l'échelle kilométrique) pour
  un usage sportif de plein air.
- Le champ de données est actif uniquement pendant l'enregistrement d'une activité sportive sur
  le compteur, et non en mode veille ou montre.
- La liste des types de pollens disponibles correspond à ceux fournis par la source de données
  externe utilisée, laquelle peut varier selon la région géographique.
- Une fréquence d'actualisation par défaut d'environ 15 minutes constitue un compromis raisonnable
  entre pertinence des données, autonomie de la batterie et respect des limites d'usage de la
  source de données externe.
