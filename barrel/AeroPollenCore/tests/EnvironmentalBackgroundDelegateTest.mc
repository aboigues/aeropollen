import Toybox.Test;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;

// Tests unitaires d'EnvironmentalBackgroundDelegate (Foundational : Scénario 4 de
// quickstart.md — persistance de l'état à la réception d'un relevé ; la perte de connectivité
// réelle via Communications.makeWebRequest() et le déclenchement par Position.getInfo() ne sont
// vérifiables qu'en simulateur/appareil, cf. quickstart.md).
module AeroPollenCore {

    (:test)
    function testOnReadingReceivedPersistsUpToDateReading(logger as Test.Logger) as Boolean {
        var delegate = new EnvironmentalBackgroundDelegate();
        var reading = EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 42, null);

        delegate.onReadingReceived(reading);

        var loaded = new EnvironmentalReadingStore().load();
        return loaded.isUpToDate() && loaded.airQualityIndex == 42;
    }

    // FR-005/FR-009 : lorsque le client Open-Meteo transmet un relevé "indisponible" (échec
    // réseau, erreur API, absence de position), le cache doit refléter cet état sans conserver
    // d'ancienne valeur numérique, et sans lever d'exception.
    (:test)
    function testOnReadingReceivedPersistsUnavailableReading(logger as Test.Logger) as Boolean {
        var delegate = new EnvironmentalBackgroundDelegate();

        delegate.onReadingReceived(EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 42, null));
        delegate.onReadingReceived(EnvironmentalReading.unavailable());

        var loaded = new EnvironmentalReadingStore().load();
        return loaded.isUnavailable() && loaded.airQualityIndex == null;
    }

    // FR-003/SC-002/research.md §12 : intervalle d'actualisation fixe d'au moins 15 minutes,
    // seul mécanisme de déclenchement disponible sur la plateforme.
    (:test)
    function testRefreshIntervalIsAtLeastFifteenMinutes(logger as Test.Logger) as Boolean {
        return REFRESH_INTERVAL_SECONDS >= 15 * 60;
    }

    // research.md §14 : quel que soit le déclencheur du réveil (premier lancement via Moment
    // quasi immédiat, ou réveil normal via Duration), onTemporalEvent() doit toujours
    // reprogrammer le prochain réveil au rythme normal de 15 minutes.
    (:test)
    function testOnTemporalEventReschedulesNormalInterval(logger as Test.Logger) as Boolean {
        var delegate = new EnvironmentalBackgroundDelegate();

        delegate.onTemporalEvent();

        var registered = Background.getTemporalEventRegisteredTime();
        return registered instanceof Time.Duration
            && (registered as Time.Duration).value() == REFRESH_INTERVAL_SECONDS;
    }
}
