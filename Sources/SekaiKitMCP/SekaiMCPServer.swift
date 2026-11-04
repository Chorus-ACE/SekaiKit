import Foundation
import MCP
import SekaiKit

/// A read-only MCP adapter. Each query requires an explicit game region.
public actor SekaiMCPServer {
    public typealias Loader = @Sendable (SekaiMCPCollection, SekaiLocale) async throws -> [SekaiMCPRecord]
    private let loader: Loader

    public init(loader: @escaping Loader = SekaiMCPDataSource.load) {
        self.loader = loader
    }

    /// Registers handlers before the transport starts. The caller owns the server lifecycle.
    public func makeServer() async -> Server {
        let server = Server(name: "SekaiKit", version: "1.0.0", capabilities: .init(tools: .init()))
        await server.withMethodHandler(ListTools.self) { _ in .init(tools: Self.tools) }
        await server.withMethodHandler(CallTool.self) { params in
            try await self.callTool(name: params.name, arguments: params.arguments ?? [:])
        }
        return server
    }

    public static let tools: [Tool] = {
        let collection: Value = .object(["type": "string", "enum": .array(SekaiMCPCollection.allCases.map { .string($0.rawValue) })])
        let locale: Value = .object(["type": "string", "enum": .array(SekaiLocale.allCases.map { .string($0.rawValue) })])
        func schema(_ properties: [String: Value], required: [String]) -> Value {
            .object(["type": "object", "properties": .object(properties), "required": .array(required.map { .string($0) }), "additionalProperties": false])
        }
        let tools = [
            Tool(name: "sekai_list_regions", description: "List supported Project SEKAI game regions. Regions have independent availability, dates and translations.", inputSchema: schema([:], required: [])),
            Tool(name: "sekai_search", description: "Search a regional collection by name or exact ID. Empty query lists records. Results are ID-ordered summaries; use sekai_get for details. No cross-region fallback.", inputSchema: schema([
                "collection": collection, "locale": locale,
                "query": .object(["type": "string", "maxLength": 256]),
                "offset": .object(["type": "integer", "minimum": 0]),
                "limit": .object(["type": "integer", "minimum": 1, "maximum": 100])
            ], required: ["collection", "locale"])),
            Tool(name: "sekai_get", description: "Get the complete SekaiKit Codable record by ID in a specific region. Dates are ISO 8601; localized fields retain SekaiKit's Codable structure. No cross-region fallback.", inputSchema: schema([
                "collection": collection, "locale": locale,
                "id": .object(["type": "integer", "minimum": 1])
            ], required: ["collection", "locale", "id"]))
        ]
        return tools.map { tool in
            var tool = tool
            tool.annotations = .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true)
            return tool
        }
    }()

    public func callTool(name: String, arguments: [String: Value]) async throws -> CallTool.Result {
        guard Self.tools.contains(where: { $0.name == name }) else { throw MCPError.invalidParams("Unknown tool: \(name)") }
        let allowed: Set<String> = name == "sekai_list_regions" ? [] : name == "sekai_get"
            ? ["collection", "locale", "id"] : ["collection", "locale", "query", "offset", "limit"]
        guard Set(arguments.keys).isSubset(of: allowed) else { throw MCPError.invalidParams("Unexpected argument") }
        if name == "sekai_list_regions" {
            return try result(.object(["regions": .array(SekaiLocale.allCases.map { .string($0.rawValue) })]))
        }
        guard let rawCollection = arguments["collection"]?.stringValue,
              let collection = SekaiMCPCollection(rawValue: rawCollection),
              let rawLocale = arguments["locale"]?.stringValue,
              let locale = SekaiLocale(rawValue: rawLocale) else {
            throw MCPError.invalidParams("A supported collection and locale (jp, en, tw, cn, kr) are required")
        }
        let id = name == "sekai_get" ? try integer(arguments, "id", default: nil, range: 1...Int.max) : nil
        let offset = name == "sekai_search" ? try integer(arguments, "offset", default: 0, range: 0...Int.max) : 0
        let limit = name == "sekai_search" ? try integer(arguments, "limit", default: 20, range: 1...100) : 20
        if let query = arguments["query"], query.stringValue == nil || (query.stringValue?.count ?? 0) > 256 {
            throw MCPError.invalidParams("query must be a string of at most 256 characters")
        }
        do {
            try Task.checkCancellation()
            let records = try await loader(collection, locale)
            try Task.checkCancellation()
            if let id {
                guard let record = records.first(where: { $0.id == id }) else {
                    return .init(content: [.text(text: "Record \(id) is not available in \(collection.rawValue) for \(locale.rawValue).", annotations: nil, _meta: nil)], isError: true)
                }
                return try result(.object(["collection": .string(rawCollection), "locale": .string(rawLocale), "record": record.data]))
            }
            let query = arguments["query"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let matches = records.filter {
                query.isEmpty || String($0.id) == query || ($0.name?.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
            }.sorted { $0.id < $1.id }
            let page = matches.dropFirst(offset).prefix(limit)
            let next = offset < matches.count && page.count < matches.count - offset ? offset + page.count : nil
            return try result(.object([
                "collection": .string(rawCollection), "locale": .string(rawLocale), "total": .int(matches.count),
                "nextOffset": next.map(Value.int) ?? .null,
                "records": .array(page.map { .object(["id": .int($0.id), "name": $0.name.map(Value.string) ?? .null]) })
            ]))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .init(content: [.text(text: "Data query failed: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
        }
    }

    private func integer(_ arguments: [String: Value], _ key: String, default fallback: Int?, range: ClosedRange<Int>) throws -> Int {
        guard let value = arguments[key] else {
            if let fallback { return fallback }
            throw MCPError.invalidParams("\(key) is required")
        }
        guard case .int(let number) = value, range.contains(number) else {
            throw MCPError.invalidParams("\(key) must be an integer in \(range)")
        }
        return number
    }

    private func result(_ value: Value) throws -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(value), as: UTF8.self)
        return .init(content: [.text(text: json, annotations: nil, _meta: nil)], structuredContent: Optional(value), isError: false)
    }
}
