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
            Background.registerForTemporalEvent(
                new Time.Duration(AeroPollenCore.REFRESH_INTERVAL_SECONDS)
            );
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
