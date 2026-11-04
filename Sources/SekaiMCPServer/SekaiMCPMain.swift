import Foundation
import SekaiKitMCP
import MCP

@main
struct SekaiMCPMain {
    static func main() async throws {
        #if os(macOS)
        let adapter = SekaiMCPServer()
        let server = await adapter.makeServer()
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
        #else
        fatalError("The sekai-mcp stdio executable requires macOS.")
        #endif
    }
}
