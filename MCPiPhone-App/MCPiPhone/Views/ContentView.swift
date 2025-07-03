import SwiftUI
import MCP
import Combine
import UIKit
import Photos
import Contacts
import EventKit
import CoreLocation
import Network
import MusicKit

// MARK: - Development Configuration

/// Development configuration - DO NOT USE IN PRODUCTION
struct DevelopmentConfig {
    /// Cloudflare Worker URL
    static let workerURL = "https://mcp-iphone-gateway.yukihamada.workers.dev"
    
    /// Development-only flag
    static let isDevelopment = true
    
    /// Auto-create anonymous account on first launch
    static let autoCreateAccount = true
    
    /// Enable automatic MCP connection
    static let autoConnectMCP = true
    
    /// Demo API key for development (when Worker is not deployed)
    /// WARNING: This is for development only!
    static let demoAPIKey = "demo-api-key-" + UUID().uuidString
}

// MARK: - HTTPMCPServer (temporary inclusion for build issues)

public enum MCPError: LocalizedError {
    case invalidParams(String)
    case invalidRequest(String)
    case notConnected(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidParams(let message):
            return "Invalid parameters: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .notConnected(let message):
            return "Not connected: \(message)"
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
        print("HTTP MCP Server would start on port \(port)")
        print("Available tools:")
        print("  Local: get_device_info, get_battery_status, get_system_info, get_photos_count, get_contacts_count, get_calendar_events, get_location, get_network_info, get_storage_info")
        print("  Photos: get_photo, list_recent_photos, get_photo_metadata")
        print("  Files: read_file, get_file_info, list_files")
        print("  Server: web_search, file_search, music_search")
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
        // Local iPhone operations
        case "get_photos_count":
            return try await getPhotosCount()
        case "get_contacts_count":
            return try await getContactsCount()
        case "get_calendar_events":
            return try await getCalendarEvents()
        case "get_location":
            return try await getLocation()
        case "get_network_info":
            return try await getNetworkInfo()
        case "get_storage_info":
            return try await getStorageInfo()
        // Server/Search operations
        case "web_search":
            return try await webSearch(arguments: arguments)
        case "file_search":
            return try await fileSearch(arguments: arguments)
        case "music_search":
            return try await musicSearch(arguments: arguments)
        // Photo operations
        case "get_photo":
            return try await getPhoto(arguments: arguments)
        case "list_recent_photos":
            return try await listRecentPhotos(arguments: arguments)
        case "get_photo_metadata":
            return try await getPhotoMetadata(arguments: arguments)
        // File operations
        case "read_file":
            return try await readFile(arguments: arguments)
        case "get_file_info":
            return try await getFileInfo(arguments: arguments)
        case "list_files":
            return try await listFiles(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown tool: \(toolName)")
        }
    }
    
    // MARK: - Tool Implementations
    
