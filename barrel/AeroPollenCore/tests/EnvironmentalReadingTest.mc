import Toybox.Test;
import Toybox.Lang;
import Toybox.Time;

// Tests unitaires des invariants du Relevé Environnemental (data-model.md).
module AeroPollenCore {

    (:test)
    function testUnavailableReadingHasNoReliableValues(logger as Test.Logger) as Boolean {
        var reading = EnvironmentalReading.unavailable();

        return reading.isUnavailable()
            && !reading.isUpToDate()
            && reading.airQualityIndex == null
            && reading.pollenScoreGlobal == null;
    }

    (:test)
    function testUpToDateReadingKeepsProvidedValues(logger as Test.Logger) as Boolean {
        var now = Time.now();
        var reading = EnvironmentalReading.upToDate(48.8566, 2.3522, now, 42, null);

        return reading.isUpToDate()
            && reading.latitude == 48.8566
            && reading.longitude == 2.3522
            && reading.airQualityIndex == 42;
    }

    // FR-002/FR-002a : le score global doit être cohérent avec le détail par type (valeur
    // maximale des types renseignés, en ignorant les types absents).
    (:test)
    function testGlobalPollenScoreIsMaxOfAvailableTypes(logger as Test.Logger) as Boolean {
        var scores = {
            POLLEN_BIRCH => 30,
            POLLEN_GRASS => 75,
            POLLEN_RAGWEED => null
        } as Dictionary<PollenType, Number?>;
        var reading = EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 20, scores);

        return reading.pollenScoreGlobal == 75;
    }

    (:test)
    function testGlobalPollenScoreIsNullWhenNoTypeAvailable(logger as Test.Logger) as Boolean {
        var reading = EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 20, null);

        return reading.pollenScoreGlobal == null;
    }
}
