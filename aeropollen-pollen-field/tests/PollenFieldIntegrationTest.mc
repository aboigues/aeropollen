import Toybox.Test;
import Toybox.Lang;
import Toybox.Time;

// Scénarios d'intégration de l'application pollen-field (quickstart.md Scénario 2). Le rendu
// complet sur un écran d'activité simulé nécessite le simulateur Connect IQ ; ce test couvre la
// partie déterministe : la correspondance entre le contenu du cache et la valeur affichée
// (contracts/garmin-datafields.md Champ 2).

// Scénario 2 (première partie) : affichage du score de pollens global en période de
// pollinisation.
(:test)
function testPollenFieldDisplaysGlobalScore(logger as Test.Logger) as Boolean {
    var view = new PollenFieldView();
    var scores = {
        AeroPollenCore.POLLEN_BIRCH => 80,
        AeroPollenCore.POLLEN_GRASS => 12
    } as Dictionary<AeroPollenCore.PollenType, Number?>;
    var reading = AeroPollenCore.EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 20, scores);

    return view.displayValueFor(reading).equals("80");
}

// Scénario 2 (seconde partie) : hors zone de couverture, l'absence de donnée pollen doit être
// explicite et distincte de l'état "indisponible" (Edge Case spec.md).
(:test)
function testPollenFieldDisplaysNoDataStateOutsideCoverage(logger as Test.Logger) as Boolean {
    var view = new PollenFieldView();
    var reading = AeroPollenCore.EnvironmentalReading.upToDate(0.0, 0.0, Time.now(), 20, null);

    var displayed = view.displayValueFor(reading);
    return !displayed.equals("80") && !displayed.equals("N/D");
}

// FR-005 : un relevé "indisponible" (perte de connectivité) doit rester distinct de l'état
// "aucune donnée pollen".
(:test)
function testPollenFieldDisplaysUnavailableState(logger as Test.Logger) as Boolean {
    var view = new PollenFieldView();
    var reading = AeroPollenCore.EnvironmentalReading.unavailable();

    return view.displayValueFor(reading).equals("N/D");
}

// Scénario 3 : dès que le Background Service écrit une nouvelle valeur dans le cache, le champ
// doit la refléter sans action utilisateur (research.md §3, §9).
(:test)
function testPollenFieldReflectsCacheUpdateWithoutUserAction(logger as Test.Logger) as Boolean {
    var view = new PollenFieldView();
    var store = new AeroPollenCore.EnvironmentalReadingStore();
    var scores = {
        AeroPollenCore.POLLEN_BIRCH => 15
    } as Dictionary<AeroPollenCore.PollenType, Number?>;

    store.save(AeroPollenCore.EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 10, scores));
    var firstDisplay = view.displayValueFor(store.load());

    var updatedScores = {
        AeroPollenCore.POLLEN_BIRCH => 90
    } as Dictionary<AeroPollenCore.PollenType, Number?>;
    store.save(AeroPollenCore.EnvironmentalReading.upToDate(45.7640, 4.8357, Time.now(), 10, updatedScores));
    var secondDisplay = view.displayValueFor(store.load());

    return firstDisplay.equals("15") && secondDisplay.equals("90");
}
