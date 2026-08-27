import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../application/ports/document_viewport_geometry.dart';
import '../../domain/reading/content/document_content.dart';

typedef DocumentExtentSeedAt = DocumentExtentSeed Function(int index);
typedef DocumentBlockIndexOf = int Function(DocumentBlockId id);

/// A correction prepared while widgets reconciled document identity.
///
/// The render object consumes it exactly once during layout. Keeping the
/// consumed bit on the value avoids a repeated correction if the widget tree
/// rebuilds before the next document mutation.
final class PendingDocumentExtentCorrection {
  final DocumentExtentCorrection correction;
  bool consumed = false;

  PendingDocumentExtentCorrection(this.correction);
}

/// A lazy variable-extent list whose off-screen coordinate system is explicit.
///
/// Flutter's ordinary [SliverList] discovers positions by walking outward from
/// mounted children. That is ideal for a conventional list, but it cannot jump
/// directly into a long variable-height document or preserve an anchor when a
/// provisional estimate above it becomes exact. This sliver asks a document
/// geometry ledger for every child's leading offset, measures only the cache
/// window, and returns [SliverGeometry.scrollOffsetCorrection] before paint.
final class GeometrySliverList extends SliverMultiBoxAdaptorWidget {
  final DocumentViewportGeometry viewportGeometry;
  final int layoutRevision;
  final int itemCount;
  final DocumentExtentSeedAt seedAt;
  final DocumentBlockIndexOf indexOf;
  final ValueChanged<DocumentExtentCorrection>? onExtentCorrection;
  final PendingDocumentExtentCorrection? pendingCorrection;

  GeometrySliverList.builder({
    super.key,
    required this.viewportGeometry,
    required this.layoutRevision,
    required this.itemCount,
    required this.seedAt,
    required this.indexOf,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    this.onExtentCorrection,
    this.pendingCorrection,
  }) : super(
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: itemCount,
           findChildIndexCallback: findChildIndexCallback,
         ),
       );

  @override
  RenderGeometrySliverList createRenderObject(BuildContext context) =>
      RenderGeometrySliverList(
        childManager: context as SliverMultiBoxAdaptorElement,
        viewportGeometry: viewportGeometry,
        layoutRevision: layoutRevision,
        itemCount: itemCount,
        seedAt: seedAt,
        blockIndexOf: indexOf,
        onExtentCorrection: onExtentCorrection,
        pendingCorrection: pendingCorrection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGeometrySliverList renderObject,
  ) {
    renderObject
      ..viewportGeometry = viewportGeometry
      ..layoutRevision = layoutRevision
      ..itemCount = itemCount
      ..seedAt = seedAt
      ..blockIndexOf = indexOf
      ..onExtentCorrection = onExtentCorrection;
    renderObject.pendingCorrection = pendingCorrection;
  }
}

/// Render half of [GeometrySliverList].
final class RenderGeometrySliverList extends RenderSliverMultiBoxAdaptor {
  RenderGeometrySliverList({
    required super.childManager,
    required this._viewportGeometry,
    required this._layoutRevision,
    required this._itemCount,
    required this._seedAt,
    required this._blockIndexOf,
    this._onExtentCorrection,
    this._pendingCorrection,
  });

  DocumentViewportGeometry _viewportGeometry;
  int _layoutRevision;
  int _itemCount;
  DocumentExtentSeedAt _seedAt;
  DocumentBlockIndexOf _blockIndexOf;
  ValueChanged<DocumentExtentCorrection>? _onExtentCorrection;
  PendingDocumentExtentCorrection? _pendingCorrection;

  DocumentViewportGeometry get viewportGeometry => _viewportGeometry;
  set viewportGeometry(DocumentViewportGeometry value) {
    if (identical(value, _viewportGeometry)) return;
    _viewportGeometry = value;
    markNeedsLayout();
  }

  set layoutRevision(int value) {
    if (value == _layoutRevision) return;
    _layoutRevision = value;
    markNeedsLayout();
  }

  int get itemCount => _itemCount;
  set itemCount(int value) {
    if (value == _itemCount) return;
    _itemCount = value;
    markNeedsLayout();
  }

  DocumentExtentSeedAt get seedAt => _seedAt;
  set seedAt(DocumentExtentSeedAt value) {
    _seedAt = value;
    markNeedsLayout();
  }

  set blockIndexOf(DocumentBlockIndexOf value) {
    _blockIndexOf = value;
    markNeedsLayout();
  }

  set onExtentCorrection(ValueChanged<DocumentExtentCorrection>? value) {
    _onExtentCorrection = value;
  }

