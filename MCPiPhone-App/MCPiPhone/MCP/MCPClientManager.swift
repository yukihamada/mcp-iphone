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
            // Local device tools
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
            ),
            // Local iPhone operations
            Tool(
                name: "get_photos_count",
                description: "Get count of photos and videos in library",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_contacts_count",
                description: "Get total number of contacts",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_calendar_events",
                description: "Get upcoming calendar events for next 7 days",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_location",
                description: "Get current location (not implemented)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_network_info",
                description: "Get network connection information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_storage_info",
                description: "Get device storage information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            // Server/Search operations
            Tool(
                name: "web_search",
                description: "Search the web for information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search query")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ])
            ),
            Tool(
                name: "file_search",
                description: "Search files in app documents",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("File name search query")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ])
            ),
            Tool(
                name: "music_search",
                description: "Search for music tracks",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Music search query")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ])
            ),
            // Photo operations
            Tool(
                name: "get_photo",
                description: "Get a photo from the device library",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "index": .object([
                            "type": .string("integer"),
                            "description": .string("Photo index (0 = most recent)")
                        ]),
                        "size": .object([
                            "type": .string("string"),
                            "description": .string("Image size: thumbnail, medium, or full")
                        ])
                    ]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "list_recent_photos",
                description: "List recent photos from the device",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Number of photos to list (default: 10)")
                        ])
                    ]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "get_photo_metadata",
                description: "Get detailed metadata for a photo",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "index": .object([
                            "type": .string("integer"),
                            "description": .string("Photo index (0 = most recent)")
                        ])
                    ]),
                    "required": .array([])
                ])
            ),
            // File operations
            Tool(
                name: "read_file",
                description: "Read the contents of a file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Absolute file path")
                        ])
                    ]),
                    "required": .array([.string("path")])
                ])
            ),
            Tool(
                name: "get_file_info",
                description: "Get detailed information about a file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Absolute file path")
                        ])
                    ]),
                    "required": .array([.string("path")])
                ])
            ),
            Tool(
                name: "list_files",
                description: "List files in a directory",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Directory path (default: home)")
                        ]),
                        "showHidden": .object([
                            "type": .string("boolean"),
                            "description": .string("Show hidden files (default: false)")
                        ])
                    ]),
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

// Error extension removed - using MCPError cases directly