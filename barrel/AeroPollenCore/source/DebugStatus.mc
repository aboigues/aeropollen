import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;

// DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : persiste le dernier code obtenu lors du relevé
// (code de réponse Communications, ou sentinelle ci-dessous) ainsi que la mémoire libre à deux
// étapes clés, pour affichage direct sur l'appareil en remplacement de "N/D" — aucun débogueur
// disponible sur Edge 530 physique. À retirer une fois la cause du N/D confirmée et corrigée.
module AeroPollenCore {

    (:background)
    const DEBUG_NEVER_RUN = -999;
    (:background)
    const DEBUG_NO_GPS_FIX = -998;

    (:background)
    class DebugStatus {

        private const KEY_CODE = "debug_code";
        private const KEY_BASELINE_FREE_KB = "debug_baseline_free_kb";
        private const KEY_FINAL_FREE_KB = "debug_final_free_kb";

        private const MEMORY_READ_FAILED = -1;

        // Appelé au tout début de onTemporalEvent(), avant toute allocation liée à la requête.
        public function recordBaseline() as Void {
            Storage.setValue(KEY_BASELINE_FREE_KB, freeMemoryKB());
        }

        // Appelé avec le code obtenu (réponse Communications, ou sentinelle DEBUG_*).
        public function record(code as Number) as Void {
            Storage.setValue(KEY_CODE, code);
            Storage.setValue(KEY_FINAL_FREE_KB, freeMemoryKB());
        }

        public function readCode() as Number {
            var value = Storage.getValue(KEY_CODE);
            return value instanceof Number ? value as Number : AeroPollenCore.DEBUG_NEVER_RUN;
        }

        public function readBaselineFreeKB() as Number {
            var value = Storage.getValue(KEY_BASELINE_FREE_KB);
            return value instanceof Number ? value as Number : MEMORY_READ_FAILED;
        }

        public function readFinalFreeKB() as Number {
            var value = Storage.getValue(KEY_FINAL_FREE_KB);
            return value instanceof Number ? value as Number : MEMORY_READ_FAILED;
        }

        private function freeMemoryKB() as Number {
            try {
                return (System.getSystemStats().freeMemory / 1024).toNumber();
            } catch (e) {
                return MEMORY_READ_FAILED;
            }
        }
    }
}
