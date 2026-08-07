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

        // DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : voir DebugStatus.mc.
        var debug = new AeroPollenCore.DebugStatus();
        debug.checkpoint("app_init_start");
        try {
            if (Background.getTemporalEventRegisteredTime() == null) {
                Background.registerForTemporalEvent(Time.now());
            }
            debug.checkpoint("app_init_ok");
        } catch (ex) {
            debug.recordException("app_init", ex);
        }
    }

    // Cf. research.md §11 : contournement nécessaire lorsqu'une vue non annotée est référencée
    // depuis une classe AppBase annotée (:background) qui utilise aussi une classe de Barrel
    // annotée (:background) (AeroPollenCore.EnvironmentalBackgroundDelegate).
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        // DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : voir DebugStatus.mc.
        var debug = new AeroPollenCore.DebugStatus();
        debug.checkpoint("get_initial_view_start");
        var view = new $.AirQualityFieldView();
        debug.checkpoint("get_initial_view_ok");
        return [ view ];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new AeroPollenCore.EnvironmentalBackgroundDelegate() ];
    }
}
