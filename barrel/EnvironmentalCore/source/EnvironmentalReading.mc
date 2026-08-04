import Toybox.Lang;
import Toybox.Time;

// Relevé Environnemental et Type de Pollen (data-model.md).
module EnvironmentalCore {

    // Type de Pollen : les six variables fournies par Open-Meteo pour l'Europe
    // (contracts/open-meteo-air-quality.md).
    (:background)
    enum PollenType {
        POLLEN_ALDER,
        POLLEN_BIRCH,
        POLLEN_GRASS,
        POLLEN_MUGWORT,
        POLLEN_OLIVE,
        POLLEN_RAGWEED
    }

    (:background)
    enum ReadingState {
        STATE_UP_TO_DATE,
        STATE_UNAVAILABLE
    }

    // Relevé Environnemental : position, horodatage, indice de qualité de l'air et
    // scores de pollens, avec un état de disponibilité (data-model.md).
    (:background)
    class EnvironmentalReading {

        public var state as ReadingState;
        public var latitude as Float?;
        public var longitude as Float?;
        public var readingTime as Moment?;
        public var airQualityIndex as Number?;
        public var pollenScoreGlobal as Number?;
        public var pollenScoresByType as Dictionary<PollenType, Number?>?;

        private function initialize(
            state as ReadingState,
            latitude as Float?,
            longitude as Float?,
            readingTime as Moment?,
            airQualityIndex as Number?,
            pollenScoresByType as Dictionary<PollenType, Number?>?
        ) {
            self.state = state;
            self.latitude = latitude;
            self.longitude = longitude;
            self.readingTime = readingTime;
            self.airQualityIndex = airQualityIndex;
            self.pollenScoresByType = pollenScoresByType;
            self.pollenScoreGlobal = EnvironmentalReading.computeGlobalPollenScore(pollenScoresByType);
        }

        // Construit un relevé marqué "indisponible" (FR-005, FR-009, FR-010) : aucune valeur
        // numérique ne doit être considérée fiable tant que ce relevé est actif.
        public static function unavailable() as EnvironmentalReading {
            return new EnvironmentalReading(STATE_UNAVAILABLE, null, null, null, null, null);
        }

        // Construit un relevé "à jour" à partir d'une position, d'un horodatage et des valeurs
        // obtenues auprès de la source de données externe (contracts/open-meteo-air-quality.md).
        public static function upToDate(
            latitude as Float,
            longitude as Float,
            readingTime as Moment,
            airQualityIndex as Number?,
            pollenScoresByType as Dictionary<PollenType, Number?>?
        ) as EnvironmentalReading {
            return new EnvironmentalReading(
                STATE_UP_TO_DATE, latitude, longitude, readingTime, airQualityIndex, pollenScoresByType
            );
        }

        public function isUpToDate() as Boolean {
            return state == STATE_UP_TO_DATE;
        }

        public function isUnavailable() as Boolean {
            return state == STATE_UNAVAILABLE;
        }

        // score_pollen_global (FR-002) : agrégation applicative des scores par type disponibles
        // (valeur maximale des types renseignés, cf. contracts/open-meteo-air-quality.md). Les
        // valeurs absentes (null, hors couverture/saison) sont ignorées sans invalider le relevé.
        private static function computeGlobalPollenScore(scores as Dictionary<PollenType, Number?>?) as Number? {
            if (scores == null || scores.size() == 0) {
                return null;
            }

            var maxScore = null;
            var values = scores.values();
            for (var i = 0; i < values.size(); i++) {
                var value = values[i];
                if (value != null && (maxScore == null || value > maxScore)) {
                    maxScore = value;
                }
            }
            return maxScore;
        }
    }
}
