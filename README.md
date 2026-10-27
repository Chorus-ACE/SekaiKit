# SekaiKit

SekaiKit is a Swift package for Project Sekai data.

The structure will be highly similar to `DoriKit`.

All master-data loaders use Protobuf archives published by JSON2Proto to
`Chorus-ACE/Sekai-Protobuf-Assets`. Regional lists include JP, EN, TC, CN and KR;
TC maps to `SekaiLocale.tw`. Existing lookup and caching APIs remain available.

| Archive | Content |
| --- | --- |
| `character.aar` | Characters and profiles |
| `event.aar` | Events, bonuses and card/song associations |
| `card.aar` | Cards and parameters |
| `gacha.aar` | Gachas, pools, rates and draw configuration |
| `song.aar` | Songs, credits, tags, charts, vocals, vocalist names, unlock conditions and shared music statistics |
| `fixture.aar` | Fixtures, genre names and all blueprint material recipes |
| `sticker.aar` | Stickers |
| `comic.aar` | Loading-screen comics |
| `skill.aar` | Skills, effects and level values |
| `release_condition.aar` | Unlock conditions |
| `episode.aar` | Event/unit/card episode directories and character mappings |

Only scenario bodies still use on-demand JSON `.asset` requests. Images and audio remain separate media.
No master-data loader falls back to regional JSON. Publish all archives before shipping this client.
New fixture fields decode as unknown in older property-list caches. Gacha wire additions preserve old
field numbers and decode legacy enum values. Skill effect duration is now `Double` to preserve half-seconds.

AppleArchive decompresses the expected `.proto` entry before Protobuf decoding.
Requests, network caches and preload hooks all use compressed `.aar` bytes;
there is no download fallback to raw `.proto` files. The archive reader validates
the entry name/type and size without extracting entry paths onto the filesystem.

SwiftProtobufPlugin generates internal wire types from `SekaiKit/Protobuf/`.
Those schemas are copied from JSON2Proto's `SekaiProtoDef/` using its
`Scripts/sync-protos.sh`; update both repositories together and publish the assets
before releasing the reader. Missing, unsuccessful or malformed downloads return
`nil` from `allInLocale`.

Use a mirror or a directory containing generated `.aar` files with a task-local URL:

```swift
await SekaiProtobuf.$baseURL.withValue(URL(filePath: "/path/to/output")) {
    let cards = await Card.allInLocale(.jp)
}
```

Run `swift test` for mapping and reader tests. To also check JSON2Proto output for
all five regions, set `SEKAI_PROTOBUF_TEST_ASSETS` to the absolute archive directory.

For all additional archives and JSON parity checks, also set
`SEKAI_ADDITIONAL_PROTOBUF_ASSETS` and `SEKAI_PROTOBUF_MASTER_DATA` (the converter's offline input directory).
The external statistics endpoint may deny downloads; verification archives containing synthetic statistics
are test artifacts and must not be published.

### On-device 3D wardrobe

The production viewer uses `Model3DLocalClient`. Load the requested region, then
only the selected character's compressed metadata. There is no merged index or
cross-region model fallback.

```swift
let client = Model3DLocalClient.shared
let library = try await client.library(for: .jp)
let wardrobe = try await client.wardrobe(for: "19:school_refusal", in: library)
if var selection = wardrobe.character.defaultSelection() {
    // wardrobe.character exposes costumes, hairstyles and accessories, with variants.
    selection.accessoryID = nil
    let configuration = try await client.prepare(selection, in: wardrobe)
    // Pass configuration.recipeJSON to the embedded window.loadModel(...).
    // Serve sekai3d://runtime paths via client.resource(at:in:).
}
```

Role IDs come from `library.roles`; Virtual Singer support units have separate
identities. A selection cannot be used with another region's wardrobe. Complete
head sets supply their own hairstyle and set `hairstyleIsLocked`. Original
regional attachment and grouping metadata remains on each `CostumeVariant`.

`prepare` downloads the selected original Unity dependency closure from its
regional official source. It converts geometry, bind poses, weights, morphs,
materials, textures, controllers and animation in Swift/C++ on a utility task.
The embedded Haruki runtime assembles parts, applies its SEKAI materials and skin
colors, plays the local motion and simulates hair/clothing springs. Converted
model Releases, Python and .NET are not needed on the client.

Metadata is SHA-256 verified before bounded DEFLATE decompression. V2 source hashes
identify upstream builds; they are not advertised as binary checksums. On first
download the client measures and hashes the normalized Bundle, then revalidates
that SHA-256 on cache reuse. V1 plans with pinned binary SHA-256 remain supported.
Raw resources are content-addressed; derived scenes are cached per selection source
and importer revision. Model cache default: 512 MiB. Unsupported formats fail
explicitly; there is no silent fallback to the old model server.

`Model3DClient` and the V1 `Model3DDeviceSourceClient` remain for API compatibility.
The old prototype tool has been retired from GreatSekai. Low-level bounded fixture
APIs such as `Model3DDeviceSourceManifest.japaneseSamples()` are retained for tests.

See `Packages/SekaiModelImporter/README.md` for format limits and opt-in fixture
tests. Run `swift test`; set `SEKAI_LOCAL_VIEWER_BASE` to a generated V2 catalog
base to validate wardrobe metadata. `SEKAI_LOCAL_VIEWER_DOWNLOAD=1` enables one
selected default character, and `SEKAI_LOCAL_VIEWER_HEAD_TEST=1` adds one complete
head set. These tests deliberately do not download a wardrobe library. Physical
iPhone latency and peak memory still require device measurement.
