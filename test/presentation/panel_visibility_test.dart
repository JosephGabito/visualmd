import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/main.dart';

void main() {
  test('only exact stored booleans can restore hidden panel state', () {
    expect(storedPanelVisibility('false'), isFalse);
    expect(storedPanelVisibility('true'), isTrue);
    expect(storedPanelVisibility(null), isTrue);
    expect(storedPanelVisibility('False'), isTrue);
    expect(storedPanelVisibility('0'), isTrue);
    expect(storedPanelVisibility('hidden'), isTrue);
  });
}
