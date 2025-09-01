//
//  StickerData.swift
//  apukou
//
//  Created by yuka on 2025/07/25.
//

import Foundation

struct StickerData: Codable {
    let id: Int
    let name: String
    let imageName: String
    let rarity: String
    let ownerName: String
    
    // JSON文字列に変換
    func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
}
