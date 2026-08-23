import 'package:web/web.dart' as web;

/// Adapter: hands a link the reader clicked to the browser, in a new tab.
void openInBrowser(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