  set pendingCorrection(PendingDocumentExtentCorrection? value) {
    if (identical(value, _pendingCorrection)) return;
    _pendingCorrection = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final sliverConstraints = constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);
    try {
      final pending = _pendingCorrection;
      if (pending != null && !pending.consumed) {
        pending.consumed = true;
        _onExtentCorrection?.call(pending.correction);
        if (pending.correction.scrollOffsetDelta != 0) {
          geometry = SliverGeometry(
            scrollOffsetCorrection: pending.correction.scrollOffsetDelta,
          );
          return;
        }
      }
      if (_itemCount == 0 || _viewportGeometry.length == 0) {
        if (firstChild != null) collectGarbage(childCount, 0);
        geometry = SliverGeometry.zero;
        return;
      }

      if (_viewportGeometry.layoutRevision != _layoutRevision) {
        final anchor = _viewportGeometry.blockAtOffset(
          sliverConstraints.scrollOffset,
        );
        final correction = _viewportGeometry.relayout(
          revision: _layoutRevision,
          estimatedExtents: Iterable<double>.generate(
            _itemCount,
            (index) => _seedAt(index).estimatedExtent,
          ),
          anchor: anchor,
        );
        _onExtentCorrection?.call(correction);
        if (correction.scrollOffsetDelta != 0) {
          geometry = SliverGeometry(
            scrollOffsetCorrection: correction.scrollOffsetDelta,
          );
          return;
        }
      }

      final cacheStart =
          sliverConstraints.scrollOffset + sliverConstraints.cacheOrigin;
      final cacheEnd = cacheStart + sliverConstraints.remainingCacheExtent;
      final desiredId = _viewportGeometry.blockAtOffset(cacheStart);
      if (desiredId == null) {
        geometry = SliverGeometry.zero;
        return;
      }
      final desiredIndex = _blockIndexOf(desiredId).clamp(0, _itemCount - 1);

      final currentFirst = firstChild == null ? null : indexOf(firstChild!);
      final currentLast = lastChild == null ? null : indexOf(lastChild!);
      final desiredOutsideMountedRange =
          currentFirst == null ||
          currentLast == null ||
          desiredIndex < currentFirst ||
          desiredIndex > currentLast;
      if (desiredOutsideMountedRange && firstChild != null) {
        collectGarbage(childCount, 0);
      }
      if (firstChild == null &&
          !addInitialChild(
            index: desiredIndex,
            layoutOffset: _leadingOffset(desiredIndex),
          )) {
        geometry = SliverGeometry.zero;
        return;
      }

      final childConstraints = sliverConstraints.asBoxConstraints();
      final anchorId = _viewportGeometry.blockAtOffset(
        sliverConstraints.scrollOffset,
      );
      var contentDelta = 0.0;
      var scrollDelta = 0.0;
      var leadingGarbage = 0;
      var reachedEnd = false;
      var child = firstChild!;
      RenderBox? lastLaidOut;

      while (true) {
        final childIndex = indexOf(child);
        if (childIndex >= _itemCount) {
          reachedEnd = true;
          break;
        }
        child.layout(childConstraints, parentUsesSize: true);
        final seed = _seedAt(childIndex);
        final parentData = child.parentData! as SliverMultiBoxAdaptorParentData;
        parentData.layoutOffset = _viewportGeometry.leadingOffsetOf(seed.id);

        final correction = _viewportGeometry.measure(
          id: seed.id,
          itemRevision: seed.revision,
          layoutRevision: _viewportGeometry.layoutRevision,
          extent: paintExtentOf(child),
          anchor: anchorId,
        );
        if (correction != null) {
          contentDelta += correction.contentExtentDelta;
          scrollDelta += correction.scrollOffsetDelta;
        }

        final leading = _viewportGeometry.leadingOffsetOf(seed.id);
        parentData.layoutOffset = leading;
        final end = leading + paintExtentOf(child);
        lastLaidOut = child;
        if (end < cacheStart) leadingGarbage++;
        if (end >= cacheEnd) break;
        if (childIndex + 1 >= _itemCount) {
          reachedEnd = true;
          break;
        }

        final existingNext = childAfter(child);
        final next =
            existingNext != null && indexOf(existingNext) == childIndex + 1
            ? existingNext
            : insertAndLayoutChild(
                childConstraints,
                after: child,
                parentUsesSize: true,
              );
        if (next == null) {
          reachedEnd = true;
          break;
        }
        child = next;
      }

      var trailingGarbage = 0;
      var trailing = lastLaidOut == null ? firstChild : childAfter(lastLaidOut);
      while (trailing != null) {
        trailingGarbage++;
        trailing = childAfter(trailing);
      }
      collectGarbage(leadingGarbage, trailingGarbage);

      if (contentDelta != 0 || scrollDelta != 0) {
        final correction = DocumentExtentCorrection(
          contentExtentDelta: contentDelta,
          scrollOffsetDelta: scrollDelta,
        );
        _onExtentCorrection?.call(correction);
        if (scrollDelta != 0) {
          geometry = SliverGeometry(scrollOffsetCorrection: scrollDelta);
          return;
        }
      }

      final laidFirst = firstChild;
      final laidLast = lastChild;
      if (laidFirst == null || laidLast == null) {
        geometry = SliverGeometry.zero;
        return;
      }
      final firstOffset = childScrollOffset(laidFirst)!;
      final lastOffset = childScrollOffset(laidLast)! + paintExtentOf(laidLast);
      final totalExtent = _viewportGeometry.totalExtent;
      final paintExtent = calculatePaintOffset(
        sliverConstraints,
        from: firstOffset,
        to: lastOffset,
      );
      final cacheExtent = calculateCacheOffset(
        sliverConstraints,
        from: firstOffset,
        to: lastOffset,
      );
      geometry = SliverGeometry(
        scrollExtent: totalExtent,
        paintExtent: paintExtent,
        cacheExtent: cacheExtent,
        maxPaintExtent: totalExtent,
        hasVisualOverflow:
            lastOffset >
                sliverConstraints.scrollOffset +
                    sliverConstraints.remainingPaintExtent ||
            sliverConstraints.scrollOffset > 0,
      );
      childManager.setDidUnderflow(
        reachedEnd || indexOf(laidLast) == _itemCount - 1,
      );
    } finally {
      childManager.didFinishLayout();
    }
  }

  double _leadingOffset(int index) =>
      _viewportGeometry.leadingOffsetOf(_seedAt(index).id);
}
