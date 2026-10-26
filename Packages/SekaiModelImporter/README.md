# SekaiModelImporter — device-side prototype

This package reads original UnityFS Bundles on Apple devices using Swift,
Apple Compression and a small statically linked C++ texture decoder. No .NET,
Unity runtime, desktop subprocess or preconverted mesh/PNG is required.

## Current scope

The bundled JP sample manifest contains **only metadata** for three known parts:
body 7002, face/hair 29001, accessory 2075025. Its five raw dependency Bundles
sum to 4.23 MB; selecting a part downloads only its dependency closure. The source
snapshot is pinned to asset version 7.1.0.10. This is not a complete regional index.

The importer currently supports UnityFS v6–8 (uncompressed/LZ4/LZ4HC), serialized
file v22 with type trees, streamed vertex/texture data, standard vertex channels,
triangle indices, authored transforms, prefab selection and diffuse textures.
ASTC, ETC and selected BC formats decode to local PNG. Duplicate FBX and sitting
prefabs are excluded by following the explicit body/face/optional prefab roots.

The scene previews the **authored rest pose**. It does not implement animation,
skin palettes, SEKAI shader/controller effects, SpringBone simulation or complete
character assembly. The separate experiment tool does not change the production
Haruki viewer. These missing semantics must be resolved before any default switch.

## Data and caching

`DeviceModelClient.prepare` obtains the official source signature, downloads only
the selected dependencies, normalizes the transport header, checks byte length and
pinned SHA-256, converts on a utility task, then atomically publishes the local
scene and texture files. Cookies remain in memory and are never logged.

Raw Bundles and conversion outputs are cached separately. Cache identity includes the region, platform, selected dependency hashes, part
and converter revision; unrelated index or label updates do not invalidate it. A receipt verifies every
converted resource by SHA-256. Damaged outputs rebuild from valid raw cache.
Only one conversion runs per client; cancellation prevents partial publication.
The default disk budget is 512 MiB with pruning of old entries after conversion.

Input limits: 32 Bundles, 64 MiB compressed input, 128 MiB expanded input,
500,000 vertices and 16,777,216 decoded texture pixels per conversion. Unsupported
formats fail explicitly. There is no automatic fallback to preconverted models.

## Verification

```
swift test --package-path Packages/SekaiModelImporter
SEKAI_RAW_BUNDLE_FIXTURES=/path/to/input/asset-bundles \
  swift test --package-path Packages/SekaiModelImporter
```

The optional local fixture suite reads the existing 12-Bundle experiment, checks
3,987 mesh/material/texture/transform/container objects, and converts three sample
parts with expected counts of 6,822 / 3,745 / 300 vertices.

One small official download can be explicitly enabled with
`SEKAI_RAW_NETWORK_PROBE=1`. The sample test downloads the body and its dependency,
not a whole wardrobe. Do not use it as a bulk downloader.

Measured on M4 Pro, Debug, 2026-10-26: body source download + conversion + cache
publication took about 1.83 seconds for 1.77 MB downloaded; offline conversion and
publication about 79 ms, verified cache hit about 0.8 ms. These are single-sample
Mac measurements, not iPhone results or a full-library benchmark. Memory peak and
physical iPhone performance are not yet measured.

## Next validation gates

- Physical iPhone memory, latency and cancellation measurements.
- Match Haruki's bone binding, coordinate transforms and material/skin semantics.
- Integrate runtime animation and SpringBone without depending on converted meshes.
- Produce versioned regional source plans from current master data and dependency
  indexes; the demo's pinned SHA-256 values do not establish a full-library plan.
- Expand beyond known fixtures, including variants, missing bones and new formats.

Upstream decoder provenance and licenses are in THIRD_PARTY_NOTICES.txt. The
same notices ship as a package resource and appear in GreatSekai Acknowledgements.
