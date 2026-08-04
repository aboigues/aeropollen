import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Point d'entrée de l'application "Pollens" (contracts/garmin-datafields.md Champ 2).
(:background)
class PollenFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();

        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(
                new Time.Duration(EnvironmentalCore.REFRESH_INTERVAL_SECONDS)
            );
        }
    }

    // Cf. research.md §11 : contournement nécessaire lorsqu'une vue non annotée est référencée
    // depuis une classe AppBase annotée (:background) qui utilise aussi une classe de Barrel
    // annotée (:background) (EnvironmentalCore.EnvironmentalBackgroundDelegate).
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new $.PollenFieldView() ];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new EnvironmentalCore.EnvironmentalBackgroundDelegate() ];
    }
}
