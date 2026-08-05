import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// Lecture/écriture du cache local du Relevé Environnemental (research.md §5). Chaque
// application (air-quality-field, pollen-field) dispose de son propre Application.Storage
// isolé (research.md §9) ; ce Store gère uniquement le relevé de l'application courante.
module AeroPollenCore {

    (:background)
    class EnvironmentalReadingStore {

        private const STORAGE_KEY = "environmentalReading";

        // Persiste un relevé "à jour" dans le cache local.
        public function save(reading as EnvironmentalReading) as Void {
            var pollenScores = null as Dictionary<Storage.KeyType, Storage.ValueType>?;
            var scoresByType = reading.pollenScoresByType;
            if (scoresByType != null) {
                var scoresOut = {} as Dictionary<Storage.KeyType, Storage.ValueType>;
                var keys = scoresByType.keys();
                for (var i = 0; i < keys.size(); i++) {
                    var key = keys[i];
                    scoresOut[key as Storage.KeyType] = scoresByType[key] as Storage.ValueType;
                }
                pollenScores = scoresOut;
            }

            var readingTime = reading.readingTime;

            var record = {
                "state" => reading.state as Number,
                "latitude" => reading.latitude,
                "longitude" => reading.longitude,
                "readingTimeValue" => readingTime != null ? readingTime.value() : null,
                "airQualityIndex" => reading.airQualityIndex,
                "pollenScoresByType" => pollenScores
            } as Dictionary<Storage.KeyType, Storage.ValueType>;

            Storage.setValue(STORAGE_KEY, record);
        }

        // Marque le cache comme indisponible (FR-005, FR-009, FR-010) : aucune ancienne valeur
        // numérique ne doit être présentée comme fiable.
        public function markUnavailable() as Void {
            save(EnvironmentalReading.unavailable());
        }

        // Charge le dernier relevé connu. En l'absence de tout relevé en cache (première
        // exécution), retourne un relevé "indisponible" plutôt qu'une exception ou un écran vide
        // (contracts/garmin-datafields.md, Délai d'affichage initial).
        public function load() as EnvironmentalReading {
            var stored = Storage.getValue(STORAGE_KEY);
            if (!(stored instanceof Dictionary)) {
                return EnvironmentalReading.unavailable();
            }

            var data = stored as Dictionary;
            var state = data["state"];
            if (state == null || state == STATE_UNAVAILABLE) {
                return EnvironmentalReading.unavailable();
            }

            var latitude = data["latitude"];
            var longitude = data["longitude"];
            var readingTimeValue = data["readingTimeValue"];
            if (!(latitude instanceof Float) || !(longitude instanceof Float) || !(readingTimeValue instanceof Number)) {
                return EnvironmentalReading.unavailable();
            }

            var rawPollenScores = data["pollenScoresByType"];
            var pollenScoresByType = null as Dictionary<PollenType, Number?>?;
            if (rawPollenScores instanceof Dictionary) {
                var scoresIn = rawPollenScores as Dictionary;
                var scoresOut = {} as Dictionary<PollenType, Number?>;
                var keys = scoresIn.keys();
                for (var i = 0; i < keys.size(); i++) {
                    var key = keys[i] as PollenType;
                    scoresOut[key] = scoresIn[key] as Number?;
                }
                pollenScoresByType = scoresOut;
            }

            return EnvironmentalReading.upToDate(
                latitude as Float,
                longitude as Float,
                new Time.Moment(readingTimeValue as Number),
                data["airQualityIndex"] as Number?,
                pollenScoresByType
            );
        }
    }
}
