import Foundation

/// Helper class to run MCP server as a separate process for testing
public class MCPServerRunner {
    private var serverProcess: Process?
    private let serverExecutablePath: String
    
    public init(executablePath: String) {
        self.serverExecutablePath = executablePath
    }
    
    /// Start the MCP server process
    public func start() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: serverExecutablePath)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        try process.run()
        self.serverProcess = process
    }
    
    /// Stop the MCP server process
    public func stop() {
        serverProcess?.terminate()
        serverProcess = nil
    }
    
    /// Check if server is running
    public var isRunning: Bool {
        return serverProcess?.isRunning ?? false
    }
}