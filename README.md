# SekaiKit

SekaiKit is a Swift package for Project Sekai data.

The structure will be highly similar to `DoriKit`.

### MCP server

`SekaiKitMCP` exposes read-only game-data queries through the official
[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk).
The `sekai-mcp` executable runs a local stdio server on macOS:

```sh
cd /path/to/SekaiKit
swift build -c release --product sekai-mcp
```

Configure your MCP host to launch the built executable directly. For hosts using
`mcpServers`, a configuration looks like this (replace the absolute path):

```json
{
  "mcpServers": {
    "sekai": {
      "command": "/path/to/SekaiKit/.build/release/sekai-mcp",
      "args": []
    }
  }
}
```

The tools are `sekai_list_regions`, `sekai_search`, and `sekai_get`. Search and
detail queries require `collection` and `locale` (`jp`, `en`, `tw`, `cn`, `kr`).
Collections: `characters`, `cards`, `events`, `gachas`, `songs`, `stickers`,
`comics`, `fixtures`. For example:

```json
{"collection":"songs","locale":"jp","query":"セカイ","limit":20,"offset":0}
```

Search matches names (case/diacritic insensitive) or an exact numeric ID and
returns ID-ordered summaries, a total, and `nextOffset` (`null` at the end).
The default limit is 20, with a maximum of 100. Omit `query` to browse.
Use `sekai_get` with the same collection/locale and an integer `id` for the full
SekaiKit Codable record. Successful responses include both JSON text and MCP
structured content. Dates use ISO 8601; localized fields keep their existing
Codable representation. Missing names remain `null`.

Queries load only the specified region using SekaiKit's existing archive and
network-cache APIs, without changing preferred locales or borrowing another
region's records/translations. First use requires access to published archives.
Missing records and download/decoding failures return tool errors; invalid
arguments return protocol errors. The executable writes MCP messages to stdout.

Applications can import `SekaiKitMCP`, call `await SekaiMCPServer().makeServer()`,
and start the returned SDK `Server` with their own transport. Keep the server
alive for the transport's lifetime. Use `SekaiProtobuf.$baseURL.withValue` around
`SekaiMCPDataSource.load` in a custom `SekaiMCPServer(loader:)` to select a mirror
or local archive directory. No Protobuf schema or published asset changes are
required for MCP support.

Run `swift test --filter SekaiMCPTests` for adapter validation.

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
Readers use the current archive and cache layouts without migration or regional JSON fallbacks.
Incomplete fixture caches are discarded and reloaded. Gacha categories use upstream strings and
rates use `Double`; obsolete enum and float fields are reserved rather than decoded.
Skill effect IDs are required by the model; durations use `Double` to preserve half-seconds.

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

### Lyrics

Lyrics are loaded separately from [Sekai-Lyrics](https://github.com/Chorus-ACE/Sekai-Lyrics),
which checks missing songs daily and refreshes all available lyrics monthly.
`try await song.lyrics()` (or `SekaiLyrics.lyrics(forSongID:)`) returns nil for an
unpublished song and throws for network, malformed-data, and song-ID errors.
The reader supports source schema versions 1–4 and retains Japanese text,
available Chinese/English translations, stanza breaks, performer segments,
ruby readings, full/game renditions, translation editions, and source/license metadata.
Translation languages are independent of `SekaiLocale`. Missing translations are
not generated. Source v4 translation editions currently contain Chinese only.
`Attribution.component` is an array of typed `Attribution.Component` values.
Within each rendition (and the document attribution list), records with the same
provider, title, source revision/link, and license are merged, with duplicate
components removed in first-seen order. Unknown components remain available as
`.unknown(String)`. The source repository's JSON format is unchanged.

```swift
if let lyrics = try await song.lyrics(), let rendition = lyrics.renditions.first {
    let lines = lyrics.lines(for: rendition, length: .full)
    let sources = rendition.provenance
}
```

Use `SekaiLyrics.$baseURL.withValue` for mirrors or a local `lyrics/` fixture directory.
Set `SEKAI_LYRICS_FIXTURES` to that directory when running
`swift test --filter SongLyricsTests` to also validate the mirrored corpus.

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
that SHA-256 on cache reuse. Source manifests must use schema v2; an explicitly
supplied binary SHA-256 is still verified.
Raw resources are content-addressed; derived scenes are cached per selection source
and importer revision. Model cache default: 512 MiB. Unsupported formats fail
explicitly; there is no silent fallback to the old model server.

The standalone `Model3DClient` and `Model3DDeviceSourceClient` use their own endpoint
contracts; they are not fallbacks for `Model3DLocalClient`. Source directories require
the current importer revision. Wardrobe parts require explicit group IDs, and local
wardrobe resources require compressed metadata with decoded sizes and compatibility
rules. Low-level bounded fixture APIs such as
`Model3DDeviceSourceManifest.japaneseSamples()` use schema v2.

See `Packages/SekaiModelImporter/README.md` for format limits and opt-in fixture
tests. Run `swift test`; set `SEKAI_LOCAL_VIEWER_BASE` to a generated V2 catalog
base to validate wardrobe metadata. `SEKAI_LOCAL_VIEWER_DOWNLOAD=1` enables one
selected default character, and `SEKAI_LOCAL_VIEWER_HEAD_TEST=1` adds one complete
head set. These tests deliberately do not download a wardrobe library. Physical
iPhone latency and peak memory still require device measurement.
