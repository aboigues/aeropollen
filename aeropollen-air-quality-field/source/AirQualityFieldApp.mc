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

        // DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : forcé à chaque lancement (au lieu de
        // seulement si aucun événement n'est déjà enregistré) pour garantir un relevé immédiat
        // à chaque réinstallation de debug, sans dépendre de l'échéance déjà programmée par une
        // installation précédente. À revenir à la condition d'origine une fois le diagnostic fini.
        Background.registerForTemporalEvent(Time.now());
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
