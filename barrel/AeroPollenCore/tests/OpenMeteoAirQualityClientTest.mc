import Toybox.Test;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Tests unitaires du client Open-Meteo : gestion d'erreurs génériques (Foundational),
// extraction de l'European AQI (US1) et des scores de pollens (US2)
// (contracts/open-meteo-air-quality.md).
module AeroPollenCore {

    // Construit le préfixe "YYYY-MM-DDTHH:" correspondant à l'heure UTC courante, pour fabriquer
    // des réponses de test cohérentes avec `findCurrentHourIndex` (offset UTC nul dans les tests).
    function currentHourFixtureTime() as String {
        var info = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var year = (info.year as Number).toString();
        var month = twoDigits(info.month as Number);
        var day = twoDigits(info.day as Number);
        var hour = twoDigits(info.hour as Number);
        return year + "-" + month + "-" + day + "T" + hour + ":00";
    }

    function twoDigits(value as Number) as String {
        return value < 10 ? "0" + value.toString() : value.toString();
    }

    // --- Foundational : gestion d'erreurs génériques ---

    (:test)
    function testHttpErrorReturnsUnavailable(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var reading = client.parseResponse(500, {}, 48.8566, 2.3522);
        return reading.isUnavailable();
    }

    (:test)
    function testNonDictionaryBodyReturnsUnavailable(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var reading = client.parseResponse(200, "not-json", 48.8566, 2.3522);
        return reading.isUnavailable();
    }

    (:test)
    function testMissingHourlyStructureReturnsUnavailable(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var reading = client.parseResponse(200, { "foo" => "bar" }, 48.8566, 2.3522);
        return reading.isUnavailable();
    }

    (:test)
    function testNoMatchingHourReturnsUnavailable(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var body = {
            "utc_offset_seconds" => 0,
            "hourly" => {
                "time" => ["2000-01-01T00:00"],
                "european_aqi" => [10]
            }
        };
        var reading = client.parseResponse(200, body, 48.8566, 2.3522);
        return reading.isUnavailable();
    }

    // --- User Story 1 : extraction de l'European AQI ---

    (:test)
    function testExtractsEuropeanAqiForCurrentHour(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var body = {
            "utc_offset_seconds" => 0,
            "hourly" => {
                "time" => [currentHourFixtureTime()],
                "european_aqi" => [55]
            }
        };
        var reading = client.parseResponse(200, body, 48.8566, 2.3522);
        return reading.isUpToDate() && reading.airQualityIndex == 55;
    }

    // --- User Story 2 : extraction des scores de pollens et score global ---

    (:test)
    function testExtractsPollenScoresAndGlobalForCurrentHour(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var body = {
            "utc_offset_seconds" => 0,
            "hourly" => {
                "time" => [currentHourFixtureTime()],
                "european_aqi" => [20],
                "alder_pollen" => [5],
                "birch_pollen" => [80],
                "grass_pollen" => [12],
                "mugwort_pollen" => [0],
                "olive_pollen" => [3],
                "ragweed_pollen" => [1]
            }
        };
        var reading = client.parseResponse(200, body, 48.8566, 2.3522);
        var scores = reading.pollenScoresByType;

        if (!reading.isUpToDate() || scores == null) {
            return false;
        }
        if ((scores as Dictionary)[POLLEN_BIRCH] != 80) {
            return false;
        }
        return reading.pollenScoreGlobal == 80;
    }

    // Une valeur `null` pour un type de pollen (hors couverture/saison) doit être traitée comme
    // absente pour ce type précis, sans invalider le reste du relevé.
    (:test)
    function testNullPollenValueTreatedAsAbsentWithoutInvalidatingReading(logger as Test.Logger) as Boolean {
        var client = new OpenMeteoAirQualityClient();
        var body = {
            "utc_offset_seconds" => 0,
            "hourly" => {
                "time" => [currentHourFixtureTime()],
                "european_aqi" => [20],
                "alder_pollen" => [null],
                "birch_pollen" => [40],
                "grass_pollen" => [null],
                "mugwort_pollen" => [null],
                "olive_pollen" => [null],
                "ragweed_pollen" => [null]
            }
        };
        var reading = client.parseResponse(200, body, 48.8566, 2.3522);
        var scores = reading.pollenScoresByType;

        if (!reading.isUpToDate() || scores == null) {
            return false;
        }
        if ((scores as Dictionary)[POLLEN_ALDER] != null) {
            return false;
        }
        return reading.pollenScoreGlobal == 40;
    }
}
