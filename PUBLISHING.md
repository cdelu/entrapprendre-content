# GitHub content publishing contract

## Decisions

- The learner-facing content repository is public.
- Editable JSON remains versioned in Git.
- Download archives are GitHub Release assets, not normal repository files or Git LFS objects.
- Releases are immutable. Every correction uses a new `content-vX.Y.Z` tag.
- The published catalogue contains exact HTTPS URLs, byte sizes, versions, and SHA-256 hashes.
- Prereleases are for testing and do not replace the stable `releases/latest` catalogue.

## Repository and stable endpoint

- Owner: `cdelu`
- Repository: `entrapprendre-content`
- Stable catalogue:

```text
https://github.com/cdelu/entrapprendre-content/releases/latest/download/catalog.json
```

## Assets

For unit `M02-U01`, a release may contain:

```text
M02-U01-core-v1.zip
M02-U01-media-v1.zip
catalog.json
```

The core package contains unit JSON, audio, transcripts, and lightweight media. The optional media package adds heavier images or video. The initial app download contains neither package.

## Generated catalogue views

Authors edit normalized `parts`, `modules`, and `units`. The builder regenerates all delivery views:

- `navigation` flattens modules in part order, includes a part header only on the first module of each part, and nests ordered unit summaries;
- `navigationSummary` reports catalogue totals;
- `progressSegments` contains one entry per unit and marks module boundaries;
- `packages` describes only successfully built downloadable archives.

Do not hand-edit these derived fields.

## Local build

```powershell
dart run tool/build_release.dart --tag content-v0.2.2
```

The builder writes a clean tag-specific directory under `dist/` and refuses to overwrite an existing output. A unit becomes downloadable only when its `unit.json` status is `published`. Draft and review units remain visible with `downloadable: false`.

## Publication workflow

Use the GitHub Actions workflow **Publish content release** and supply the new tag plus the prerelease flag. The workflow rebuilds from committed source rather than uploading local `dist/` files.

The release gate runs in this order:

1. validate source content in release mode;
2. verify the release tag;
3. build archives in a temporary directory;
4. validate packaged JSON;
5. calculate sizes and SHA-256 hashes;
6. generate `catalog.json`;
7. create the GitHub Release and upload assets;
8. publish the stable release atomically.

A failed step must not change the stable catalogue.

## Repository workflow

For a normal content change:

1. create a feature branch;
2. stage only the intended source, schema, or tool files;
3. commit and push;
4. open a draft PR, review it, mark it ready, and merge it;
5. dispatch the release workflow with a new immutable tag;
6. wait for the workflow to succeed;
7. download the stable catalogue URL and verify counts, labels, and package metadata before testing the app.
