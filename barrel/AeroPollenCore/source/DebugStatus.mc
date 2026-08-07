import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;

// DIAGNOSTIC TEMPORAIRE (terrain, 2026-08) : trace, via Application.Storage (seul canal qui
// survit à un crash puisqu'il est écrit en synchrone à chaque étape), le point le plus avancé
// atteint dans le cycle de vie de l'app ainsi que le message de toute exception interceptée.
// Aucun débogueur ni log persistant n'est disponible sur un appareil physique sideloadé avec une
// clé développeur (ERA de Garmin ne couvre que les apps publiées sur le store, cf.
// TROUBLESHOOTING.md §12). Les fichiers Storage bruts (Garmin/Apps/DATA/<App>.DAT) restent
// lisibles depuis le PC via `strings`/`xxd` même si l'app plante avant d'atteindre onUpdate() et
// ne peut donc rien afficher elle-même. À retirer une fois la cause du "logo" confirmée et
// corrigée.
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
        private const KEY_CHECKPOINT = "debug_checkpoint";
        private const KEY_EXCEPTION_STAGE = "debug_exception_stage";
        private const KEY_EXCEPTION_MESSAGE = "debug_exception_message";
        private const KEY_RESPONSE_DETAIL = "debug_response_detail";
        private const KEY_REQUEST_DETAIL = "debug_request_detail";
        private const KEY_PHONE_CONNECTED = "debug_phone_connected";

        private const MEMORY_READ_FAILED = -1;
        private const NONE_TEXT = "-";

        // Appelé au tout début de onTemporalEvent(), avant toute allocation liée à la requête.
        public function recordBaseline() as Void {
            Storage.setValue(KEY_BASELINE_FREE_KB, freeMemoryKB());
        }

        // Appelé avec le code obtenu (réponse Communications, ou sentinelle DEBUG_*).
        public function record(code as Number) as Void {
            Storage.setValue(KEY_CODE, code);
            Storage.setValue(KEY_FINAL_FREE_KB, freeMemoryKB());
        }

        // Marque le point le plus avancé atteint dans le cycle de vie (initialize, getInitialView,
        // onLayout, compute, onUpdate...). Écrit en synchrone : reste lisible même si l'étape
        // suivante fait planter l'app avant tout retour à l'appelant.
        public function checkpoint(stage as String) as Void {
            Storage.setValue(KEY_CHECKPOINT, stage);
        }

        // Capture une exception interceptée à une étape donnée, sans jamais elle-même lever
        // d'exception (getErrorMessage() peut échouer sur certains types d'erreurs).
        public function recordException(stage as String, ex as Exception) as Void {
            Storage.setValue(KEY_EXCEPTION_STAGE, stage);
            var message = "?";
            try {
                message = ex.getErrorMessage();
            } catch (e) {
                message = "(getErrorMessage a échoué)";
            }
            Storage.setValue(KEY_EXCEPTION_MESSAGE, message);
        }

        // Capture un extrait textuel du corps de la réponse HTTP (ex. le champ "reason" renvoyé
        // par Open-Meteo sur une erreur 400), tronqué pour rester affichable sur un champ.
        public function recordResponseDetail(text as String?) as Void {
            Storage.setValue(KEY_RESPONSE_DETAIL, text);
        }

        public function readResponseDetail() as String {
            var value = Storage.getValue(KEY_RESPONSE_DETAIL);
            return value instanceof String ? value as String : NONE_TEXT;
        }

        // Capture les paramètres exacts envoyés dans la requête (ex. coordonnées), distinct du
        // corps de la réponse pour ne pas les écraser mutuellement.
        public function recordRequestDetail(text as String?) as Void {
            Storage.setValue(KEY_REQUEST_DETAIL, text);
        }

        public function readRequestDetail() as String {
            var value = Storage.getValue(KEY_REQUEST_DETAIL);
            return value instanceof String ? value as String : NONE_TEXT;
        }

        // Capture System.getDeviceSettings().phoneConnected au moment précis de la tentative
        // réseau, pour savoir si le téléphone était vraiment apparié à cet instant quand -104
        // (BLE_CONNECTION_UNAVAILABLE) est obtenu malgré Garmin Connect Mobile affiché "connecté".
        public function recordPhoneConnected(connected as Boolean) as Void {
            Storage.setValue(KEY_PHONE_CONNECTED, connected);
        }

        public function readPhoneConnected() as String {
            var value = Storage.getValue(KEY_PHONE_CONNECTED);
            if (value instanceof Boolean) {
                return (value as Boolean) ? "P1" : "P0";
            }
            return "P?";
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

        public function readCheckpoint() as String {
            var value = Storage.getValue(KEY_CHECKPOINT);
            return value instanceof String ? value as String : NONE_TEXT;
        }

        public function readExceptionStage() as String {
            var value = Storage.getValue(KEY_EXCEPTION_STAGE);
            return value instanceof String ? value as String : NONE_TEXT;
        }

        public function readExceptionMessage() as String {
            var value = Storage.getValue(KEY_EXCEPTION_MESSAGE);
            return value instanceof String ? value as String : NONE_TEXT;
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
