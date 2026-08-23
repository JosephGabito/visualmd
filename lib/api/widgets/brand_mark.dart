import 'package:flutter/widgets.dart';

/// The detailed product mark used where the interface has room to honour it.
final class BrandMark extends StatelessWidget {
  static const assetName = 'assets/brand/visual-md-logo.png';

  final double size;

  const BrandMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) => Image.asset(
    assetName,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    // Nearby text already names Visual MD; repeating it adds noise for a
    // screen-reader without conveying another action or piece of content.
    excludeFromSemantics: true,
  );
}
