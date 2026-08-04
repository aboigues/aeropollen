import Toybox.Test;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Application.Storage;

// Tests unitaires du cache EnvironmentalReadingStore (data-model.md, research.md §5).
module EnvironmentalCore {

    (:test)
    function testSaveThenLoadRoundTripsUpToDateReading(logger as Test.Logger) as Boolean {
        var store = new EnvironmentalReadingStore();
        var scores = {
            POLLEN_BIRCH => 30,
            POLLEN_GRASS => 75
        } as Dictionary<PollenType, Number?>;
        var original = EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 42, scores);

        store.save(original);
        var loaded = store.load();

        return loaded.isUpToDate()
            && loaded.latitude == 48.8566
            && loaded.longitude == 2.3522
            && loaded.airQualityIndex == 42
            && loaded.pollenScoreGlobal == 75;
    }

    (:test)
    function testMarkUnavailableIsReflectedOnLoad(logger as Test.Logger) as Boolean {
        var store = new EnvironmentalReadingStore();
        store.save(EnvironmentalReading.upToDate(48.8566, 2.3522, Time.now(), 42, null));

        store.markUnavailable();
        var loaded = store.load();

        return loaded.isUnavailable() && loaded.airQualityIndex == null;
    }

    (:test)
    function testLoadWithoutAnyPriorSaveIsUnavailable(logger as Test.Logger) as Boolean {
        Storage.clearValues();

        var store = new EnvironmentalReadingStore();
        var loaded = store.load();

        return loaded.isUnavailable();
    }
}
