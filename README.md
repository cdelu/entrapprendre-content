# Entr'Apprendre content repository

This public repository contains the downloadable course content for the Entr'Apprendre learner app. FlutterFlow application code does not live here.

Repository: [`cdelu/entrapprendre-content`](https://github.com/cdelu/entrapprendre-content)

## Structure

- `source/catalog.source.json`: normalized parts, modules, and unit summaries.
- `source/units/<UNIT_ID>/unit.json`: pedagogical blocks for a unit.
- `schema/`: versioned JSON contracts.
- `tool/validate_content.dart`: source and release validation.
- `tool/build_release.dart`: deterministic release builder.
- `.github/workflows/publish-content.yml`: manual GitHub Release workflow.
- `dist/`: ignored local build output; never edit or commit it.

Stable IDs such as `M02` and `M02-U01` must not change when titles or ordering are corrected. Downloaded content and local learner progress depend on them. IDs are internal and must not be shown in the learner interface.

## Validate

```powershell
dart analyze
dart run tool/validate_content.dart
dart run tool/validate_content.dart --release
```

Release validation accepts valid drafts in the catalogue but excludes them from downloadable packages.

## Build locally

```powershell
dart run tool/build_release.dart --tag content-v0.2.2
```

The builder creates `dist/content-v0.2.2/` and never edits source files. It derives:

- a FlutterFlow-friendly nested navigation list;
- learner-facing unit status/detail labels;
- one progress cell per unit with module-boundary metadata;
- immutable package URLs, byte sizes, versions, and SHA-256 hashes;
- core and optional media archives for published units.

## Published catalogue

The learner app uses:

```text
https://github.com/cdelu/entrapprendre-content/releases/latest/download/catalog.json
```

The current stable release is [`content-v0.2.2`](https://github.com/cdelu/entrapprendre-content/releases/tag/content-v0.2.2). It contains seven modules, 37 unit summaries, and catalogue-derived progress metadata.

See `PUBLISHING.md` for the release contract.
