import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Point d'entrée de l'application "Qualité de l'Air" (contracts/garmin-datafields.md Champ 1).
(:background)
class AirQualityFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();

        if (Background.getTemporalEventRegisteredTime() == null) {
            // Premier lancement : Background.registerForTemporalEvent() avec un Moment déjà
            // passé déclenche l'événement quasi immédiatement (doc Toybox.Background), plutôt
            // que d'attendre REFRESH_INTERVAL_SECONDS avant le tout premier relevé.
            // EnvironmentalBackgroundDelegate reprogramme ensuite le rythme normal de 15 minutes
            // dès ce premier réveil.
            Background.registerForTemporalEvent(Time.now());
        }
    }

    // Cf. research.md §11 : contournement nécessaire lorsqu'une vue non annotée est référencée
    // depuis une classe AppBase annotée (:background) qui utilise aussi une classe de Barrel
    // annotée (:background) (AeroPollenCore.EnvironmentalBackgroundDelegate).
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new $.AirQualityFieldView() ];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new AeroPollenCore.EnvironmentalBackgroundDelegate() ];
    }
}
