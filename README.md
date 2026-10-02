# SekaiKit

SekaiKit is a Swift package for Project Sekai data.

The structure will be highly similar to `DoriKit`.

Character, Event, Card and ExtendedEvent download only `character.aar`,
`event.aar` and `card.aar` archives published by JSON2Proto to
`Chorus-ACE/Sekai-Protobuf-Assets`. Each file includes JP, EN, TC, CN and KR data;
TC maps to `SekaiLocale.tw`. Existing `allInLocale`, `all`, `allWithCache`, and ID
lookup APIs continue to return SekaiKit models. Song data still uses its JSON sources.

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
