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

### 3D wardrobe

Load one region explicitly. SekaiKit requests only `regions/{locale}.json`; it does
not load the merged catalog, consult other regions, or fall back across regions.

```swift
let library = try await Model3DClient.shared.library(for: .jp)
if let character = library.characters.first(where: { $0.characterID == 19 }),
   var selection = character.defaultSelection() {
    if let variant = character.costumes.first?.variants.first {
        selection.costumeID = variant.id
    }
    selection.accessoryID = nil
    let configuration = try library.resolve(selection)
    // Pass configuration.recipeJSON to Haruki's window.loadModel(...).
    // Serve resources with Model3DClient.shared.resource(at:in:).
}
```

`Model3DLibrary.locale` records the chosen region. Its characters expose `costumes`,
`hairstyles`, and `accessories`, grouped into color variants. Names and color names
are plain optional strings from that region; source metadata is available directly
on each variant. There is no LocalizedData wrapper or cross-region identity map.

A selection retains its region and cannot be used with another region's library.
Changing regions means loading that region's library and starting a new selection.
Complete head accessories set `hairstyleIsLocked`; removing them restores independent
hairstyle selection. Renderer head-slot details stay inside SekaiKit.

Older regional indexes without grouping metadata remain readable and show one entry
per exported variant. Model files are still cached and shared by content hash across
regions; separating indexes does not force duplicate resource downloads.

### Experimental device-side 3D processing

The regular `Model3DClient` and regional wardrobes remain unchanged. The separate
prototype API downloads original Unity Bundles and converts a bounded JP sample
on the device:

```swift
let source = try Model3DDeviceSourceManifest.japaneseSamples()
let result = try await Model3DDeviceClient.shared.prepare(
    partID: "body-7002", manifest: source
)
// result.directory contains locally generated scene.json and textures/*.png.
// result.cacheHit / downloadedBytes / conversionSeconds describe this request.
```

The sample source plan is pinned to three parts and five dependency Bundles
(4.23 MB total). It contains no converted meshes or PNGs. The native importer is
in `Packages/SekaiModelImporter`; its README documents format support, limits and
verification. Its implementation types are not exposed through SekaiKit's public
API. GreatSekai exposes the prototype as a separate tool.

This first stage previews authored rest-pose geometry with diffuse textures.
Animation, skin colors, dedicated SEKAI materials, physics and complete character
assembly are not yet integrated, so this API does not replace the existing viewer.
Physical iPhone performance and peak memory still require measurement.

The experimental device importer can now use dynamic, regional source catalogs:

```swift
let sources = Model3DDeviceSourceClient.shared
let region = try await sources.catalog(for: .jp)
let parts = try await sources.parts(for: 1, in: region)
if let part = parts.parts.first(where: \.isReady) {
    let plan = try await sources.manifest(for: part, in: parts)
    let model = try await Model3DDeviceClient.shared.prepare(partID: part.id, manifest: plan)
    // model.directory contains locally generated scene.json and textures/.
}
```

Only the selected character's metadata and part dependency plan are fetched.
Pending source checks are explicit, regional data is never combined, and immutable
metadata is SHA-256 verified and cached. Other regions expose their own directories
but on-device import remains JP-only; colour variants and full rendering semantics
remain outside this prototype. See the asset repository's `DEVICE-SOURCES.md` for
scheduled update budgets and publication contracts.