    private func getDeviceInfo() async throws -> String {
        return await MainActor.run {
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
    }
    
    private func getBatteryStatus() async throws -> String {
        return await MainActor.run {
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
    }
    
    private func getSystemInfo() async throws -> String {
        return await MainActor.run {
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
    
    // MARK: - Local iPhone Operations
    
    private func getPhotosCount() async throws -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "Photos access not authorized. Please enable in Settings."
        }
        
        let fetchOptions = PHFetchOptions()
        let photos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let videos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        return """
        Photos Library:
        - Images: \(photos.count)
        - Videos: \(videos.count)
        - Total: \(photos.count + videos.count)
        """
    }
    
    private func getContactsCount() async throws -> String {
        let store = CNContactStore()
        
        do {
            let containers = try store.containers(matching: nil)
            var totalContacts = 0
            
            for container in containers {
                let predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                totalContacts += contacts.count
            }
            
            return "Total Contacts: \(totalContacts)"
        } catch {
            return "Contacts access not authorized. Please enable in Settings."
        }
    }
    
    private func getCalendarEvents() async throws -> String {
        let eventStore = EKEventStore()
        
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    guard granted else {
                        continuation.resume(returning: "Calendar access not authorized. Please enable in Settings.")
                        return
                    }
                    self.fetchCalendarEvents(eventStore: eventStore, continuation: continuation)
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    guard granted else {
                        continuation.resume(returning: "Calendar access not authorized. Please enable in Settings.")
                        return
                    }
                    self.fetchCalendarEvents(eventStore: eventStore, continuation: continuation)
                }
            }
        }
    }
    
    private func fetchCalendarEvents(eventStore: EKEventStore, continuation: CheckedContinuation<String, Never>) {
        let calendars = eventStore.calendars(for: .event)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        var result = "Upcoming Events (Next 7 days):\n"
        
        if events.isEmpty {
            result += "No events scheduled"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            for event in events.prefix(10) {
                result += "- \(event.title ?? "Untitled"): \(formatter.string(from: event.startDate))\n"
            }
            
            if events.count > 10 {
                result += "... and \(events.count - 10) more events"
            }
        }
        
        continuation.resume(returning: result)
    }
    
    private func getLocation() async throws -> String {
        return "Location services would require additional setup and permissions. Current status: Not implemented."
    }
    
    private func getNetworkInfo() async throws -> String {
        var info = "Network Information:\n"
        
        // Get WiFi info (limited on iOS)
        info += "WiFi: Connected (details restricted by iOS)\n"
        
        // Check network path
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        return await withCheckedContinuation { continuation in
            let capturedInfo = info
            monitor.pathUpdateHandler = { path in
                var result = capturedInfo
                result += "Network Status: \(path.status == .satisfied ? "Connected" : "Disconnected")\n"
                result += "Using Cellular: \(path.usesInterfaceType(.cellular) ? "Yes" : "No")\n"
                result += "Using WiFi: \(path.usesInterfaceType(.wifi) ? "Yes" : "No")\n"
                
                monitor.cancel()
                continuation.resume(returning: result)
            }
            monitor.start(queue: queue)
        }
    }
    
    private func getStorageInfo() async throws -> String {
        let fileManager = FileManager.default
        
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentDirectory.path)
            
            let totalSpace = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let freeSpace = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let usedSpace = totalSpace - freeSpace
            
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            
            return """
            Storage Information:
            - Total: \(formatter.string(fromByteCount: totalSpace))
            - Used: \(formatter.string(fromByteCount: usedSpace))
            - Free: \(formatter.string(fromByteCount: freeSpace))
            - Usage: \(Int((Double(usedSpace) / Double(totalSpace)) * 100))%
            """
        } catch {
            return "Unable to retrieve storage information: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Server/Search Operations
    
    private func webSearch(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw MCPError.invalidParams("Missing 'query' parameter")
        }
        
        // Use real web search via Cloudflare Worker
        guard let apiKey = AuthManager.shared.apiKey else {
            return "Web search requires authentication. Please ensure you're connected to the Cloudflare Worker."
        }
        
        let url = URL(string: "\(DevelopmentConfig.workerURL)/api/search/web")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                return "Search failed: HTTP \(httpResponse.statusCode)"
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                
                var output = "Web Search Results for \"\(query)\":\n\n"
                
                for (index, result) in results.enumerated() {
                    let title = result["title"] as? String ?? "Untitled"
                    let snippet = result["snippet"] as? String ?? "No description"
                    let url = result["url"] as? String ?? ""
                    let source = result["source"] as? String ?? "Web"
                    
                    output += "\(index + 1). \(title)\n"
                    output += "   Source: \(source)\n"
                    output += "   \(snippet)\n"
                    if !url.isEmpty {
                        output += "   URL: \(url)\n"
                    }
                    output += "\n"
                }
                
                return output
            }
            
            return "Search completed but no results found."
        } catch {
            return "Web search failed: \(error.localizedDescription)"
        }
    }
    
    private func fileSearch(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw MCPError.invalidParams("Missing 'query' parameter")
        }
        
        let fileManager = FileManager.default
        var searchResults: [(name: String, path: String, type: String, snippet: String?)] = []
        
        // Search in Documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            searchResults.append(contentsOf: searchFiles(in: documentsURL, query: query, type: "Documents"))
        }
        
        // Search in iCloud Drive if available
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            searchResults.append(contentsOf: searchFiles(in: iCloudURL, query: query, type: "iCloud Drive"))
        }
        
        // Search in app's bundle resources
        let bundleURL = Bundle.main.bundleURL
        searchResults.append(contentsOf: searchFiles(in: bundleURL, query: query, type: "App Bundle"))
        
        if searchResults.isEmpty {
            return "No files found matching '\(query)'."
        }
        
        var output = "File Search Results for \"\(query)\":\n\n"
        
        for (index, result) in searchResults.prefix(20).enumerated() {
            output += "\(index + 1). \(result.name)\n"
            output += "   Location: \(result.type)\n"
            output += "   Path: \(result.path)\n"
            if let snippet = result.snippet {
                output += "   Content: \(snippet)\n"
            }
            output += "\n"
        }
        
        if searchResults.count > 20 {
            output += "... and \(searchResults.count - 20) more results\n"
        }
        
        return output
    }
    
    private func searchFiles(in directory: URL, query: String, type: String) -> [(name: String, path: String, type: String, snippet: String?)] {
        let fileManager = FileManager.default
        var results: [(name: String, path: String, type: String, snippet: String?)] = []
        
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .fileSizeKey]) else {
            return results
        }
        
        let searchQuery = query.lowercased()
        
        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            
            // Skip directories and hidden files
            if fileName.hasPrefix(".") { continue }
            
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                continue
            }
            
            // Check if filename matches
            if fileName.lowercased().contains(searchQuery) {
                results.append((name: fileName, path: fileURL.path, type: type, snippet: nil))
                continue
            }
            
            // For text files, also search content
            let textExtensions = ["txt", "md", "json", "xml", "plist", "swift", "js", "html", "css"]
            if let fileExtension = fileURL.pathExtension.lowercased() as String?,
               textExtensions.contains(fileExtension) {
                
                // Read file content (limit to small files)
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int,
                   fileSize < 100_000 { // 100KB limit
                    
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8),
                       content.lowercased().contains(searchQuery) {
                        
                        // Extract snippet around the match
                        let snippet = extractSnippet(from: content, around: searchQuery)
                        results.append((name: fileName, path: fileURL.path, type: type, snippet: snippet))
                    }
                }
            }
        }
        
        return results
    }
    
    private func extractSnippet(from content: String, around query: String, contextLength: Int = 50) -> String {
        let lowercasedContent = content.lowercased()
        guard let range = lowercasedContent.range(of: query.lowercased()) else {
            return String(content.prefix(100)) + "..."
        }
        
        let startIndex = content.index(range.lowerBound, offsetBy: -contextLength, limitedBy: content.startIndex) ?? content.startIndex
        let endIndex = content.index(range.upperBound, offsetBy: contextLength, limitedBy: content.endIndex) ?? content.endIndex
        
        var snippet = String(content[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if startIndex > content.startIndex { snippet = "..." + snippet }
        if endIndex < content.endIndex { snippet = snippet + "..." }
        
        return snippet
    }
    
    private func musicSearch(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw MCPError.invalidParams("Missing 'query' parameter")
        }
        
        // Check MusicKit authorization
        let authStatus = await MusicAuthorization.request()
        guard authStatus == .authorized else {
            return "Music search requires Apple Music access. Please authorize in Settings."
        }
        
        do {
            // Create search request
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self, Album.self, Artist.self])
            request.limit = 10
            
            // Perform search
            let response = try await request.response()
            
            var output = "Music Search Results for \"\(query)\":\n\n"
            
            // Songs
            if !response.songs.isEmpty {
                output += "🎵 Songs:\n"
                for (index, song) in response.songs.prefix(5).enumerated() {
                    output += "  \(index + 1). \(song.title)\n"
                    output += "     Artist: \(song.artistName)\n"
                    if let albumTitle = song.albumTitle {
                        output += "     Album: \(albumTitle)\n"
                    }
                    if let duration = song.duration {
                        let minutes = Int(duration) / 60
                        let seconds = Int(duration) % 60
                        output += "     Duration: \(minutes):\(String(format: "%02d", seconds))\n"
                    }
                    if let releaseDate = song.releaseDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        output += "     Released: \(formatter.string(from: releaseDate))\n"
                    }
                    output += "\n"
                }
            }
            
            // Albums
            if !response.albums.isEmpty {
                output += "💿 Albums:\n"
                for (index, album) in response.albums.prefix(3).enumerated() {
                    output += "  \(index + 1). \(album.title)\n"
                    output += "     Artist: \(album.artistName)\n"
                    output += "     Tracks: \(album.trackCount)\n"
                    if let releaseDate = album.releaseDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        output += "     Released: \(formatter.string(from: releaseDate))\n"
                    }
                    output += "\n"
                }
            }
            
            // Artists
            if !response.artists.isEmpty {
                output += "🎤 Artists:\n"
                for (index, artist) in response.artists.prefix(3).enumerated() {
                    output += "  \(index + 1). \(artist.name)\n"
                    if let genres = artist.genres {
                        let genreNames = genres.map { $0.name }.joined(separator: ", ")
                        if !genreNames.isEmpty {
                            output += "     Genres: \(genreNames)\n"
                        }
                    }
                    output += "\n"
                }
            }
            
            if response.songs.isEmpty && response.albums.isEmpty && response.artists.isEmpty {
                output = "No music found for \"\(query)\". Try a different search term."
            }
            
            return output
        } catch {
            // If MusicKit fails, try iTunes Search API as fallback
            return try await iTunesSearch(query: query)
        }
    }
    
    private func iTunesSearch(query: String) async throws -> String {
        // iTunes Search API (free, no auth required)
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&media=music&limit=10")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            
            var output = "Music Search Results for \"\(query)\" (via iTunes):\n\n"
            
            for (index, result) in results.prefix(10).enumerated() {
                let trackName = result["trackName"] as? String ?? "Unknown"
                let artistName = result["artistName"] as? String ?? "Unknown Artist"
                let albumName = result["collectionName"] as? String ?? "Unknown Album"
                let genre = result["primaryGenreName"] as? String ?? "Unknown"
                
                output += "\(index + 1). \(trackName)\n"
                output += "   Artist: \(artistName)\n"
                output += "   Album: \(albumName)\n"
                output += "   Genre: \(genre)\n"
                
                if result["previewUrl"] != nil {
                    output += "   Preview: Available\n"
                }
                
                output += "\n"
            }
            
            if results.isEmpty {
                output = "No music found for \"\(query)\"."
            }
            
            return output
        }
        
        return "Music search failed."
    }
    
    // MARK: - Photo Operations
    
    private func getPhoto(arguments: [String: Any]) async throws -> String {
        let index = arguments["index"] as? Int ?? 0
        let size = arguments["size"] as? String ?? "thumbnail"
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "Photos access not authorized. Please enable in Settings."
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = index + 1
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard assets.count > index else {
            return "Photo at index \(index) not found. Only \(assets.count) photos available."
        }
        
        let asset = assets.object(at: index)
        
        // Get image
        let manager = PHImageManager.default()
        let targetSize: CGSize
        
        switch size {
        case "full":
            targetSize = PHImageManagerMaximumSize
        case "medium":
            targetSize = CGSize(width: 1024, height: 1024)
        default: // thumbnail
            targetSize = CGSize(width: 256, height: 256)
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        return await withCheckedContinuation { continuation in
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                guard let image = image else {
                    continuation.resume(returning: "Failed to load photo")
                    return
                }
                
                // Convert to base64
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: "Failed to convert photo")
                    return
                }
                
                let base64String = imageData.base64EncodedString()
                
                let result = """
                Photo Information:
                - Index: \(index)
                - Creation Date: \(asset.creationDate?.description ?? "Unknown")
                - Size: \(Int(image.size.width)) x \(Int(image.size.height)) pixels
                - Data Size: \(ByteCountFormatter().string(fromByteCount: Int64(imageData.count)))
                
                Base64 Image Data:
                data:image/jpeg;base64,\(base64String)
                """
                
                continuation.resume(returning: result)
            }
        }
    }
    
    private func listRecentPhotos(arguments: [String: Any]) async throws -> String {
        let limit = arguments["limit"] as? Int ?? 10
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "Photos access not authorized. Please enable in Settings."
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var output = "Recent Photos (\(assets.count) of \(limit) requested):\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            output += "\(i). Photo\n"
            output += "   Created: \(asset.creationDate.map { dateFormatter.string(from: $0) } ?? "Unknown")\n"
            output += "   Type: \(asset.mediaType == .image ? "Image" : "Other")\n"
            output += "   Dimensions: \(asset.pixelWidth) x \(asset.pixelHeight)\n"
            if let location = asset.location {
                output += "   Location: \(location.coordinate.latitude), \(location.coordinate.longitude)\n"
            }
            output += "\n"
        }
        
        return output
    }
    
    private func getPhotoMetadata(arguments: [String: Any]) async throws -> String {
        let index = arguments["index"] as? Int ?? 0
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "Photos access not authorized. Please enable in Settings."
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = index + 1
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard assets.count > index else {
            return "Photo at index \(index) not found."
        }
        
        let asset = assets.object(at: index)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        
        var metadata = "Photo Metadata:\n\n"
        metadata += "General Information:\n"
        metadata += "- Creation Date: \(asset.creationDate.map { dateFormatter.string(from: $0) } ?? "Unknown")\n"
        metadata += "- Modification Date: \(asset.modificationDate.map { dateFormatter.string(from: $0) } ?? "Unknown")\n"
        metadata += "- Media Type: \(asset.mediaType == .image ? "Image" : asset.mediaType == .video ? "Video" : "Other")\n"
        metadata += "- Pixel Dimensions: \(asset.pixelWidth) x \(asset.pixelHeight)\n"
        metadata += "- Aspect Ratio: \(String(format: "%.2f", Double(asset.pixelWidth) / Double(asset.pixelHeight)))\n"
        metadata += "- Duration: \(asset.duration) seconds\n"
        metadata += "\n"
        
        if let location = asset.location {
            metadata += "Location:\n"
            metadata += "- Latitude: \(location.coordinate.latitude)\n"
            metadata += "- Longitude: \(location.coordinate.longitude)\n"
            metadata += "- Altitude: \(location.altitude) meters\n"
            metadata += "\n"
        }
        
        metadata += "Flags:\n"
        metadata += "- Favorite: \(asset.isFavorite ? "Yes" : "No")\n"
        metadata += "- Hidden: \(asset.isHidden ? "Yes" : "No")\n"
        
        return metadata
    }
    
    // MARK: - File Operations
    
    private func readFile(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String else {
            throw MCPError.invalidParams("Missing 'path' parameter")
        }
        
        let fileURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            return "File not found: \(path)"
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            // Check if it's a directory
            if let fileType = attributes[.type] as? FileAttributeType, fileType == .typeDirectory {
                return "Error: Path points to a directory, not a file."
            }
            
            // For text files, read content directly
            let textExtensions = ["txt", "md", "json", "xml", "plist", "swift", "js", "html", "css", "py", "rb", "java", "c", "cpp", "h", "m", "yml", "yaml", "toml", "ini", "conf", "log"]
            
            if let fileExtension = fileURL.pathExtension.lowercased() as String?,
               textExtensions.contains(fileExtension) {
                
                if fileSize > 1_000_000 { // 1MB limit for text files
                    return "File too large (\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))). Maximum size for text files is 1MB."
                }
                
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                return """
                File: \(fileURL.lastPathComponent)
                Type: Text (\(fileExtension))
                Size: \(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))
                
                Content:
                \(content)
                """
            } else {
                // For binary files, return base64
                if fileSize > 10_000_000 { // 10MB limit for binary files
                    return "File too large (\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))). Maximum size for binary files is 10MB."
                }
                
                let data = try Data(contentsOf: fileURL)
                let base64String = data.base64EncodedString()
                
                return """
                File: \(fileURL.lastPathComponent)
                Type: Binary (\(fileURL.pathExtension))
                Size: \(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))
                
                Base64 Data:
                \(base64String)
                """
            }
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
    
    private func getFileInfo(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String else {
            throw MCPError.invalidParams("Missing 'path' parameter")
        }
        
        let fileURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            return "File not found: \(path)"
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .medium
            
            var info = "File Information:\n\n"
            info += "Path: \(path)\n"
            info += "Name: \(fileURL.lastPathComponent)\n"
            info += "Extension: \(fileURL.pathExtension.isEmpty ? "None" : fileURL.pathExtension)\n"
            
            if let fileType = attributes[.type] as? FileAttributeType {
                info += "Type: \(fileType == .typeDirectory ? "Directory" : fileType == .typeRegular ? "Regular File" : "Other")\n"
            }
            
            if let size = attributes[.size] as? Int {
                info += "Size: \(ByteCountFormatter().string(fromByteCount: Int64(size)))\n"
            }
            
            if let creationDate = attributes[.creationDate] as? Date {
                info += "Created: \(dateFormatter.string(from: creationDate))\n"
            }
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                info += "Modified: \(dateFormatter.string(from: modificationDate))\n"
            }
            
            // Check if readable/writable
            info += "Readable: \(fileManager.isReadableFile(atPath: path) ? "Yes" : "No")\n"
            info += "Writable: \(fileManager.isWritableFile(atPath: path) ? "Yes" : "No")\n"
            info += "Executable: \(fileManager.isExecutableFile(atPath: path) ? "Yes" : "No")\n"
            
            return info
        } catch {
            return "Error getting file info: \(error.localizedDescription)"
        }
    }
    
    private func listFiles(arguments: [String: Any]) async throws -> String {
        let path = arguments["path"] as? String ?? NSHomeDirectory()
        let showHidden = arguments["showHidden"] as? Bool ?? false
        
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: path)
        
        guard fileManager.fileExists(atPath: path) else {
            return "Directory not found: \(path)"
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .fileSizeKey, .creationDateKey])
            
            var output = "Contents of \(path):\n\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            var directories: [URL] = []
            var files: [URL] = []
            
            for item in contents {
                if !showHidden && item.lastPathComponent.hasPrefix(".") {
                    continue
                }
                
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    directories.append(item)
                } else {
                    files.append(item)
                }
            }
            
            // Sort alphabetically
            directories.sort { $0.lastPathComponent < $1.lastPathComponent }
            files.sort { $0.lastPathComponent < $1.lastPathComponent }
            
            // List directories first
            if !directories.isEmpty {
                output += "Directories:\n"
                for dir in directories {
                    output += "  📁 \(dir.lastPathComponent)/\n"
                }
                output += "\n"
            }
            
            // Then list files
            if !files.isEmpty {
                output += "Files:\n"
                for file in files {
                    let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let size = resourceValues.fileSize ?? 0
                    let sizeStr = ByteCountFormatter().string(fromByteCount: Int64(size))
                    
                    let icon = getFileIcon(for: file.pathExtension)
                    output += "  \(icon) \(file.lastPathComponent) (\(sizeStr))\n"
                }
            }
            
            if directories.isEmpty && files.isEmpty {
                output += "(Empty directory)"
            }
            
            output += "\n\nTotal: \(directories.count) directories, \(files.count) files"
            
            return output
        } catch {
            return "Error listing directory: \(error.localizedDescription)"
        }
    }
    
    private func getFileIcon(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "txt", "md": return "📄"
        case "pdf": return "📕"
        case "jpg", "jpeg", "png", "gif", "bmp": return "🖼️"
        case "mp3", "wav", "m4a", "aac": return "🎵"
        case "mp4", "mov", "avi", "mkv": return "🎥"
        case "zip", "rar", "7z", "tar", "gz": return "📦"
        case "app": return "📦"
        case "swift", "js", "py", "java", "c", "cpp": return "📃"
        case "json", "xml", "plist", "yml", "yaml": return "⚙️"
        default: return "📃"
        }
    }
}

