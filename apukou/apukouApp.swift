//
//  apukouApp.swift
//  apukou
//
//  Created by yuka on 2025/05/06.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // カスタムURLスキーム処理（apukou://sticker）
        if url.scheme == "apukou" && url.host == "sticker" {
            return handleStickerShare(url: url)
        }
        
        // ファイルURLから画像を読み込み（従来の処理）
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let imageData = try Data(contentsOf: url)
                if let image = UIImage(data: imageData) {
                    // 新しいステッカーをデータに追加
                    StickerDataManager.shared.addReceivedSticker(image: image)
                    
                    // 通知でUI更新
                    NotificationCenter.default.post(name: .stickerReceived, object: image)
                    
                    print("ステッカーを受信しました")
                    return true
                }
            } catch {
                print("ファイル読み込みエラー: \(error)")
            }
        }
        return false
    }
    
    private func handleStickerShare(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("無効なシール共有URL")
            return false
        }
        
        var stickerName: String?
        var imageBase64: String?
        
        for item in queryItems {
            switch item.name {
            case "name":
                stickerName = item.value?.removingPercentEncoding
            case "image":
                imageBase64 = item.value
            default:
                break
            }
        }
        
        guard let imageData = imageBase64,
              let data = Data(base64Encoded: imageData),
              let image = UIImage(data: data) else {
            print("画像データの復元に失敗")
            return false
        }
        
        // シールをコレクションに追加
        StickerDataManager.shared.addReceivedSticker(image: image)
        
        // 通知でUI更新
        NotificationCenter.default.post(name: .stickerReceived, object: image)
        
        print("シール「\(stickerName ?? "Unknown")」を受信しました")
        return true
    }
}

@main
struct apukouApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
        }
    }
}

// MARK: - 通知名
extension Notification.Name {
    static let stickerReceived = Notification.Name("stickerReceived")
}
