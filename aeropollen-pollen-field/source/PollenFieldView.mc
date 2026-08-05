import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Champ de données "Pollens" (contracts/garmin-datafields.md Champ 2). Lecture seule du cache
// local ; aucun appel réseau dans compute()/onUpdate() (FR-007). Distingue l'état
// "indisponible" (FR-005) de l'absence de donnée pollen pour la zone/saison (Edge Case,
// User Story 2 scénario 2).
class PollenFieldView extends WatchUi.DataField {

    private var _reading as AeroPollenCore.EnvironmentalReading;

    function initialize() {
        DataField.initialize();
        _reading = AeroPollenCore.EnvironmentalReading.unavailable();
    }

    function onLayout(dc as Dc) as Void {
        var obscurityFlags = DataField.getObscurityFlags();

        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.TopLeftLayout(dc));
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.TopRightLayout(dc));
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.BottomLeftLayout(dc));
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.BottomRightLayout(dc));
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));
            var labelView = View.findDrawableById("label") as Text;
            labelView.locY = labelView.locY - 16;
            var valueView = View.findDrawableById("value") as Text;
            valueView.locY = valueView.locY + 7;
        }

        (View.findDrawableById("label") as Text).setText(Rez.Strings.FieldLabel);
    }

    // Lecture seule du cache alimenté par EnvironmentalBackgroundDelegate (research.md §3, §9) ;
    // ne déclenche jamais de requête réseau (FR-007, SC-004).
    function compute(info as Activity.Info) as Void {
        _reading = new AeroPollenCore.EnvironmentalReadingStore().load();
    }

    function onUpdate(dc as Dc) as Void {
        (View.findDrawableById("Background") as Background).setColor(getBackgroundColor() as ColorValue);

        var value = View.findDrawableById("value") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            value.setColor(Graphics.COLOR_WHITE);
        } else {
            value.setColor(Graphics.COLOR_BLACK);
        }

        // DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : remplace "N/D" par le dernier code obtenu,
        // réparti label/value pour éviter la troncature (voir TROUBLESHOOTING.md §11).
        if (_reading.isUnavailable()) {
            var debugStatus = new AeroPollenCore.DebugStatus();
            (View.findDrawableById("label") as Text).setText(
                debugStatus.readCode().toString() + "/F" + debugStatus.readBaselineFreeKB().toString()
            );
            value.setText("B" + debugStatus.readFinalFreeKB().toString());
        } else {
            (View.findDrawableById("label") as Text).setText(Rez.Strings.FieldLabel);
            value.setText(displayValueFor(_reading));
        }

        View.onUpdate(dc);
    }

    // Extrait pour être directement testable (PollenFieldIntegrationTest.mc) sans dépendre du
    // cycle de rendu complet du simulateur.
    function displayValueFor(reading as AeroPollenCore.EnvironmentalReading) as String {
        if (reading.isUnavailable()) {
            // FR-005 : état "indisponible" explicite, jamais d'ancienne valeur ni d'écran vide.
            return WatchUi.loadResource(Rez.Strings.UnavailableValue) as String;
        }

        var globalScore = reading.pollenScoreGlobal;
        if (globalScore == null) {
            // Aucune donnée pollen pour cette zone/saison (Edge Case), distinct de "indisponible".
            return WatchUi.loadResource(Rez.Strings.NoPollenDataValue) as String;
        }

        return (globalScore as Number).toString();
    }
}
