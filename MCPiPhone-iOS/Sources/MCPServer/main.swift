import Foundation
import MCP
import Logging

// Sample MCP server that provides device information
class SampleMCPServer {
    private let logger = Logger(label: "com.mcpiphone.server")
    private let server: Server
    
    init() throws {
        self.server = Server(
            name: "Device Info Server",
            version: "1.0.0",
            capabilities: .init(
                resources: .init(listChanged: false),
                tools: .init(listChanged: false)
            )
        )
        
        setupToolHandlers()
    }
    
    func start() async throws {
        let transport = StdioTransport()
        logger.info("Starting MCP Server")
        
        do {
            try await server.start(transport: transport)
        } catch {
            logger.error("Server failed: \(error)")
            throw error
        }
    }
    
    private func setupToolHandlers() {
        Task {
            await server.withMethodHandler(ListTools.self) { [weak self] _ in
                let deviceInfoTool = Tool(
                    name: "get_device_info",
                    description: "Get current device information",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([:]),
                        "required": .array([])
                    ])
                )
                
                let systemInfoTool = Tool(
                    name: "get_system_info",
                    description: "Get system information",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([:]),
                        "required": .array([])
                    ])
                )
                
                return ListTools.Result(tools: [deviceInfoTool, systemInfoTool])
            }
            
            await server.withMethodHandler(CallTool.self) { [weak self] params in
                guard let self = self else {
                    throw MCPError.invalidParams("Server deallocated")
                }
                
                self.logger.info("Handling tool call: \(params.name)")
                
                switch params.name {
                case "get_device_info":
                    return try self.handleGetDeviceInfo()
                case "get_system_info":
                    return try self.handleGetSystemInfo()
                default:
                    throw MCPError.invalidParams("Unknown tool: \(params.name)")
                }
            }
        }
    }
    
    private func handleGetDeviceInfo() throws -> CallTool.Result {
        let processInfo = ProcessInfo.processInfo
        
        let info = """
        Host Name: \(processInfo.hostName)
        Process Name: \(processInfo.processName)
        Process ID: \(processInfo.processIdentifier)
        """
        
        return CallTool.Result(content: [.text(info)])
    }
    
    private func handleGetSystemInfo() throws -> CallTool.Result {
        let processInfo = ProcessInfo.processInfo
        
        let info = """
        OS Version: \(processInfo.operatingSystemVersionString)
        Active Processors: \(processInfo.activeProcessorCount)
        Physical Memory: \(ByteCountFormatter().string(fromByteCount: Int64(processInfo.physicalMemory)))
        """
        
        return CallTool.Result(content: [.text(info)])
    }
}

// Command-line executable for running the sample MCP server
@main
struct MCPServerCLI {
    static func main() async throws {
        fputs("Starting MCP Server...\n", stderr)
        
        do {
            let server = try SampleMCPServer()
            try await server.start()
        } catch {
            fputs("Server error: \(error)\n", stderr)
            exit(1)
        }
    }
}