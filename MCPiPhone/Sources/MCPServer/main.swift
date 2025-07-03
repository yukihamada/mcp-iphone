import Foundation
import MCPiPhone

// Command-line executable for running the sample MCP server
@main
struct MCPServerCLI {
    static func main() async throws {
        print("Starting iOS MCP Server...", to: &FileHandle.standardError)
        
        do {
            let server = try SampleMCPServer()
            try await server.start()
        } catch {
            print("Server error: \(error)", to: &FileHandle.standardError)
            exit(1)
        }
    }
}