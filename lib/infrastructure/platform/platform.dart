// Picks the adapters for the platform we were compiled for.
// `js_interop` is checked first: the web toolchain also claims `dart.library.io`.
export 'platform_stub.dart'
    if (dart.library.js_interop) 'platform_web.dart'
    if (dart.library.io) 'platform_io.dart';
