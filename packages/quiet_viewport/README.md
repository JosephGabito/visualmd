# Quiet Viewport

Quiet Viewport is the rendering physics for lazy, variable-height documents.
It is deliberately independent of Markdown, application state, typography,
and Flutter widgets. A host supplies stable item identities, deterministic
extent estimates, real measurements, and the item currently anchoring the
viewport.

The package answers two questions:

1. How does a lazy viewport update its geometry without moving the content a
   reader is looking at?
2. How can the scrollbar show only user movement rather than corrections made
   by the layout engine?

## Coordinate model

For item extents `h₀ … hₙ₋₁`, the leading content coordinate of item `k` is:

```text
H(k) = Σ hᵢ, 0 ≤ i < k
```

If the viewport scroll offset is `p`, the anchor's visible coordinate is:

```text
y = H(k) − p
```

Suppose measurement corrects an item before the anchor by `Δ`. The anchor's
new content coordinate is `H'(k) = H(k) + Δ`. Choosing:

```text
p' = p + Δ
```

gives:

```text
y' = H'(k) − p' = H(k) + Δ − (p + Δ) = H(k) − p = y
```

The pixels therefore do not move.

That physical compensation is not user input. During a visible scrollbar
interaction, Quiet Viewport accumulates it as bias `c` and exposes:

```text
logicalPixels = physicalPixels − c
```

After the correction, both physical pixels and bias increase by `Δ`, so the
logical position is identical. The scrollbar's content extent is frozen for
the same interaction; measurements and tail appends therefore cannot resize
or move its thumb. A host settles onto the new geometry only after the
scrollbar is no longer visible or interactive.

## Complexity

`StableExtentLedger` uses an appendable Fenwick tree:

- identity lookup: O(1);
- append: O(log n);
- initial bulk construction: O(n);
- suffix replacement: O(r + k log n) for `r` removed and `k` inserted items;
- measurement/revision: O(log n);
- scaled layout epoch: O(log n) for anchor compensation, O(1) storage work;
- complete layout-epoch replacement: O(n);
- leading-offset query: O(log n);
- total extent: O(log n).

The implementation performs no committed-prefix scan for an ordinary append or
provisional-tail replacement. Measured extents before the replacement boundary
remain authoritative.

During a continuous resize, `scaleRelayout` multiplies the ledger's latent
coordinate scale rather than rewriting its Fenwick records. If the provisional
scale is `q`, then `H'(k) = qH(k)`. Returning
`p' = p + (q - 1)H(k)` preserves the anchor because
`H'(k) - p' = H(k) - p`. Mounted items replace their scaled estimates with real
measurements under the new layout revision; stale measurements remain fenced.

`IndexedExtentLedger` provides the same prefix geometry for immutable dense
identities `0 … n-1` without allocating a key map or per-item revision vector.
It is intended for code rows and similar media whose index is already the
stable identity.

`AppendLineIndex` maps physical text lines to source ranges. Its initial build
is O(source); an append visits only the new suffix and preserves every earlier
range. Together, these two primitives let a streaming code surface extend its
coordinate system without rereading the accumulated fence.

`AppendWrapIndex` applies the same persistence to visual lines. The host's text
engine resolves line starts inside bounded windows; the index commits every
complete line and retains only the final unfinished line for the next append.
Its steady-state work is O(new suffix + previous final line), without making
the package depend on Flutter or on one typography system. A width, face,
scale, locale, direction, or feature change is a new layout epoch and must use
`replace`, because each can legitimately change every line boundary.
When a host can prove that a completed projection changes only a known visual
suffix, `replaceTail` retains every line before that boundary and resolves only
the revised tail. A host which cannot afford the initial O(source) pass in one
frame can construct the index with `AppendWrapIndex.progressive`, grant a
bounded number of windows through `indexNext`, and publish the geometry only
after `isComplete`. Partial work never needs to become a partial scrollbar.
`withContext` and `progressiveWithContext` additionally pass each bounded
window's absolute source start to the host. This lets a projection retain
language or typography state at line boundaries without rereading its prefix.

## Revision fencing

Every item measurement names both the item revision and the layout revision.
A late measurement from replaced content, an old width, or an old type/theme
epoch is ignored before it can alter geometry.

## Status

Version 0.1 proves the framework-independent geometry. Visual MD is the first
integration and benchmark host: its API observes mounted render boxes, applies
anchor corrections through `ScrollPosition`, and paints and drags a scrollbar
from frozen metrics. A streamed tail cannot twitch a visible thumb, and a
layout epoch cannot require one estimate per offscreen item.
