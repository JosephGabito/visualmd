// Selects a local Mermaid engine without letting platform libraries cross
// into the composition root.
export 'mermaid_renderer_stub.dart'
    if (dart.library.js_interop) 'mermaid_renderer_web.dart'
    if (dart.library.io) 'mermaid_renderer_native.dart';
