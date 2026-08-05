# AeroPollen

Deux champs de données Connect IQ pour Garmin Edge 530, affichant la qualité de l'air et les
niveaux de pollens à la position courante, à partir des données [Open-Meteo Air Quality
API](https://open-meteo.com/en/docs/air-quality-api).

## Structure du projet

Le dépôt regroupe trois projets Connect IQ distincts, partageant du code via un Monkey Barrel :

```
barrel/AeroPollenCore/          # Monkey Barrel : code et tests partagés
aeropollen-air-quality-field/   # Application #1 : champ "Qualité de l'Air" (European AQI)
aeropollen-pollen-field/        # Application #2 : champ "Pollens" (score global)
```

Chaque application Garmin (`aeropollen-air-quality-field`, `aeropollen-pollen-field`) est
installée séparément sur l'appareil et déclare sa propre dépendance vers le barrel
`AeroPollenCore` via `base.barrelPath` dans son `monkey.jungle`.

## Documentation

La spécification complète (exigences, plan technique, modèle de données, contrats, tâches) se
trouve dans [`specs/001-pollen-air-datafield/`](specs/001-pollen-air-datafield/).

Les principes du projet (langue française, sécurité, dépendances à jour, Test-First, tests
d'intégration exhaustifs, gouvernance des Pull Requests) sont définis dans
[`.specify/memory/constitution.md`](.specify/memory/constitution.md).

## Build

Nécessite le SDK Connect IQ (Garmin Connect IQ SDK Manager) et le compilateur `monkeyc`.
Compiler les trois projets dans l'ordre (le barrel doit être disponible avant les applications) :

```bash
monkeyc -f barrel/AeroPollenCore/monkey.jungle -d edge530 -o /tmp/AeroPollenCore.prg -y developer_key.der
monkeyc -f aeropollen-air-quality-field/monkey.jungle -d edge530 -o /tmp/AirQuality.prg -y developer_key.der
monkeyc -f aeropollen-pollen-field/monkey.jungle -d edge530 -o /tmp/Pollen.prg -y developer_key.der
```

## Tests

Chaque projet embarque ses tests d'intégration (`Toybox.Test`) dans son dossier `tests/`.
Exécution via le simulateur Connect IQ (`monkeydo -t`) — nécessite un environnement avec rendu
graphique fonctionnel (non disponible sous WSL sans GPU).
