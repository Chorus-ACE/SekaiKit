# SekaiModelImporter

Native original Unity Bundle conversion on Apple devices. Swift, Apple Compression
and statically linked MIT texture decoders produce local scene JSON and PNGs.
No Unity runtime, .NET, Python, subprocess or preconverted model is needed.

Supported input: UnityFS v6–8 (uncompressed/LZ4/LZ4HC), serialized files v17–22
with type trees, streamed mesh/texture data, standard vertex channels and triangle
indices. ASTC, ETC, selected BC, PVRTC and common uncompressed pixel formats decode
natively. Unknown formats fail explicitly.

Scenes preserve prefab transforms, rig/bind matrices, skin weights, sparse morphs,
material properties/texture transforms, character/spring controllers and raw Unity
animation clips. Color-variation bundles override the original material textures.
The embedded renderer converts Unity coordinates once and adapts these scenes to
Haruki's real composer, SEKAI materials, animation and spring runtime.

## Sources and cache

Source plans are region-specific. JP uses its official signed source; EN and the
three iOS regions use their own versioned source paths. Signed cookies remain in
memory. V1 plans enforce pinned binary SHA-256 and exact normalized length. V2
upstream `sourceHash` identifies source metadata, not file bytes. Newly downloaded
Bundles are normalized, measured, SHA-256 hashed and mapped to that source identity.
Cache reuse revalidates the actual binary hash.

Downloads and expanded data are bounded. Conversion runs off the UI thread with
cancellation; canceled work does not publish partial results. One conversion runs
per client, with subsequent requests queued. Atomic scenes/texture receipts are
SHA-256 verified; damaged outputs rebuild from valid raw cache. Raw and derived
files share a default 512 MiB cache budget, with old entries pruned after conversion.
Cache identity includes region/platform, source URL, selected dependencies, color
variation, part identity and importer revision. Unrelated names do not invalidate it.

Limits per part: 32 Bundles, 64 MiB compressed input, 128 MiB expanded input,
500,000 vertices, 16,777,216 decoded texture pixels, 4096px maximum texture edge.
There is no automatic fallback to server-converted models.

## Verification

```sh
swift test --package-path Packages/SekaiModelImporter
SEKAI_RAW_BUNDLE_FIXTURES=/path/to/input/asset-bundles \
  swift test --package-path Packages/SekaiModelImporter
```

The bounded fixture suite reuses 12 local Bundles, validates 3,987 Unity objects,
converts body/face/accessory samples (6,822 / 3,745 / 300 vertices), checks color
variation, cache repair/reuse, pixel channel order and PNG orientation.
The SDK integration suite additionally loads live regional metadata and can opt
in to a single default character per chosen region. Offscreen WKWebView tests
exercise real GPU materials, complete heads, animation and physics; they are not
physical iPhone benchmarks or proof that every upstream costume is supported.

Decoder provenance and MIT licenses are in THIRD_PARTY_NOTICES.txt. Identical
notices ship as a package resource and appear in GreatSekai Acknowledgements.
