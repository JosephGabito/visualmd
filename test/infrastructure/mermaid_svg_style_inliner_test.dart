import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/mermaid/svg_style_inliner.dart';

void main() {
  test('the SVG cascade becomes presentation attributes', () {
    final result = inlineSvgStyles('''
<svg id="diagram" viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg">
  <style>
    #diagram { fill: #111; font-size: 14px; }
    #diagram .node rect { fill: #eee; stroke: #555; }
    #diagram .accent { fill: #f00 !important; }
  </style>
  <g class="node"><rect class="accent" style="fill: #0f0" /></g>
</svg>
''');

    expect(result, isNot(contains('<style')));
    expect(result, contains('viewBox="0 0 10 10"'));
    expect(result, contains('font-size="14px"'));
    expect(result, contains('stroke="#555"'));
    expect(result, contains('fill="#f00"'));
  });

  test('a later equally specific rule wins without disturbing geometry', () {
    final result = inlineSvgStyles('''
<svg id="diagram" viewBox="0 0 20 30" xmlns="http://www.w3.org/2000/svg">
  <style>
    #diagram .line { stroke: #111; }
    #diagram .line { stroke: #222; stroke-width: 2px; }
  </style>
  <path class="line" d="M 0 0 L 20 30" />
</svg>
''');

    expect(result, contains('viewBox="0 0 20 30"'));
    expect(result, contains('d="M 0 0 L 20 30"'));
    expect(result, contains('stroke="#222"'));
    expect(result, contains('stroke-width="2px"'));
  });

  test('browser layout and URL-bearing CSS do not become SVG attributes', () {
    final result = inlineSvgStyles('''
<svg id="diagram" viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg">
  <style>
    #diagram .node {
      fill: #eee;
      position: absolute;
      margin: 20px;
      href: url(https://example.com/tracker);
      src: url(https://example.com/font.woff2);
    }
  </style>
  <rect class="node" width="10" height="10" />
</svg>
''');

    expect(result, contains('fill="#eee"'));
    expect(result, isNot(contains('position=')));
    expect(result, isNot(contains('margin=')));
    expect(result, isNot(contains('href=')));
    expect(result, isNot(contains('src=')));
    expect(result, isNot(contains('example.com')));
  });
}
