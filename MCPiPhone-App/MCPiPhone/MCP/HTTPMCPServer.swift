import Foundation
import UIKit

enum MCPError: LocalizedError {
    case invalidParams(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidParams(let message):
            return "Invalid parameters: \(message)"
        }
    }
}

/// HTTP-based MCP server for iOS compatibility
class HTTPMCPServer {
    private let port: Int
    private var httpServer: HTTPServer?
    
    init(port: Int = 8080) {
        self.port = port
    }
    
    func start() async throws {
        // For iOS demo, we'll simulate an HTTP MCP server
        // In a real implementation, this would start an HTTP server
        print("HTTP MCP Server would start on port \(port)")
        print("Available tools: get_device_info, get_battery_status, get_system_info")
    }
    
    func stop() {
        httpServer?.stop()
        httpServer = nil
    }
    
    // Handle MCP tool calls over HTTP
    func handleToolCall(_ toolName: String, arguments: [String: Any] = [:]) async throws -> String {
        switch toolName {
        case "get_device_info":
            return try await getDeviceInfo()
        case "get_battery_status":
            return try await getBatteryStatus()
        case "get_system_info":
            return try await getSystemInfo()
        default:
            throw MCPError.invalidParams("Unknown tool: \(toolName)")
        }
    }
    
    // MARK: - Tool Implementations
    
    private func getDeviceInfo() async throws -> String {
        let device = UIDevice.current
        
        let info = """
        Device Model: \(device.model)
        Device Name: \(device.name)
        System Name: \(device.systemName)
        System Version: \(device.systemVersion)
        Identifier: \(device.identifierForVendor?.uuidString ?? "Unknown")
        User Interface: \(device.userInterfaceIdiom == .phone ? "iPhone" : "iPad")
        """
        
        return info
    }
    
    private func getBatteryStatus() async throws -> String {
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
        
        return info
    }
    
    private func getSystemInfo() async throws -> String {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        
        let info = """
        iOS Version: \(device.systemVersion)
        Process Name: \(processInfo.processName)
        Host Name: \(processInfo.hostName)
        OS Version: \(processInfo.operatingSystemVersionString)
        Active Processors: \(processInfo.activeProcessorCount)
        Physical Memory: \(ByteCountFormatter().string(fromByteCount: Int64(processInfo.physicalMemory)))
        """
        
        return info
    }
}

// Placeholder for HTTP server implementation
private class HTTPServer {
    func stop() {
        // Implementation would stop the HTTP server
    }
}