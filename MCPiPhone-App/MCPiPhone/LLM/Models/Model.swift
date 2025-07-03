import Foundation

struct Model: Identifiable, Codable {
    let id: String
    let name: String
    let url: String
    let filename: String
    let sizeInBytes: Int64
    var status: DownloadStatus
    
    enum DownloadStatus: String, Codable {
        case notDownloaded = "download"
        case downloading = "downloading"
        case downloaded = "downloaded"
        case failed = "failed"
    }
    
    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: sizeInBytes)
    }
    
    static let availableModels = [
        Model(
            id: "jan-nano-iq4xs",
            name: "Jan-Nano (iQ4_XS, 2.3GB)",
            url: "https://huggingface.co/Menlo/Jan-nano-gguf/resolve/main/jan-nano-iQ4_XS.gguf",
            filename: "jan-nano-iQ4_XS.gguf",
            sizeInBytes: 2_469_000_000, // ~2.3GB
            status: .notDownloaded
        ),
        Model(
            id: "jan-nano-32k-iq4xs",
            name: "Jan-Nano-32k (iQ4_XS, 2.3GB)",
            url: "https://huggingface.co/Menlo/Jan-nano-32k-gguf/resolve/main/jan-nano-32k-iQ4_XS.gguf",
            filename: "jan-nano-32k-iQ4_XS.gguf",
            sizeInBytes: 2_469_000_000, // ~2.3GB
            status: .notDownloaded
        ),
        Model(
            id: "jan-nano-128k-iq4xs",
            name: "Jan-Nano-128k (iQ4_XS, 2.3GB)",
            url: "https://huggingface.co/Menlo/Jan-nano-128k-gguf/resolve/main/jan-nano-128k-iQ4_XS.gguf",
            filename: "jan-nano-128k-iQ4_XS.gguf",
            sizeInBytes: 2_469_000_000, // ~2.3GB
            status: .notDownloaded
        )
    ]
}