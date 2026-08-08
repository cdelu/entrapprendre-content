# GitHub content publishing contract

## Decisions

- The learner content repository is public.
- Editable normalized JSON remains versioned in Git.
- Download archives are GitHub Release assets, not ordinary repository files or Git LFS objects.
- Releases are immutable; every correction uses a new `content-vX.Y.Z` tag.
- Stable IDs are preserved across corrections.
- Prereleases are for end-to-end testing and do not replace the stable `releases/latest` catalogue.
- Publishing a stable release requires explicit user approval.

## Stable endpoint

```text
https://github.com/cdelu/entrapprendre-content/releases/latest/download/catalog.json
```

Current stable release: [`content-v0.3.1`](https://github.com/cdelu/entrapprendre-content/releases/tag/content-v0.3.1).

## Release assets

For unit `M02-U01` at content version 3, a future release may contain:

```text
catalog.json
M02-U01-unit-v3.json
M02-U01-core-v3.zip
M02-U01-media-v3.zip       optional
M02-U01-view-01.mp3        optional direct audio asset
```

The standalone unit JSON is read directly by FlutterFlow. The core package contains unit JSON and lightweight supporting files, excluding top-level `media/`. The optional media package contains heavier media. Direct audio assets are the recommended next contract for the current network AudioPlayer but have not yet been implemented end to end.

## Derived catalogue views

Authors edit normalized `parts`, `modules`, and `units`. The builder regenerates:

- `navigation` — modules in part order, part metadata on every module, `showPartHeader` on each part’s first module, and nested unit summaries;
- `navigationSummary` — catalogue totals;
- `progressSegments` — one entry per unit with module-boundary metadata;
- `packages` — descriptors for successfully built archives.

Never hand-edit derived fields.

## Local build

```powershell
dart run tool/build_release.dart --tag content-v0.4.0
```

The builder writes a clean tag-specific directory under `dist/` and refuses to overwrite it. Draft and review units remain in catalogue navigation with `downloadable: false`; only published units produce downloadable assets.

## GitHub Actions publication

Use **Publish content release** and provide a new tag and prerelease flag. The workflow rebuilds from committed source rather than uploading local `dist/` output.

The release gate:

1. validates source in release mode;
2. verifies the release tag;
3. builds in a temporary directory;
4. validates packaged JSON;
5. calculates sizes and hashes;
6. generates `catalog.json`;
7. creates the GitHub Release and uploads assets;
8. publishes stable only after all previous steps succeed.

A failed step must not change the stable catalogue.

## Normal repository workflow

1. Fetch remote changes and create a feature branch from `origin/main`.
2. Change only normalized source, schemas, tools, tests, or documentation required by the task.
3. Run analysis and both validation modes.
4. Build and inspect a local release when useful.
5. Stage only intended files, commit, push, open a PR, review, and merge.
6. Dispatch a new immutable prerelease or stable release after approval.
7. Verify the stable catalogue, counts, one unit JSON URL, and any direct media URL.
8. Restart learner-app Test Mode if its cached API response is stale.

## Manual Studio workflow

The future backendless Studio app will produce a transfer ZIP containing release assets plus normalized source backup. The user must unpack it and upload files from `UPLOAD_TO_GITHUB_RELEASE/` individually. Uploading only the outer transfer ZIP will not work because the learner app requests exact asset names.
