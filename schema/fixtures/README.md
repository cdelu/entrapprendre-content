# Renderer contract fixtures

`supported-blocks.json` preserves the twelve supported block examples from
commit `c62beae`, plus the `textarea` and `scale` exercise examples. The support
manifest points here instead of into editable course lessons. Keep these array
positions stable, or update the corresponding manifest pointers together.

This is a **structural test fixture**, not a learner unit, an approved lesson,
or evidence of visual/audio acceptance. Its synthetic header has draft status.
The old sample audio reference is omitted; `media/atelier.jpg` is a path-shape
example only and its sample bytes are intentionally not restored. Image delivery
and real playback require separate tests with actual authorized media.

Fixtures stay under `schema/`, outside `source/units/` and the catalogue, so the
release builder does not ship them. No renderer/editor support statuses changed.
The production validator and builder are unchanged.

Run the normal source/release validation, then the regression check:

```text
dart run tool/smoke_support_fixtures.dart
```

The check resolves every implemented block/exercise pointer and runs the real
release validator in a temporary copy. It confirms that reordering course blocks
does not break the fixtures, while a wrong-kind or missing fixture still fails.
It does not claim to test FlutterFlow rendering or media decoding.
