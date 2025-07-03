import Foundation
import MCP
import Logging
import UIKit

/// Sample MCP server that provides iOS device information and capabilities
public class SampleMCPServer {
    private let logger = Logger(label: "com.mcpiphone.server")
    private let server: Server
    
    public init() throws {
        // Initialize server with capabilities
        self.server = Server(
            name: "iOS Device Server",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false),
                resources: .init(listChanged: false)
            )
        )
        
        // Register tools
        try registerTools()
        
        // Register resources
        try registerResources()
        
        // Setup tool handlers
        setupToolHandlers()
    }
    
    /// Start the server with stdio transport
    public func start() async throws {
        let transport = StdioTransport()
        
        logger.info("Starting iOS MCP Server")
        
        do {
            try await server.start(transport: transport)
        } catch {
            logger.error("Server failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
    
    // MARK: - Tool Registration
    
    private func registerTools() throws {
        // Device Info Tool
        let deviceInfoTool = Tool(
            name: "get_device_info",
            description: "Get current iOS device information",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
        
        // Battery Status Tool
        let batteryTool = Tool(
            name: "get_battery_status",
            description: "Get current battery level and charging status",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
        
        // System Version Tool
        let systemVersionTool = Tool(
            name: "get_system_version",
            description: "Get iOS system version information",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
        
        // Screen Info Tool
        let screenInfoTool = Tool(
            name: "get_screen_info",
            description: "Get device screen dimensions and scale",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
        
        // Available Memory Tool
        let memoryTool = Tool(
            name: "get_memory_info",
            description: "Get available memory information",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        )
        
        // Register all tools
        try server.registerTool(deviceInfoTool)
        try server.registerTool(batteryTool)
        try server.registerTool(systemVersionTool)
        try server.registerTool(screenInfoTool)
        try server.registerTool(memoryTool)
        
        logger.info("Registered tools", metadata: [
            "toolCount": .stringConvertible(5)
        ])
    }
    
    // MARK: - Resource Registration
    
    private func registerResources() throws {
        // Device capabilities resource
        let capabilitiesResource = Resource(
            uri: "device://capabilities",
            name: "Device Capabilities",
            description: "List of device capabilities and features",
            mimeType: "application/json"
        )
        
        // App info resource
        let appInfoResource = Resource(
            uri: "app://info",
            name: "App Information",
            description: "Current app bundle and version information",
            mimeType: "application/json"
        )
        
        try server.registerResource(capabilitiesResource)
        try server.registerResource(appInfoResource)
        
        logger.info("Registered resources", metadata: [
            "resourceCount": .stringConvertible(2)
        ])
    }
    
    // MARK: - Tool Handlers
    
    private func setupToolHandlers() {
        Task {
            await server.withMethodHandler(CallTool.self) { [weak self] params in
                guard let self = self else {
                    throw MCPError.invalidParams("Server deallocated")
                }
                
                self.logger.info("Handling tool call", metadata: [
                    "toolName": .string(params.name)
                ])
                
                switch params.name {
                case "get_device_info":
                    return try self.handleGetDeviceInfo()
                    
                case "get_battery_status":
                    return try self.handleGetBatteryStatus()
                    
                case "get_system_version":
                    return try self.handleGetSystemVersion()
                    
                case "get_screen_info":
                    return try self.handleGetScreenInfo()
                    
                case "get_memory_info":
                    return try self.handleGetMemoryInfo()
                    
                default:
                    throw MCPError.invalidParams("Unknown tool: \(params.name)")
                }
            }
            
            await server.withMethodHandler(ReadResource.self) { [weak self] params in
                guard let self = self else {
                    throw MCPError.invalidParams("Server deallocated")
                }
                
                self.logger.info("Handling resource read", metadata: [
                    "uri": .string(params.uri)
                ])
                
                switch params.uri {
                case "device://capabilities":
                    return try self.handleReadDeviceCapabilities()
                    
                case "app://info":
                    return try self.handleReadAppInfo()
                    
                default:
                    throw MCPError.invalidParams("Unknown resource: \(params.uri)")
                }
            }
        }
    }
    
    // MARK: - Tool Implementations
    
    private func handleGetDeviceInfo() throws -> CallTool.Result {
        let device = UIDevice.current
        
        let info = """
        Device Model: \(device.model)
        Device Name: \(device.name)
        System Name: \(device.systemName)
        Identifier: \(device.identifierForVendor?.uuidString ?? "Unknown")
        User Interface: \(device.userInterfaceIdiom == .phone ? "iPhone" : "iPad")
        """
        
        return CallTool.Result(content: [.text(info)])
    }
    
    private func handleGetBatteryStatus() throws -> CallTool.Result {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        let batteryLevel = Int(device.batteryLevel * 100)
        let batteryState: String
        
        switch device.batteryState {
        case .unplugged:
            batteryState = "Unplugged"
        case .charging:
            batteryState = "Charging"
        case .full:
            batteryState = "Full"
        case .unknown:
            batteryState = "Unknown"
        @unknown default:
            batteryState = "Unknown"
        }
        
        let info = """
        Battery Level: \(batteryLevel)%
        Battery State: \(batteryState)
        """
        
        return CallTool.Result(content: [.text(info)])
    }
    
    private func handleGetSystemVersion() throws -> CallTool.Result {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        
        let info = """
        iOS Version: \(device.systemVersion)
        Process Name: \(processInfo.processName)
        Host Name: \(processInfo.hostName)
        OS Version: \(processInfo.operatingSystemVersionString)
        Active Processors: \(processInfo.activeProcessorCount)
        """
        
        return CallTool.Result(content: [.text(info)])
    }
    
    private func handleGetScreenInfo() throws -> CallTool.Result {
        let screen = UIScreen.main
        let bounds = screen.bounds
        
        let info = """
        Screen Size: \(bounds.width) x \(bounds.height) points
        Screen Scale: \(screen.scale)x
        Native Resolution: \(bounds.width * screen.scale) x \(bounds.height * screen.scale) pixels
        Brightness: \(Int(screen.brightness * 100))%
        """
        
        return CallTool.Result(content: [.text(info)])
    }
    
    private func handleGetMemoryInfo() throws -> CallTool.Result {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        
        let info = """
        Physical Memory: \(formatter.string(fromByteCount: Int64(physicalMemory)))
        Active Processors: \(processInfo.activeProcessorCount)
        Thermal State: \(thermalStateString(processInfo.thermalState))
        Low Power Mode: \(processInfo.isLowPowerModeEnabled ? "Enabled" : "Disabled")
        """
        
        return CallTool.Result(content: [.text(info)])
    }
    
    // MARK: - Resource Implementations
    
    private func handleReadDeviceCapabilities() throws -> ReadResource.Result {
        let capabilities: [String: Any] = [
            "hasCamera": UIImagePickerController.isSourceTypeAvailable(.camera),
            "hasPhotoLibrary": UIImagePickerController.isSourceTypeAvailable(.photoLibrary),
            "hasFaceID": deviceHasFaceID(),
            "hasTouchID": deviceHasTouchID(),
            "supportsMultitasking": UIDevice.current.isMultitaskingSupported,
            "supportsARKit": isARKitSupported()
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: capabilities, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return ReadResource.Result(content: [.text(jsonString)])
    }
    
    private func handleReadAppInfo() throws -> ReadResource.Result {
        let bundle = Bundle.main
        
        let appInfo: [String: Any] = [
            "bundleIdentifier": bundle.bundleIdentifier ?? "Unknown",
            "displayName": bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? "Unknown",
            "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "Unknown",
            "buildNumber": bundle.object(forInfoDictionaryKey: "CFBundleVersion") ?? "Unknown",
            "minimumOSVersion": bundle.object(forInfoDictionaryKey: "MinimumOSVersion") ?? "Unknown"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: appInfo, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return ReadResource.Result(content: [.text(jsonString)])
    }
    
    // MARK: - Helper Methods
    
    private func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func deviceHasFaceID() -> Bool {
        // Check if device has Face ID capability
        return UIDevice.current.userInterfaceIdiom == .phone && 
               UIScreen.main.bounds.height >= 812 // iPhone X and later
    }
    
    private func deviceHasTouchID() -> Bool {
        // Simplified check - in production, use LAContext
        return UIDevice.current.userInterfaceIdiom == .phone && 
               UIScreen.main.bounds.height < 812
    }
    
    private func isARKitSupported() -> Bool {
        // Simplified check - in production, check ARConfiguration.isSupported
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil
    }
}