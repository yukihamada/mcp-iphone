import Foundation
import Combine

class ModelManager: NSObject, ObservableObject {
    static let shared = ModelManager()
    
    @Published var models: [Model] = Model.availableModels
    @Published var activeDownloads: [String: DownloadProgress] = [:]
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.mcp.iphone.modeldownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    struct DownloadProgress {
        let modelId: String
        let bytesWritten: Int64
        let totalBytes: Int64
        
        var percentage: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(bytesWritten) / Double(totalBytes) * 100
        }
    }
    
    override init() {
        super.init()
        loadModelStates()
    }
    
    private var modelsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Models", isDirectory: true)
    }
    
    private func loadModelStates() {
        guard let modelsDir = modelsDirectory else { return }
        
        // Create models directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        
        // Check which models are already downloaded
        for (index, model) in models.enumerated() {
            let modelPath = modelsDir.appendingPathComponent(model.filename)
            if FileManager.default.fileExists(atPath: modelPath.path) {
                models[index].status = .downloaded
            }
        }
    }
    
    func downloadModel(_ modelId: String) {
        guard let index = models.firstIndex(where: { $0.id == modelId }),
              let url = URL(string: models[index].url) else { return }
        
        models[index].status = .downloading
        
        let task = urlSession.downloadTask(with: url)
        task.taskDescription = modelId
        downloadTasks[modelId] = task
        task.resume()
    }
    
    func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        activeDownloads.removeValue(forKey: modelId)
        
        if let index = models.firstIndex(where: { $0.id == modelId }) {
            models[index].status = .notDownloaded
        }
    }
    
    func deleteModel(_ modelId: String) {
        guard let index = models.firstIndex(where: { $0.id == modelId }),
              let modelsDir = modelsDirectory else { return }
        
        let modelPath = modelsDir.appendingPathComponent(models[index].filename)
        try? FileManager.default.removeItem(at: modelPath)
        models[index].status = .notDownloaded
    }
    
    func getModelPath(_ modelId: String) -> URL? {
        guard let model = models.first(where: { $0.id == modelId }),
              model.status == .downloaded,
              let modelsDir = modelsDirectory else { return nil }
        
        let modelPath = modelsDir.appendingPathComponent(model.filename)
        return FileManager.default.fileExists(atPath: modelPath.path) ? modelPath : nil
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelId = downloadTask.taskDescription,
              let index = models.firstIndex(where: { $0.id == modelId }),
              let modelsDir = modelsDirectory else { return }
        
        let destinationURL = modelsDir.appendingPathComponent(models[index].filename)
        
        do {
            // Remove existing file if any
            try? FileManager.default.removeItem(at: destinationURL)
            
            // Move downloaded file to models directory
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.models[index].status = .downloaded
                self.activeDownloads.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
            }
        } catch {
            print("Failed to save model: \(error)")
            DispatchQueue.main.async {
                self.models[index].status = .failed
                self.activeDownloads.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let modelId = downloadTask.taskDescription else { return }
        
        DispatchQueue.main.async {
            self.activeDownloads[modelId] = DownloadProgress(
                modelId: modelId,
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let modelId = task.taskDescription,
              let index = models.firstIndex(where: { $0.id == modelId }) else { return }
        
        if let error = error {
            print("Download failed: \(error)")
            DispatchQueue.main.async {
                self.models[index].status = .failed
                self.activeDownloads.removeValue(forKey: modelId)
                self.downloadTasks.removeValue(forKey: modelId)
            }
        }
    }
}