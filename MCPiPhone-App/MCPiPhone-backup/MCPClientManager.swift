import Foundation
import MCP
import Logging
import UIKit

/// Demo server info for iOS app
public struct DemoServerInfo {
    public let name: String
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Manager class for handling MCP client connections and operations
@MainActor
public class MCPClientManager: ObservableObject {
    private let logger = Logger(label: "com.mcpiphone.client")
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var serverInfo: DemoServerInfo?
    @Published public private(set) var availableTools: [Tool] = []
    @Published public private(set) var connectionError: MCPError?
    
    private var httpServer: HTTPMCPServer?
    
    public init() {
        self.httpServer = HTTPMCPServer()
    }
    
    /// Connect to HTTP MCP server (iOS compatible)
    /// - Parameters:
    ///   - executable: Path to the server executable (used as identifier)
    ///   - args: Arguments to pass to the server
    ///   - env: Environment variables for the server process
    public func connectToServer(
        executable: String,
        args: [String] = [],
        env: [String: String] = [:]
    ) async throws {
        logger.info("Starting HTTP MCP server (iOS)")
        
        guard let httpServer = self.httpServer else {
            throw MCPError.invalidRequest("HTTP server not initialized")
        }
        
        // Start the HTTP MCP server
        try await httpServer.start()
        
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Set up server info
        self.isConnected = true
        self.serverInfo = DemoServerInfo(name: "iOS HTTP MCP Server", version: "1.0.0")
        self.connectionError = nil
        
        // Set up available tools
        self.availableTools = [
            Tool(
                name: "get_device_info",
                description: "Get iOS device information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_battery_status",
                description: "Get battery level and charging status",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_system_info",
                description: "Get iOS system information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            )
        ]
        
        logger.info("Successfully started HTTP MCP server")
    }
    
    /// Disconnect from the MCP server
    public func disconnect() async {
        logger.info("Disconnecting from MCP server")
        
        httpServer?.stop()
        self.isConnected = false
        self.serverInfo = nil
        self.availableTools = []
        self.connectionError = nil
    }
    
    /// Call a tool on the connected MCP server
    /// - Parameters:
    ///   - toolName: Name of the tool to call
    ///   - arguments: Arguments to pass to the tool
    /// - Returns: The result content from the tool
    public func callTool(
        _ toolName: String,
        arguments: [String: Any] = [:]
    ) async throws -> String {
        guard isConnected else {
            throw MCPError.notConnected("Not connected to MCP server")
        }
        
        logger.info("Calling tool", metadata: [
            "toolName": .string(toolName),
            "arguments": .dictionary(arguments.mapValues { .string(String(describing: $0)) })
        ])
        
        // Use HTTP MCP server for tool execution
        guard let httpServer = self.httpServer else {
            throw MCPError.invalidRequest("HTTP server not available")
        }
        
        return try await httpServer.handleToolCall(toolName, arguments: arguments)
    }
    
}

// MARK: - Error Extension

extension MCPError {
    static func notConnected(_ message: String) -> MCPError {
        return .invalidRequest(message)
    }
}