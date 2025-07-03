import Foundation
import MCP
import Logging

/// Manager class for handling MCP client connections and operations
@MainActor
public class MCPClientManager: ObservableObject {
    private let logger = Logger(label: "com.mcpiphone.client")
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var serverInfo: ServerInfo?
    @Published public private(set) var availableTools: [Tool] = []
    @Published public private(set) var connectionError: Error?
    
    private var client: Client?
    private var transport: Transport?
    
    public init() {}
    
    /// Connect to an MCP server using stdio transport
    /// - Parameters:
    ///   - executable: Path to the server executable
    ///   - args: Arguments to pass to the server
    ///   - env: Environment variables for the server process
    public func connectToServer(
        executable: String,
        args: [String] = [],
        env: [String: String] = [:]
    ) async throws {
        logger.info("Connecting to MCP server", metadata: [
            "executable": .string(executable),
            "args": .array(args.map { .string($0) })
        ])
        
        // Create client
        let client = Client(
            name: "MCPiPhone",
            version: "1.0.0"
        )
        
        // Create stdio transport
        let transport = Transport.stdioProcess(
            executable: executable,
            args: args,
            env: env
        )
        
        do {
            // Connect to server
            let result = try await client.connect(transport: transport)
            
            self.client = client
            self.transport = transport
            self.isConnected = true
            self.serverInfo = result.serverInfo
            self.connectionError = nil
            
            logger.info("Connected to MCP server", metadata: [
                "serverName": .string(result.serverInfo.name),
                "serverVersion": .string(result.serverInfo.version)
            ])
            
            // Check capabilities and load tools if available
            if result.capabilities.tools != nil {
                await loadAvailableTools()
            }
            
        } catch {
            logger.error("Failed to connect to MCP server", metadata: [
                "error": .string(error.localizedDescription)
            ])
            self.connectionError = error
            throw error
        }
    }
    
    /// Disconnect from the current MCP server
    public func disconnect() async {
        logger.info("Disconnecting from MCP server")
        
        if let transport = transport {
            await transport.close()
        }
        
        self.client = nil
        self.transport = nil
        self.isConnected = false
        self.serverInfo = nil
        self.availableTools = []
        self.connectionError = nil
    }
    
    /// Load available tools from the connected server
    private func loadAvailableTools() async {
        guard let client = client else { return }
        
        do {
            let result = try await client.listTools()
            self.availableTools = result.tools
            
            logger.info("Loaded tools from server", metadata: [
                "toolCount": .stringConvertible(result.tools.count),
                "tools": .array(result.tools.map { .string($0.name) })
            ])
        } catch {
            logger.error("Failed to load tools", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    /// Call a tool on the connected server
    /// - Parameters:
    ///   - toolName: Name of the tool to call
    ///   - arguments: Arguments to pass to the tool
    /// - Returns: The tool's response content
    public func callTool(
        _ toolName: String,
        arguments: [String: Any] = [:]
    ) async throws -> [Content] {
        guard let client = client else {
            throw MCPError.connectionError("Not connected to any server")
        }
        
        logger.info("Calling tool", metadata: [
            "toolName": .string(toolName),
            "arguments": .dictionary(Dictionary(uniqueKeysWithValues: 
                arguments.map { ($0.key, .string(String(describing: $0.value))) }
            ))
        ])
        
        do {
            let result = try await client.callTool(
                CallTool.Params(
                    name: toolName,
                    arguments: arguments
                )
            )
            
            logger.info("Tool call successful", metadata: [
                "toolName": .string(toolName),
                "contentCount": .stringConvertible(result.content.count)
            ])
            
            return result.content
        } catch {
            logger.error("Tool call failed", metadata: [
                "toolName": .string(toolName),
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
    
    /// List available resources from the connected server
    public func listResources() async throws -> [Resource] {
        guard let client = client else {
            throw MCPError.connectionError("Not connected to any server")
        }
        
        let result = try await client.listResources()
        return result.resources
    }
    
    /// Read a specific resource from the server
    /// - Parameter uri: The URI of the resource to read
    /// - Returns: The resource content
    public func readResource(uri: String) async throws -> [Content] {
        guard let client = client else {
            throw MCPError.connectionError("Not connected to any server")
        }
        
        let result = try await client.readResource(
            ReadResource.Params(uri: uri)
        )
        return result.content
    }
}

// MARK: - Custom Errors

enum MCPError: LocalizedError {
    case connectionError(String)
    case invalidParams(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionError(let message):
            return "Connection Error: \(message)"
        case .invalidParams(let message):
            return "Invalid Parameters: \(message)"
        }
    }
}