// Placeholder for HTTP server implementation
private class HTTPServer {
    func stop() {
        // Implementation would stop the HTTP server
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var selectedTab = 1  // Default to Chat tab
    @StateObject private var mcpManager = MCPClientManager()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .environmentObject(mcpManager)
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(1)
            
            MCPToolsView()
                .environmentObject(mcpManager)
                .tabItem {
                    Label("MCP Tools", systemImage: "wrench.and.screwdriver")
                }
                .tag(0)
        }
        .onAppear {
            // Create anonymous account on first launch if needed
            if !AuthManager.shared.isAuthenticated {
                print("[ContentView] Not authenticated, attempting to create anonymous account...")
                Task {
                    do {
                        try await AuthManager.shared.createAnonymousAccount()
                        print("[ContentView] Anonymous account created successfully")
                    } catch {
                        print("[ContentView] Failed to create anonymous account: \(error)")
                        // Try again after a short delay
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        do {
                            try await AuthManager.shared.createAnonymousAccount()
                            print("[ContentView] Anonymous account created on retry")
                        } catch {
                            print("[ContentView] Retry also failed: \(error)")
                        }
                    }
                }
            } else {
                print("[ContentView] Already authenticated")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToChatWithToolOutput"))) { _ in
            // Switch to chat tab when tool output is sent
            selectedTab = 1
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
    
    enum MessageRole {
        case user
        case assistant
        case system
    }
}

// MARK: - Chat View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    
    private let llmConfig = LLMConfiguration.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Add a welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: """
            Hello! I'm your AI assistant with MCP (Model Context Protocol) integration.
            
            I can help you with:
            • General questions and conversations
            • Analyzing output from MCP tools
            • Understanding device information and system status
            
            You can also use the MCP Tools tab to:
            • Get device information (battery, system, storage)
            • Access photos and files
            • Search the web and music
            • And more!
            
            How can I assist you today?
            """
        ))
        
        // Listen for rate limit updates
        NotificationCenter.default.publisher(for: Notification.Name("RateLimitUpdate"))
            .sink { [weak self] notification in
                if let limit = notification.userInfo?["limit"] as? Int,
                   let remaining = notification.userInfo?["remaining"] as? Int {
                    self?.statusMessage = "API calls: \(remaining)/\(limit) remaining"
                }
            }
            .store(in: &cancellables)
        
        // Listen for fallback notifications
        NotificationCenter.default.publisher(for: Notification.Name("LLMFallbackToLocal"))
            .sink { [weak self] notification in
                var message = "Switched to local LLM due to rate limit"
                if let suggestion = notification.userInfo?["suggestion"] as? String {
                    message += ". \(suggestion)"
                }
                self?.statusMessage = message
            }
            .store(in: &cancellables)
        
        // Listen for tool output to analyze
        NotificationCenter.default.publisher(for: Notification.Name("SwitchToChatWithToolOutput"))
            .sink { [weak self] notification in
                guard let toolName = notification.userInfo?["toolName"] as? String,
                      let output = notification.userInfo?["output"] as? String else { return }
                
                self?.addToolOutput(toolName: toolName, output: output)
            }
            .store(in: &cancellables)
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        
        // Clear any previous error
        errorMessage = nil
        isLoading = true
        
        do {
            // Check if current provider is available
            guard llmConfig.currentProvider.isAvailable else {
                throw LLMError.notAvailable
            }
            
            // Build the prompt with conversation history
            let prompt = buildPrompt()
            
            // Create a placeholder for the assistant's response
            let assistantMessage = ChatMessage(role: .assistant, content: "")
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1
            
            // Get streaming response using LLMConfiguration (handles fallback)
            let stream = try await llmConfig.stream(prompt: prompt, maxTokens: 1000)
            
            var fullResponse = ""
            for await chunk in stream {
                fullResponse += chunk
                // Update the message with accumulated response
                messages[messageIndex] = ChatMessage(role: .assistant, content: fullResponse)
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            
            // Remove the empty assistant message if there was an error
            if messages.last?.content.isEmpty == true {
                messages.removeLast()
            }
            
            // Handle specific errors
            if let llmError = error as? LLMError {
                switch llmError {
                case .notAvailable:
                    if DevelopmentConfig.isDevelopment {
                        errorMessage = """
                        LLM not available. Please check:
                        1. Cloudflare Worker is deployed at: \(DevelopmentConfig.workerURL)
                        2. Your API key is configured in Settings
                        3. Or wait for local LLM implementation to complete
                        """
                    } else {
                        errorMessage = "Please configure your API key in Settings"
                    }
                case .rateLimitExceeded(let resetAt, let suggestion):
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    var message = "Rate limit exceeded. Try again at \(formatter.string(from: resetAt))"
                    if let suggestion = suggestion {
                        message += ". \(suggestion)"
                    }
                    errorMessage = message
                default:
                    errorMessage = llmError.localizedDescription
                }
            } else {
                errorMessage = "An error occurred: \(error.localizedDescription)"
            }
        }
    }
    
    func clearMessages() {
        messages = [ChatMessage(
            role: .assistant,
            content: """
            Hello! I'm your AI assistant with MCP (Model Context Protocol) integration.
            
            I can help you with:
            • General questions and conversations
            • Analyzing output from MCP tools
            • Understanding device information and system status
            
            You can also use the MCP Tools tab to:
            • Get device information (battery, system, storage)
            • Access photos and files
            • Search the web and music
            • And more!
            
            How can I assist you today?
            """
        )]
        errorMessage = nil
    }
    
    private func buildPrompt() -> String {
        // Build a prompt that includes recent conversation history
        // Limit to last 10 messages to avoid token limits
        let recentMessages = messages.suffix(10)
        
        var prompt = ""
        for message in recentMessages {
            switch message.role {
            case .user:
                prompt += "User: \(message.content)\n"
            case .assistant:
                prompt += "Assistant: \(message.content)\n"
            case .system:
                prompt += "System: \(message.content)\n"
            }
        }
        
        // Remove the last newline
        if prompt.hasSuffix("\n") {
            prompt.removeLast()
        }
        
        return prompt
    }
    
    func addToolOutput(toolName: String, output: String) {
        // Add system message with tool output
        let message = """
        MCP Tool Result - \(toolName):
        
        \(output)
        
        Would you like me to analyze this output or answer any questions about it?
        """
        
        messages.append(ChatMessage(role: .system, content: message))
    }
}

