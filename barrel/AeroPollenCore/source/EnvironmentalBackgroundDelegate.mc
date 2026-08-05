import Toybox.Background;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;

// Service en arrière-plan partagé par les deux applications (research.md §3, §9). Interroge
// Open-Meteo à intervalle régulier et met à jour le cache local de l'application courante.
// Ne bloque jamais le rendu des champs de données (FR-007) et ne doit jamais interrompre
// l'activité en cours en cas d'échec (FR-009) : toute erreur se traduit par un relevé
// "indisponible" persisté dans le cache, jamais par une exception non gérée.
module AeroPollenCore {

    // FR-003/SC-002 : actualisation au moins toutes les 15 minutes. Seul mécanisme de
    // déclenchement disponible sur la plateforme (research.md §12) : Connect IQ n'offre pas
    // d'événement natif "déplacement significatif" pour réveiller un Background Service ;
    // l'intervalle temporel fixe satisfait en pratique l'Acceptance Scenario 1 de User Story 3
    // aux vitesses d'une sortie vélo.
    (:background)
    const REFRESH_INTERVAL_SECONDS = 15 * 60;

    (:background)
    class EnvironmentalBackgroundDelegate extends System.ServiceDelegate {

        function initialize() {
            System.ServiceDelegate.initialize();
        }

        // Appelé par le firmware à l'échéance enregistrée via
        // Background.registerForTemporalEvent() (FR-003).
        public function onTemporalEvent() as Void {
            // Reprogramme systématiquement le prochain réveil au rythme normal, y compris juste
            // après le tout premier déclenchement quasi immédiat enregistré par AppBase avec un
            // Moment (cf. AirQualityFieldApp/PollenFieldApp) : garantit un intervalle stable de
            // 15 minutes une fois le premier relevé obtenu, sans dépendre du type
            // d'enregistrement (Moment ou Duration) à l'origine de ce réveil précis.
            Background.registerForTemporalEvent(new Time.Duration(REFRESH_INTERVAL_SECONDS));

            // DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : voir DebugStatus.mc.
            new DebugStatus().recordBaseline();

            var location = currentLocation();

            if (location == null) {
                // FR-010 : aucune position GPS exploitable -> aucune requête réseau, état
                // "indisponible" immédiat.
                new DebugStatus().record(AeroPollenCore.DEBUG_NO_GPS_FIX);
                new EnvironmentalReadingStore().markUnavailable();
                Background.exit(null);
                return;
            }

            var degrees = location.toDegrees();
            var client = new OpenMeteoAirQualityClient();
            client.fetch(degrees[0].toFloat(), degrees[1].toFloat(), method(:onReadingReceived));
        }

        // Callback d'OpenMeteoAirQualityClient : persiste le relevé (à jour ou indisponible,
        // FR-005/FR-009) puis termine proprement le service en arrière-plan.
        public function onReadingReceived(reading as EnvironmentalReading) as Void {
            new EnvironmentalReadingStore().save(reading);
            Background.exit(null);
        }

        private function currentLocation() as Position.Location? {
            var info = Position.getInfo();
            return info.position;
        }
    }
}
