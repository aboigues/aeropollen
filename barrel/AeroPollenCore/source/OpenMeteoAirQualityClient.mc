import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Client de l'API Open-Meteo Air Quality (contracts/open-meteo-air-quality.md). Construit la
// requête HTTPS, interroge la source externe, et transforme la réponse en Relevé
// Environnemental (à jour ou indisponible), sans jamais exposer d'exception à l'appelant.
module AeroPollenCore {

    (:background)
    class OpenMeteoAirQualityClient {

        private const BASE_URL = "https://air-quality-api.open-meteo.com/v1/air-quality";
        private const HOURLY_PARAMS =
            "european_aqi,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen";

        private var _latitude as Float?;
        private var _longitude as Float?;
        private var _callback as (Method(reading as EnvironmentalReading) as Void)?;

        // Interroge Open-Meteo pour la position donnée et transmet le Relevé Environnemental
        // résultant (à jour ou indisponible) au callback fourni. Ne lève jamais d'exception
        // (FR-009) : toute erreur se traduit par un relevé "indisponible".
        public function fetch(
            latitude as Float,
            longitude as Float,
            callback as Method(reading as EnvironmentalReading) as Void
        ) as Void {
            _latitude = latitude;
            _longitude = longitude;
            _callback = callback;

            var params = {
                "latitude" => latitude,
                "longitude" => longitude,
                "hourly" => HOURLY_PARAMS,
                "timezone" => "auto"
            };

            var options = {
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            Communications.makeWebRequest(BASE_URL, params, options, method(:onResponse));
        }

        // Callback de Communications.makeWebRequest (contracts/open-meteo-air-quality.md,
        // Conditions d'échec).
        public function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
            var latitude = _latitude;
            var longitude = _longitude;
            var reading = (latitude == null || longitude == null)
                ? EnvironmentalReading.unavailable()
                : parseResponse(responseCode, data, latitude as Float, longitude as Float);
            var callback = _callback;
            if (callback != null) {
                callback.invoke(reading);
            }
        }

        // Fonction pure de transformation de la réponse HTTP en Relevé Environnemental, publique
        // afin d'être directement testable (OpenMeteoAirQualityClientTest.mc) sans dépendre du
        // cycle asynchrone de Communications.makeWebRequest.
        public function parseResponse(
            responseCode as Number,
            data as Dictionary or String or Null,
            latitude as Float,
            longitude as Float
        ) as EnvironmentalReading {
            if (responseCode != 200 || !(data instanceof Dictionary)) {
                return EnvironmentalReading.unavailable();
            }

            var body = data as Dictionary;
            var hourly = body["hourly"];
            if (!(hourly instanceof Dictionary)) {
                return EnvironmentalReading.unavailable();
            }
            var hourlyDict = hourly as Dictionary;

            var times = hourlyDict["time"];
            if (!(times instanceof Array)) {
                return EnvironmentalReading.unavailable();
            }
            var timesArray = times as Array;

            var utcOffsetRaw = body["utc_offset_seconds"];
            var utcOffsetSeconds = utcOffsetRaw instanceof Number ? utcOffsetRaw as Number : 0;
            var index = findCurrentHourIndex(timesArray, utcOffsetSeconds);
            if (index == -1) {
                return EnvironmentalReading.unavailable();
            }

            var pollenScores = {
                POLLEN_ALDER => extractNumberAt(hourlyDict, "alder_pollen", index),
                POLLEN_BIRCH => extractNumberAt(hourlyDict, "birch_pollen", index),
                POLLEN_GRASS => extractNumberAt(hourlyDict, "grass_pollen", index),
                POLLEN_MUGWORT => extractNumberAt(hourlyDict, "mugwort_pollen", index),
                POLLEN_OLIVE => extractNumberAt(hourlyDict, "olive_pollen", index),
                POLLEN_RAGWEED => extractNumberAt(hourlyDict, "ragweed_pollen", index)
            } as Dictionary<PollenType, Number?>;

            return EnvironmentalReading.upToDate(
                latitude as Float,
                longitude as Float,
                Time.now(),
                extractNumberAt(hourlyDict, "european_aqi", index),
                pollenScores
            );
        }

        // Recherche dans hourly.time[] l'entrée correspondant à l'heure locale courante de la
        // position interrogée (contracts/open-meteo-air-quality.md, condition d'échec n°4).
        // `utc_offset_seconds` est renvoyé par Open-Meteo car `timezone=auto` a été demandé.
        private function findCurrentHourIndex(timesArray as Array, offsetSeconds as Number) as Number {
            var localMoment = Time.now().add(new Time.Duration(offsetSeconds));
            var info = Gregorian.utcInfo(localMoment, Time.FORMAT_SHORT);

            var expectedPrefix = Lang.format("$1$-$2$-$3$T$4$:", [
                formatTwoDigits(info.year as Number, 4),
                formatTwoDigits(info.month as Number, 2),
                formatTwoDigits(info.day as Number, 2),
                formatTwoDigits(info.hour as Number, 2)
            ]);
            var prefixLength = expectedPrefix.length();

            for (var i = 0; i < timesArray.size(); i++) {
                var entry = timesArray[i];
                if (entry instanceof String) {
                    var entryString = entry as String;
                    if (entryString.length() >= prefixLength) {
                        var candidate = entryString.substring(0, prefixLength);
                        if (candidate != null && (candidate as String).equals(expectedPrefix)) {
                            return i;
                        }
                    }
                }
            }
            return -1;
        }

        private function formatTwoDigits(value as Number, width as Number) as String {
            var text = value.toString();
            while (text.length() < width) {
                text = "0" + text;
            }
            return text;
        }

        private function extractNumberAt(hourlyDict as Dictionary, key as String, index as Number) as Number? {
            var values = hourlyDict[key];
            if (!(values instanceof Array)) {
                return null;
            }
            var valuesArray = values as Array;
            if (index >= valuesArray.size()) {
                return null;
            }
            var value = valuesArray[index];
            if (value instanceof Number) {
                return value as Number;
            }
            if (value instanceof Float) {
                return (value as Float).toNumber();
            }
            return null;
        }
    }
}
