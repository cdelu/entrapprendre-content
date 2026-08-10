# Entr'Apprendre content repository

This public repository contains the downloadable course content for the Entr'Apprendre learner app. FlutterFlow application code does not live here.

Repository: [cdelu/entrapprendre-content](https://github.com/cdelu/entrapprendre-content)

## Structure

- `source/catalog.source.json` — normalized course, parts, modules, and unit summaries.
- `source/units/<UNIT_ID>/unit.json` — ordered pedagogical blocks for a unit.
- `schema/` — JSON contracts.
- `tool/validate_content.dart` — source and release validation.
- `tool/build_release.dart` — deterministic release builder.
- `.github/workflows/publish-content.yml` — manual GitHub Release workflow.
- `dist/` — ignored local build output; never edit or commit it.

Stable IDs such as `M02` and `M02-U01` must remain unchanged when titles or order change. Downloads and local learner progress depend on them. IDs are internal and never learner-facing.

## Current release

The current stable release is [`content-v0.3.1`](https://github.com/cdelu/entrapprendre-content/releases/tag/content-v0.3.1). It contains seven modules, 37 unit summaries, and the remotely loadable `M02-U01` reference unit.

The learner app uses:

```text
https://github.com/cdelu/entrapprendre-content/releases/latest/download/catalog.json
```

## Validate

```powershell
dart analyze
dart run tool/validate_content.dart
dart run tool/validate_content.dart --release
dart run tool/smoke_audio_delivery.dart
```

Release validation permits valid draft/review catalogue entries but packages only units whose unit document is `published`.

## Build locally

Use a new immutable tag; the example below is illustrative:

```powershell
dart run tool/build_release.dart --tag content-v0.4.0
```

The builder creates `dist/content-v0.4.0/` and refuses to overwrite an existing output. It derives:

- nested FlutterFlow navigation;
- learner-facing unit labels;
- one progress entry per unit with module boundaries;
- standalone versioned unit JSON;
- core and optional media ZIPs for published units;
- immutable URLs, byte sizes, versions, and SHA-256 hashes.

## Support boundary

The unit schema recognizes more content kinds than the learner app currently renders. Studio and content authors must use the shared support manifest once it is introduced, not schema presence alone.

Current learner runtime support: text, accordion, takeaway, exercise with textarea/scale items, training-journal use of the exercise structure, and optional block audio.

See `PUBLISHING.md` for the release contract and the parent `AUTHORING_APP_HANDOFF.md` for the planned backendless Studio workflow.
