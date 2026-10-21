import Foundation
import UIKit

@MainActor
final class PatchUpdateManager: ObservableObject {
    static let shared = PatchUpdateManager()

    private static let owner = "lmd140809"
    private static let repo  = "MinhDux"
    private static let releasesAPI = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!

    @Published var availableUpdates: [PatchUpdate] = []
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var lastError: String?

    private init() {}

    func checkForUpdates() async -> [PatchUpdate] {
        isChecking = true
        lastError = nil
        defer { isChecking = false }

        do {
            var request = URLRequest(url: Self.releasesAPI)
            request.timeoutInterval = 15
            request.setValue("MinhDuc/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "GitHub", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lỗi kết nối"])
            }

            let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
            var updates: [PatchUpdate] = []

            for release in releases where !release.draft && !release.prerelease {
                guard release.tagName.hasPrefix("patch-") else { continue }
                let version = String(release.tagName.dropFirst(6).split(separator: "-").first ?? "")

                let patchAssets = release.assets.filter { $0.name.hasSuffix(".3105") }

                for asset in patchAssets {
                    let localVersion = UserDefaults.standard.string(forKey: "patch_ver_\(asset.name)") ?? "0.0.0"
                    if isNewer(remote: version, than: localVersion) {
                        updates.append(PatchUpdate(
                            version: version,
                            filename: asset.name,
                            downloadURL: URL(string: asset.browserDownloadURL)!,
                            size: asset.size,
                            notes: release.body
                        ))
                    }
                }
            }
            availableUpdates = updates
            return updates
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    func downloadAndInstall(_ update: PatchUpdate) async throws {
        isDownloading = true
        downloadProgress = 0.2
        defer { isDownloading = false }

        let (data, response) = try await URLSession.shared.data(from: update.downloadURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count > 0 else {
            throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tải thất bại"])
        }
        downloadProgress = 0.6

        let magic = Data("3105PATCH\0".utf8)
        guard data.prefix(magic.count) == magic else {
            throw NSError(domain: "Verify", code: -1, userInfo: [NSLocalizedDescriptionKey: "File không hợp lệ"])
        }

        let baseName = (update.filename as NSString).deletingPathExtension
        let destURL = try destinationURL(for: baseName)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destURL.path) {
            try? fileManager.removeItem(at: destURL)
        }
        try data.write(to: destURL, options: [.atomic])
        downloadProgress = 0.8

        UserDefaults.standard.set(update.version, forKey: "patch_ver_\(update.filename)")
        if let newName = update.notes, !newName.isEmpty {
            UserDefaults.standard.set(newName, forKey: "patch_name_\(baseName).OGIOS")
        }

        downloadProgress = 1.0
        
        await MainActor.run {
            self.availableUpdates.removeAll { $0.id == update.id }
        }
    }

    private func destinationURL(for baseName: String) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("PatchProjects", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(baseName).OGIOS")
    }

    private func isNewer(remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }
}

// MARK: - MODELS
struct PatchUpdate: Identifiable {
    let id = UUID()
    let version: String
    let filename: String
    let downloadURL: URL
    let size: Int
    let notes: String?
    var sizeFormatted: String { ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file) }
}

struct GitHubRelease: Codable {
    let tagName: String
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]
    enum CodingKeys: String, CodingKey { case tagName = "tag_name", body, draft, prerelease, assets }
}
struct GitHubAsset: Codable {
    let name: String
    let size: Int
    let browserDownloadURL: String
    enum CodingKeys: String, CodingKey { case name, size, browserDownloadURL = "browser_download_url" }
}