// MARK: - Chat View

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var mcpManager: MCPClientManager
    @State private var messageText = ""
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping outside
                        isMessageFieldFocused = false
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        // Scroll to bottom when new message is added
                        withAnimation {
                            scrollProxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // Status or error message
                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                }
                
                Divider()
                
                // Message input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...5)
                        .focused($isMessageFieldFocused)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: mcpManager.isConnected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(mcpManager.isConnected ? .green : .gray)
                            .font(.caption)
                        Text("MCP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.clearMessages()
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        Task {
            await viewModel.sendMessage(trimmedMessage)
        }
        
        messageText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.role == .user ? Color.accentColor : Color.gray.opacity(0.2))
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - MCP Tools View

struct MCPToolsView: View {
    @EnvironmentObject var mcpManager: MCPClientManager
    @State private var serverPath = "demo"  // Default to demo server
    @State private var selectedTool: Tool?
    @State private var toolResponse = ""
    @State private var isConnecting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingLLMSettings = false
    @State private var hasAutoConnected = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with LLM Settings
                HStack {
                    Text("MCP iOS Demo")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Button(action: { showingLLMSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                
                // Connection Section
                connectionSection
                
                Divider()
                
                // Server Info Section
                if mcpManager.isConnected {
                    serverInfoSection
                    
                    Divider()
                    
                    // Tools Section
                    toolsSection
                    
                    Divider()
                    
                    // Response Section
                    responseSection
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .alert("MCP Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingLLMSettings) {
                LLMSettingsView()
            }
            .onAppear {
                // Auto-connect to MCP server on first appearance
                if !hasAutoConnected && !mcpManager.isConnected {
                    hasAutoConnected = true
                    autoConnectToMCPServer()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP Server Connection")
                .font(.headline)
            
            HStack {
                TextField("Server executable path", text: $serverPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(mcpManager.isConnected)
                
                if mcpManager.isConnected {
                    // Connection status indicator
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                
                Button(action: toggleConnection) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(mcpManager.isConnected ? "Disconnect" : "Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting || (serverPath.isEmpty && !mcpManager.isConnected))
            }
            
            if let error = mcpManager.connectionError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server Information")
                .font(.headline)
            
            if let serverInfo = mcpManager.serverInfo {
                Label("Name: \(serverInfo.name)", systemImage: "server.rack")
                Label("Version: \(serverInfo.version)", systemImage: "info.circle")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available Tools")
                .font(.headline)
            
            if mcpManager.availableTools.isEmpty {
                Text("No tools available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mcpManager.availableTools, id: \.name) { tool in
                            ToolRow(tool: tool, isSelected: selectedTool?.name == tool.name) {
                                callTool(tool)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tool Response")
                    .font(.headline)
                
                Spacer()
                
                if !toolResponse.isEmpty && toolResponse != "No response yet" {
                    Button(action: sendToChat) {
                        Label("Ask AI", systemImage: "message")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            ScrollView {
                Text(toolResponse.isEmpty ? "No response yet" : toolResponse)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    
    private func toggleConnection() {
        if mcpManager.isConnected {
            Task {
                await mcpManager.disconnect()
                serverPath = ""
                toolResponse = ""
                selectedTool = nil
            }
        } else {
            isConnecting = true
            Task {
                do {
                    try await mcpManager.connectToServer(executable: serverPath)
                } catch {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
                isConnecting = false
            }
        }
    }
    
    private func callTool(_ tool: Tool) {
        selectedTool = tool
        toolResponse = "Calling \(tool.name)..."
        
        Task {
            do {
                let response = try await mcpManager.callTool(tool.name)
                
                await MainActor.run {
                    toolResponse = response
                }
            } catch {
                await MainActor.run {
                    toolResponse = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func sendToChat() {
        guard let tool = selectedTool else { return }
        
        // Store the tool output in app storage for the chat view to access
        UserDefaults.standard.set(toolResponse, forKey: "lastToolOutput")
        UserDefaults.standard.set(tool.name, forKey: "lastToolName")
        
        // Post notification to switch to chat tab
        NotificationCenter.default.post(
            name: Notification.Name("SwitchToChatWithToolOutput"),
            object: nil,
            userInfo: [
                "toolName": tool.name,
                "output": toolResponse
            ]
        )
    }
    
    private func autoConnectToMCPServer() {
        guard DevelopmentConfig.autoConnectMCP else { return }
        
        isConnecting = true
        Task {
            do {
                // Add a small delay to ensure UI is ready
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                try await mcpManager.connectToServer(executable: serverPath)
                
                // Show success message
                await MainActor.run {
                    toolResponse = "MCP Server connected successfully! Available tools: \(mcpManager.availableTools.count)"
                }
            } catch {
                // Log the error but don't show alert for auto-connection
                print("[MCP Auto-connect] Failed: \(error.localizedDescription)")
                
                // Show a subtle error message in the response area
                await MainActor.run {
                    toolResponse = "MCP Server auto-connection failed. You can manually connect using the Connect button."
                }
            }
            
            await MainActor.run {
                isConnecting = false
            }
        }
    }
}

// MARK: - Tool Row View

struct ToolRow: View {
    let tool: Tool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if !tool.description.isEmpty {
                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}