{{flutter_js}}
{{flutter_build_config}}

// Flutter's default bootstrap passes serviceWorkerSettings, and flutter.js then registers
// flutter_service_worker.js whenever a worker already covers the page. Since 3.47 that worker only
// unregisters itself, and FCM's firebase-messaging-sw.js shares its scope (the base href), so each
// launch would drop the web push subscription (docs/STACK.md § Push). Ronda has no offline mode,
// so it loads without Flutter's worker.
_flutter.loader.load();
