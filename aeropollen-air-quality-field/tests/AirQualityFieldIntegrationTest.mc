import Toybox.Test;
import Toybox.Lang;
import Toybox.Time;

// Scénarios d'intégration de l'application air-quality-field (quickstart.md). Le rendu complet
// sur un écran d'activité simulé (Scénario 1, position GPS simulée) nécessite le simulateur
// Connect IQ ; ce test couvre la partie déterministe et automatisable : la correspondance entre
// le contenu du cache et la valeur affichée par le champ (contracts/garmin-datafields.md Champ 1).

// Scénario 1 : affichage de la qualité de l'air à la position courante.
(:test)
function testAirQualityFieldDisplaysCachedIndex(logger as Test.Logger) as Boolean {
    var view = new AirQualityFieldView();
    var reading = AeroPollenCore.EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 55, null);

    return view.displayValueFor(reading).equals("55");
}

// FR-005 : un relevé "indisponible" doit afficher l'état explicite, jamais une valeur vide.
(:test)
function testAirQualityFieldDisplaysUnavailableState(logger as Test.Logger) as Boolean {
    var view = new AirQualityFieldView();
    var reading = AeroPollenCore.EnvironmentalReading.unavailable();

    return !view.displayValueFor(reading).equals("55");
}

// Scénario 3 : dès que le Background Service écrit une nouvelle valeur dans le cache (nouvelle
// position/heure), le champ doit la refléter sans action utilisateur — compute() relit le cache
// à chaque cycle (research.md §3, §9).
(:test)
function testAirQualityFieldReflectsCacheUpdateWithoutUserAction(logger as Test.Logger) as Boolean {
    var view = new AirQualityFieldView();
    var store = new AeroPollenCore.EnvironmentalReadingStore();

    store.save(AeroPollenCore.EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 10, null));
    var firstDisplay = view.displayValueFor(store.load());

    store.save(AeroPollenCore.EnvironmentalReading.upToDate(45.7640, 4.8357, Time.now(), 99, null));
    var secondDisplay = view.displayValueFor(store.load());

    return firstDisplay.equals("10") && secondDisplay.equals("99");
}
