//
//  StickerDataManager.swift
//  apukou
//
//  Created by yuka on 2025/07/27.
//

import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

// MARK: - ステッカーデータ管理
class StickerDataManager: ObservableObject {
    static let shared = StickerDataManager()
    
    @Published var stickerSlots: [StickerItem?] = Array(repeating: nil, count: 10)
    @Published var additionalStickers: [StickerItem] = []  // 11個目以降のシール
    
    // 既存のstickersプロパティとの互換性のため
    var stickers: [StickerItem] {
        return stickerSlots.compactMap { $0 } + additionalStickers
    }
    @Published var canCreateTodaysSticker: Bool = true
    @Published var availableCreationChances: Int = 1
    
    private let userManager = UserManager.shared
    
    private init() {
        // Firebaseからステッカーを読み込み（初期化時はクリアしない）
        loadStickersFromFirebase()
        
        // 作成制限の初期チェック
        Task { @MainActor in
            await updateTodaysCreationStatus()
        }
    }
    
    func resetUserData() {
        DispatchQueue.main.async {
            self.stickerSlots = Array(repeating: nil, count: 10)
            self.additionalStickers = []
            self.canCreateTodaysSticker = true
            self.availableCreationChances = 1
            print("✅ StickerDataManager データをリセットしました")
        }
    }
    
    func addReceivedSticker(image: UIImage, challengeTitle: String? = nil) {
        let newSticker: StickerItem
        
        if let emptySlotIndex = stickerSlots.firstIndex(where: { $0 == nil }) {
            // 空きスロットがある場合
            newSticker = StickerItem(
                id: emptySlotIndex,
                isObtained: true,
                createDate: Date(),
                isFromExchange: challengeTitle == nil, // チャレンジの場合は交換ではない
                exchangeDate: challengeTitle == nil ? Date() : nil,
                customImage: image,
                imageScale: 1.0,
                imageTranslation: .zero,
                challengeTitle: challengeTitle
            )
            
            DispatchQueue.main.async {
                self.stickerSlots[emptySlotIndex] = newSticker
            }
        } else {
            // スロットが満杯の場合
            let nextId = 10 + additionalStickers.count
            newSticker = StickerItem(
                id: nextId,
                isObtained: true,
                createDate: Date(),
                isFromExchange: challengeTitle == nil, // チャレンジの場合は交換ではない
                exchangeDate: challengeTitle == nil ? Date() : nil,
                customImage: image,
                imageScale: 1.0,
                imageTranslation: .zero,
                challengeTitle: challengeTitle
            )
            
            DispatchQueue.main.async {
                self.additionalStickers.append(newSticker)
            }
        }
        
        // Firebaseに保存し、URLを更新
        uploadStickerToFirebase(image: image, isFromExchange: challengeTitle == nil, challengeTitle: challengeTitle) { [weak self] result in
            switch result {
            case .success(let documentID):
                print("受信ステッカーをFirebaseに保存しました: \(documentID)")
                // 保存成功時にFirebase URLを取得してシールアイテムを更新
                self?.updateStickerWithFirebaseURL(sticker: newSticker)
            case .failure(let error):
                print("Firebaseへの保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateStickerWithFirebaseURL(sticker: StickerItem) {
        // 最新のFirebaseドキュメントからURLを取得してシールを更新
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("users").document(userId).collection("stickers")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Firebase URL取得に失敗しました: \(error.localizedDescription)")
                    return
                }
                
                guard let document = snapshot?.documents.first,
                      let imageURL = document.data()["imageURL"] as? String else {
                    print("❌ Firebase URLが見つかりません")
                    return
                }
                
                DispatchQueue.main.async {
                    // スロット内のシールを更新
                    if sticker.id < 10, let existingSticker = self?.stickerSlots[sticker.id] {
                        let updatedSticker = StickerItem(
                            id: existingSticker.id,
                            isObtained: existingSticker.isObtained,
                            createDate: existingSticker.createDate,
                            isFromExchange: existingSticker.isFromExchange,
                            exchangeDate: existingSticker.exchangeDate,
                            customImage: existingSticker.customImage,
                            firebaseImageURL: imageURL,
                            drawingData: existingSticker.drawingData,
                            textElements: existingSticker.textElements,
                            shape: existingSticker.shape,
                            recipientName: existingSticker.recipientName,
                            recipientUsername: existingSticker.recipientUsername,
                            recipientAvatarName: existingSticker.recipientAvatarName,
                            isSent: existingSticker.isSent,
                            stickerName: existingSticker.stickerName,
                            imageScale: existingSticker.imageScale,
                            imageTranslation: existingSticker.imageTranslation,
                            challengeTitle: existingSticker.challengeTitle
                        )
                        self?.stickerSlots[sticker.id] = updatedSticker
                    } else {
                        // 追加シール配列内のシールを更新
                        if let index = self?.additionalStickers.firstIndex(where: { $0.id == sticker.id }) {
                            let existingSticker = self?.additionalStickers[index]
                            let updatedSticker = StickerItem(
                                id: existingSticker?.id ?? sticker.id,
                                isObtained: existingSticker?.isObtained ?? true,
                                createDate: existingSticker?.createDate ?? Date(),
                                isFromExchange: existingSticker?.isFromExchange ?? true,
                                exchangeDate: existingSticker?.exchangeDate,
                                customImage: existingSticker?.customImage,
                                firebaseImageURL: imageURL,
                                drawingData: existingSticker?.drawingData,
                                textElements: existingSticker?.textElements,
                                shape: existingSticker?.shape,
                                recipientName: existingSticker?.recipientName,
                                recipientUsername: existingSticker?.recipientUsername,
                                recipientAvatarName: existingSticker?.recipientAvatarName,
                                isSent: existingSticker?.isSent ?? false,
                                stickerName: existingSticker?.stickerName,
                                imageScale: existingSticker?.imageScale ?? 1.0,
                                imageTranslation: existingSticker?.imageTranslation ?? .zero,
                                challengeTitle: existingSticker?.challengeTitle
                            )
                            self?.additionalStickers[index] = updatedSticker
                        }
                    }
                    
                    print("✅ Firebase URLを更新しました: \(imageURL)")
                }
            }
    }
    
    func addSentSticker(image: UIImage, friend: Friend) {
        // 最初の空きスロットを見つける
        guard let emptySlotIndex = stickerSlots.firstIndex(where: { $0 == nil }) else {
            print("❌ 利用可能なスロットがありません")
            return
        }
        
        let newSticker = StickerItem(
            id: emptySlotIndex,
            isObtained: true,
            createDate: Date(),
            isFromExchange: true,
            exchangeDate: Date(),
            customImage: image,
            recipientName: friend.name,
            recipientUsername: friend.username,
            recipientAvatarName: friend.avatarName,
            isSent: true,
            imageScale: 1.0,
            imageTranslation: .zero
        )
        
        DispatchQueue.main.async {
            self.stickerSlots[emptySlotIndex] = newSticker
        }
        
        // Firebaseに保存（送信済みマークを付ける）
        uploadStickerToFirebase(image: image, isFromExchange: true, friend: friend) { result in
            switch result {
            case .success(let documentID):
                print("送信ステッカーをFirebaseに保存しました: \(documentID)")
            case .failure(let error):
                print("Firebaseへの保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    func addCreatedSticker(image: UIImage, drawingData: Data? = nil, textElements: [TextElementData]? = nil, shape: String? = nil, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero, isInitialSlot: Bool = false) {
        // isInitialSlotが true の場合は一切の制限をかけない
        if !isInitialSlot && availableCreationChances <= 0 {
            print("❌ 作成可能なチャンスがありません")
            return
        }
        let newSticker: StickerItem
        
        // 最初の空きスロットを確認
        if let emptySlotIndex = stickerSlots.firstIndex(where: { $0 == nil }) {
            // 空きスロットがある場合はスロットに配置
            newSticker = StickerItem(
                id: emptySlotIndex,  // スロットインデックスをIDとして使用
                isObtained: true,
                createDate: Date(),
                isFromExchange: false,
                exchangeDate: nil,
                customImage: image,
                drawingData: drawingData,
                textElements: textElements,
                shape: shape,
                stickerName: stickerName,
                imageScale: imageScale,
                imageTranslation: imageTranslation
            )
            
            DispatchQueue.main.async {
                self.stickerSlots[emptySlotIndex] = newSticker
                
                // 初期10スロットを全て使い切った場合はチャンスを消費
                let remainingEmptySlots = self.stickerSlots[0..<10].filter({ $0 == nil }).count
                if remainingEmptySlots == 0 {
                    // 最後の1つを埋めた場合、次回から制限開始
                    Task {
                        await self.consumeCreationChance()
                    }
                }
            }
        } else {
            // スロットが満杯の場合は追加配列に追加
            let nextId = 10 + additionalStickers.count  // ID 10以降を使用
            newSticker = StickerItem(
                id: nextId,
                isObtained: true,
                createDate: Date(),
                isFromExchange: false,
                exchangeDate: nil,
                customImage: image,
                drawingData: drawingData,
                textElements: textElements,
                shape: shape,
                stickerName: stickerName,
                imageScale: imageScale,
                imageTranslation: imageTranslation
            )
            
            DispatchQueue.main.async {
                self.additionalStickers.append(newSticker)
                // 11個目以降は常にチャンスを消費
                Task {
                    await self.consumeCreationChance()
                }
            }
        }
        // Firebaseに保存
        uploadStickerToFirebase(image: image, isFromExchange: false, drawingData: drawingData, textElements: textElements, shape: shape, stickerName: stickerName, imageScale: imageScale, imageTranslation: imageTranslation) { result in
            switch result {
            case .success(let documentID):
                print("作成ステッカーをFirebaseに保存しました: \(documentID)")
            case .failure(let error):
                print("Firebaseへの保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Firebase関連メソッド
    private func uploadStickerToFirebase(image: UIImage, isFromExchange: Bool, drawingData: Data? = nil, textElements: [TextElementData]? = nil, friend: Friend? = nil, shape: String? = nil, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero, challengeTitle: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "StickerDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }
        
        let fileName = UUID().uuidString + ".jpg"
        let storageRef = Storage.storage().reference().child("stickers/\(fileName)")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let downloadURL = url {
                    // Firestoreにメタデータを保存
                    self.saveStickerDataToFirestore(imageURL: downloadURL.absoluteString, isFromExchange: isFromExchange, drawingData: drawingData, textElements: textElements, friend: friend, shape: shape, stickerName: stickerName, imageScale: imageScale, imageTranslation: imageTranslation, challengeTitle: challengeTitle, completion: completion)
                }
            }
        }
    }
    
    private func saveStickerDataToFirestore(imageURL: String, isFromExchange: Bool, drawingData: Data? = nil, textElements: [TextElementData]? = nil, friend: Friend? = nil, shape: String? = nil, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero, challengeTitle: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "StickerDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーIDが取得できません"])))
            return
        }
        
        let docRef = Firestore.firestore().collection("users").document(userId).collection("stickers").document()
        
        var data: [String: Any] = [
            "id": docRef.documentID,
            "imageURL": imageURL,
            "isFromExchange": isFromExchange,
            "isObtained": true,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // 友達情報を追加（送信済みシールの場合）
        if let friend = friend {
            data["recipientName"] = friend.name
            data["recipientUsername"] = friend.username
            data["recipientAvatarName"] = friend.avatarName
            data["isSent"] = true
        }
        
        // シール名を追加
        if let stickerName = stickerName, !stickerName.isEmpty {
            data["stickerName"] = stickerName
        }
        
        // チャレンジタイトルを追加
        if let challengeTitle = challengeTitle, !challengeTitle.isEmpty {
            data["challengeTitle"] = challengeTitle
        }
        
        // 形状を追加
        if let shape = shape, !shape.isEmpty {
            data["shape"] = shape
        }
        
        // 描画データを追加
        if let drawingData = drawingData {
            data["drawingData"] = drawingData.base64EncodedString()
        }
        
        // テキスト要素を追加
        if let textElements = textElements {
            do {
                let encoder = JSONEncoder()
                let textElementsData = try encoder.encode(textElements)
                data["textElements"] = textElementsData.base64EncodedString()
            } catch {
                print("テキスト要素のエンコードに失敗しました: \(error)")
            }
        }
        
        // 画像変形情報を追加
        data["imageScale"] = imageScale
        data["imageTranslationX"] = imageTranslation.width
        data["imageTranslationY"] = imageTranslation.height
        
        docRef.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(docRef.documentID))
            }
        }
    }
    
    // MARK: - Firebaseからステッカーを読み込み
    func loadStickersFromFirebase() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ ユーザーIDが取得できません")
            return
        }
        
        Firestore.firestore().collection("users").document(userId).collection("stickers")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Firebaseからのステッカー読み込みに失敗しました: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                DispatchQueue.main.async {
                    let firebaseStickers = documents.compactMap { doc -> StickerItem? in
                        let data = doc.data()
                        guard let imageURL = data["imageURL"] as? String else { return nil }
                        
                        // 描画データを復元
                        var drawingData: Data? = nil
                        if let drawingDataString = data["drawingData"] as? String {
                            drawingData = Data(base64Encoded: drawingDataString)
                        }
                        
                        // テキスト要素を復元
                        var textElements: [TextElementData]? = nil
                        if let textElementsString = data["textElements"] as? String,
                           let textElementsData = Data(base64Encoded: textElementsString) {
                            do {
                                let decoder = JSONDecoder()
                                textElements = try decoder.decode([TextElementData].self, from: textElementsData)
                            } catch {
                                print("テキスト要素のデコードに失敗しました: \(error)")
                            }
                        }
                        
                        // 画像変形情報を復元
                        let imageScale = data["imageScale"] as? CGFloat ?? 1.0
                        let imageTranslationX = data["imageTranslationX"] as? CGFloat ?? 0
                        let imageTranslationY = data["imageTranslationY"] as? CGFloat ?? 0
                        let imageTranslation = CGSize(width: imageTranslationX, height: imageTranslationY)
                        
                        return StickerItem(
                            id: documents.firstIndex(of: doc) ?? 0,  // 一時的なID、後で適切なスロットに配置
                            isObtained: data["isObtained"] as? Bool ?? true,
                            createDate: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            isFromExchange: data["isFromExchange"] as? Bool ?? false,
                            exchangeDate: (data["isFromExchange"] as? Bool ?? false) ? (data["createdAt"] as? Timestamp)?.dateValue() : nil,
                            customImage: nil,
                            firebaseImageURL: imageURL,
                            drawingData: drawingData,
                            textElements: textElements,
                            shape: data["shape"] as? String,
                            recipientName: data["recipientName"] as? String,
                            recipientUsername: data["recipientUsername"] as? String,
                            recipientAvatarName: data["recipientAvatarName"] as? String,
                            isSent: data["isSent"] as? Bool ?? false,
                            stickerName: data["stickerName"] as? String,
                            imageScale: imageScale,
                            imageTranslation: imageTranslation,
                            challengeTitle: data["challengeTitle"] as? String
                        )
                    }
                    
                    // Firebaseのステッカーをスロットまたは追加配列に配置
                    var stickerCount = 0
                    for var sticker in firebaseStickers {
                        // 最初の10個はスロットに配置
                        if let emptySlotIndex = self?.stickerSlots.firstIndex(where: { $0 == nil }) {
                            sticker = StickerItem(
                                id: emptySlotIndex,  // スロットインデックスをIDに設定
                                isObtained: sticker.isObtained,
                                createDate: sticker.createDate,
                                isFromExchange: sticker.isFromExchange,
                                exchangeDate: sticker.exchangeDate,
                                customImage: sticker.customImage,
                                firebaseImageURL: sticker.firebaseImageURL,
                                drawingData: sticker.drawingData,
                                textElements: sticker.textElements,
                                shape: sticker.shape,
                                recipientName: sticker.recipientName,
                                recipientUsername: sticker.recipientUsername,
                                recipientAvatarName: sticker.recipientAvatarName,
                                isSent: sticker.isSent,
                                stickerName: sticker.stickerName,
                                imageScale: sticker.imageScale,
                                imageTranslation: sticker.imageTranslation,
                                challengeTitle: sticker.challengeTitle
                            )
                            self?.stickerSlots[emptySlotIndex] = sticker
                            
                            // Firebase画像をローカルにダウンロードして保存
                            if let imageURL = sticker.firebaseImageURL {
                                self?.downloadAndCacheImage(from: imageURL, for: emptySlotIndex)
                            }
                        } else {
                            // スロットが満杯の場合は追加配列に配置
                            let additionalId = 10 + stickerCount
                            sticker = StickerItem(
                                id: additionalId,
                                isObtained: sticker.isObtained,
                                createDate: sticker.createDate,
                                isFromExchange: sticker.isFromExchange,
                                exchangeDate: sticker.exchangeDate,
                                customImage: sticker.customImage,
                                firebaseImageURL: sticker.firebaseImageURL,
                                drawingData: sticker.drawingData,
                                textElements: sticker.textElements,
                                shape: sticker.shape,
                                recipientName: sticker.recipientName,
                                recipientUsername: sticker.recipientUsername,
                                recipientAvatarName: sticker.recipientAvatarName,
                                isSent: sticker.isSent,
                                stickerName: sticker.stickerName,
                                imageScale: sticker.imageScale,
                                imageTranslation: sticker.imageTranslation,
                                challengeTitle: sticker.challengeTitle
                            )
                            self?.additionalStickers.append(sticker)
                            
                            // Firebase画像をローカルにダウンロードして保存
                            if let imageURL = sticker.firebaseImageURL {
                                self?.downloadAndCacheAdditionalImage(from: imageURL, for: additionalId)
                            }
                        }
                        stickerCount += 1
                    }
                }
            }
    }
    
    // Firebase画像をダウンロードしてローカル保存（スロット用）
    private func downloadAndCacheImage(from urlString: String, for slotIndex: Int) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("❌ 画像ダウンロードエラー: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ 画像データの変換に失敗")
                return
            }
            
            DispatchQueue.main.async {
                if var existingSticker = self?.stickerSlots[slotIndex] {
                    existingSticker.customImage = image
                    self?.stickerSlots[slotIndex] = existingSticker
                    print("✅ Firebase画像をローカル保存: スロット\(slotIndex)")
                }
            }
        }.resume()
    }
    
    // Firebase画像をダウンロードしてローカル保存（追加シール用）
    private func downloadAndCacheAdditionalImage(from urlString: String, for stickerId: Int) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("❌ 追加シール画像ダウンロードエラー: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ 追加シール画像データの変換に失敗")
                return
            }
            
            DispatchQueue.main.async {
                if let index = self?.additionalStickers.firstIndex(where: { $0.id == stickerId }) {
                    var existingSticker = self?.additionalStickers[index]
                    existingSticker?.customImage = image
                    if let updatedSticker = existingSticker {
                        self?.additionalStickers[index] = updatedSticker
                    }
                    print("✅ Firebase画像をローカル保存: 追加シール\(stickerId)")
                }
            }
        }.resume()
    }
    
    // MARK: - シールを削除
    func deleteSticker(_ sticker: StickerItem) {
        let wasUserCreated = !sticker.isFromExchange && sticker.challengeTitle == nil
        let isFromAdditionalSlots = sticker.id >= 10
        
        DispatchQueue.main.async {
            // スロットをnilにする（IDがスロットインデックス）
            if sticker.id < self.stickerSlots.count {
                self.stickerSlots[sticker.id] = nil
            } else {
                // 追加シールから削除
                self.additionalStickers.removeAll { $0.id == sticker.id }
            }
            
            // 11枚目以降のユーザー作成シールを削除した場合、チャンスを回復
            if wasUserCreated && isFromAdditionalSlots {
                Task {
                    await self.restoreCreationChance()
                }
            }
        }
        
        // Firebaseからも削除
        deleteStickerFromFirebase(sticker: sticker)
    }
    
    private func deleteStickerFromFirebase(sticker: StickerItem) {
        guard let imageURL = sticker.firebaseImageURL,
              let userId = Auth.auth().currentUser?.uid else {
            print("❌ Firebase URL またはユーザーIDがありません")
            return
        }
        
        Firestore.firestore().collection("users").document(userId).collection("stickers")
            .whereField("imageURL", isEqualTo: imageURL)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ ドキュメントの検索に失敗しました: \(error.localizedDescription)")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("❌ 削除対象のドキュメントが見つかりません")
                    return
                }
                
                // Firestoreドキュメントを削除
                document.reference.delete { error in
                    if let error = error {
                        print("❌ Firestoreからの削除に失敗しました: \(error.localizedDescription)")
                    } else {
                        print("✅ Firestoreからシールを削除しました")
                    }
                }
                
                // Firebase Storageからも画像を削除
                let storageRef = Storage.storage().reference(forURL: imageURL)
                storageRef.delete { error in
                    if let error = error {
                        print("❌ Storageからの削除に失敗しました: \(error.localizedDescription)")
                    } else {
                        print("✅ Storageからシール画像を削除しました")
                    }
                }
            }
    }
    
    func updateSticker(_ sticker: StickerItem, newImage: UIImage, drawingData: Data? = nil, textElements: [TextElementData]? = nil, shape: String? = nil, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero) {
        DispatchQueue.main.async {
            // IDがスロットインデックスなので直接アクセス
            if sticker.id < self.stickerSlots.count, var existingSticker = self.stickerSlots[sticker.id] {
                print("✅ Updating existing sticker at slot \(sticker.id)")
                // Only update the modifiable fields, preserve position-determining fields
                existingSticker.customImage = newImage
                existingSticker.drawingData = drawingData
                existingSticker.textElements = textElements
                existingSticker.shape = shape
                existingSticker.stickerName = stickerName
                existingSticker.imageScale = imageScale
                existingSticker.imageTranslation = imageTranslation
                // スロットを更新
                self.stickerSlots[sticker.id] = existingSticker
                print("✅ Sticker updated successfully at slot \(sticker.id)")
            } else {
                print("❌ Could not find sticker with ID \(sticker.id) for update")
            }
        }
        
        // Firebaseにも更新を保存
        if let firebaseURL = sticker.firebaseImageURL {
            updateStickerInFirebase(sticker: sticker, newImage: newImage, drawingData: drawingData, textElements: textElements, shape: shape, stickerName: stickerName, imageScale: imageScale, imageTranslation: imageTranslation) { result in
                switch result {
                case .success:
                    print("シールの更新をFirebaseに保存しました")
                case .failure(let error):
                    print("Firebaseへの更新保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateStickerInFirebase(sticker: StickerItem, newImage: UIImage, drawingData: Data? = nil, textElements: [TextElementData]? = nil, shape: String? = nil, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero, completion: @escaping (Result<Void, Error>) -> Void) {
        // 新しい画像をアップロード
        guard let imageData = newImage.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "StickerDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }
        
        let fileName = UUID().uuidString + ".jpg"
        let storageRef = Storage.storage().reference().child("stickers/\(fileName)")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let downloadURL = url {
                    // Firestoreのドキュメントを更新
                    self.updateStickerDocumentInFirestore(sticker: sticker, newImageURL: downloadURL.absoluteString, drawingData: drawingData, textElements: textElements, shape: shape, stickerName: stickerName, imageScale: imageScale, imageTranslation: imageTranslation, completion: completion)
                }
            }
        }
    }
    
    private func updateStickerDocumentInFirestore(sticker: StickerItem, newImageURL: String, drawingData: Data? = nil, textElements: [TextElementData]? = nil, shape: String? = nil, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero, completion: @escaping (Result<Void, Error>) -> Void) {
        // Firebase URLからドキュメントIDを取得（簡易的な方法）
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "StickerDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーIDが取得できません"])))
            return
        }
        
        Firestore.firestore().collection("users").document(userId).collection("stickers")
            .whereField("imageURL", isEqualTo: sticker.firebaseImageURL ?? "")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(.failure(NSError(domain: "StickerDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ドキュメントが見つかりません"])))
                    return
                }
                
                var updateData: [String: Any] = [
                    "imageURL": newImageURL,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                // 描画データを追加
                if let drawingData = drawingData {
                    updateData["drawingData"] = drawingData.base64EncodedString()
                } else {
                    updateData["drawingData"] = FieldValue.delete()
                }
                
                // テキスト要素を追加
                if let textElements = textElements {
                    do {
                        let encoder = JSONEncoder()
                        let textElementsData = try encoder.encode(textElements)
                        updateData["textElements"] = textElementsData.base64EncodedString()
                    } catch {
                        print("テキスト要素のエンコードに失敗しました: \(error)")
                        updateData["textElements"] = FieldValue.delete()
                    }
                } else {
                    updateData["textElements"] = FieldValue.delete()
                }
                
                // 形状を追加
                if let shape = shape, !shape.isEmpty {
                    updateData["shape"] = shape
                } else {
                    updateData["shape"] = FieldValue.delete()
                }
                
                // シール名を追加
                if let stickerName = stickerName, !stickerName.isEmpty {
                    updateData["stickerName"] = stickerName
                } else {
                    updateData["stickerName"] = FieldValue.delete()
                }
                
                // 画像変形情報を追加
                updateData["imageScale"] = imageScale
                updateData["imageTranslationX"] = imageTranslation.width
                updateData["imageTranslationY"] = imageTranslation.height
                
                document.reference.updateData(updateData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
}

// MARK: - ステッカーアイテムモデル
struct StickerItem: Identifiable {
    let id: Int
    let isObtained: Bool
    let createDate: Date
    let isFromExchange: Bool
    let exchangeDate: Date?
    var customImage: UIImage?
    let firebaseImageURL: String?
    var drawingData: Data?
    var textElements: [TextElementData]?
    var shape: String?
    var recipientName: String?
    var recipientUsername: String?
    var recipientAvatarName: String?
    var isSent: Bool
    var stickerName: String?
    var imageScale: CGFloat
    var imageTranslation: CGSize
    var challengeTitle: String? // チャレンジでゲットしたシール用
    
    init(id: Int, isObtained: Bool, createDate: Date, isFromExchange: Bool, exchangeDate: Date?, customImage: UIImage? = nil, firebaseImageURL: String? = nil, drawingData: Data? = nil, textElements: [TextElementData]? = nil, shape: String? = nil, recipientName: String? = nil, recipientUsername: String? = nil, recipientAvatarName: String? = nil, isSent: Bool = false, stickerName: String? = nil, imageScale: CGFloat = 1.0, imageTranslation: CGSize = .zero, challengeTitle: String? = nil) {
        self.id = id
        self.isObtained = isObtained
        self.createDate = createDate
        self.isFromExchange = isFromExchange
        self.exchangeDate = exchangeDate
        self.customImage = customImage
        self.firebaseImageURL = firebaseImageURL
        self.drawingData = drawingData
        self.textElements = textElements
        self.shape = shape
        self.recipientName = recipientName
        self.recipientUsername = recipientUsername
        self.recipientAvatarName = recipientAvatarName
        self.isSent = isSent
        self.stickerName = stickerName
        self.imageScale = imageScale
        self.imageTranslation = imageTranslation
        self.challengeTitle = challengeTitle
    }
}

// MARK: - 作成制限管理拡張
extension StickerDataManager {
    @MainActor
    private func updateTodaysCreationStatus() async {
        await userManager.updateCreationLimits()
        
        availableCreationChances = userManager.getRemainingCreationChances()
        canCreateTodaysSticker = userManager.canCreateSticker()
        
        print("📊 現在の作成チャンス: \(availableCreationChances), 作成可能: \(canCreateTodaysSticker)")
    }
    
    @MainActor
    private func consumeCreationChance() async {
        await userManager.incrementCreationCount()
        
        availableCreationChances = userManager.getRemainingCreationChances()
        canCreateTodaysSticker = userManager.canCreateSticker()
        
        print("✅ チャンスを1つ消費。残り: \(availableCreationChances)")
    }
    
    func canCreateNewSticker() -> Bool {
        Task { @MainActor in
            await updateTodaysCreationStatus()
        }
        return canCreateTodaysSticker
    }
    
    func getAvailableCreationChances() -> Int {
        Task { @MainActor in
            await updateTodaysCreationStatus()
        }
        return availableCreationChances
    }
    
    @MainActor
    func addCreationChances(_ count: Int) async {
        await userManager.addCreationChances(count)
        
        availableCreationChances = userManager.getRemainingCreationChances()
        canCreateTodaysSticker = userManager.canCreateSticker()
        
        print("✅ 作成チャンスを\(count)個追加。合計: \(availableCreationChances)")
    }
    
    @MainActor
    private func restoreCreationChance() async {
        await userManager.restoreCreationChance()
        
        availableCreationChances = userManager.getRemainingCreationChances()
        canCreateTodaysSticker = userManager.canCreateSticker()
        
        print("✅ シール削除により作成チャンスを1個回復。合計: \(availableCreationChances)")
    }
    
    // MARK: - シール交換機能
    func exchangeSticker(sticker: StickerItem, image: UIImage, friend: Friend, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid,
              let friendId = friend.id else {
            print("❌ ユーザーIDまたは友達IDが取得できません")
            completion(false)
            return
        }
        
        print("📤 シール交換開始: \(sticker.stickerName ?? "シール#\(sticker.id)") → \(friend.name)")
        
        // 送信者情報を取得
        let currentUser = UserManager.shared.currentUser
        
        // 交換相手のFirestoreコレクションに送るシール情報を準備
        var exchangedStickerData: [String: Any] = [
            "isObtained": true,
            "isFromExchange": true,
            "createdAt": FieldValue.serverTimestamp(),
            "exchangeDate": FieldValue.serverTimestamp(),
            "stickerName": sticker.stickerName ?? "",
            "shape": sticker.shape ?? "circle",
            "imageScale": sticker.imageScale,
            "imageTranslationX": sticker.imageTranslation.width,
            "imageTranslationY": sticker.imageTranslation.height,
            "recipientName": currentUser?.name ?? "Unknown",
            "recipientUsername": currentUser?.username ?? "@unknown", 
            "recipientAvatarName": "person.circle.fill"
        ]
        
        // 描画データを追加
        if let drawingData = sticker.drawingData {
            exchangedStickerData["drawingData"] = drawingData.base64EncodedString()
        }
        
        // テキスト要素を追加
        if let textElements = sticker.textElements {
            do {
                let encoder = JSONEncoder()
                let textElementsData = try encoder.encode(textElements)
                exchangedStickerData["textElements"] = textElementsData.base64EncodedString()
            } catch {
                print("❌ テキスト要素のエンコードに失敗: \(error)")
            }
        }
        
        // 画像をFirebase Storageにアップロード
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ 画像データの変換に失敗")
            completion(false)
            return
        }
        
        let fileName = "exchanged_\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("stickers/\(fileName)")
        
        storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                print("❌ 画像アップロードに失敗: \(error)")
                completion(false)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ ダウンロードURL取得に失敗: \(error)")
                    completion(false)
                    return
                }
                
                guard let downloadURL = url else {
                    print("❌ ダウンロードURLが取得できません")
                    completion(false)
                    return
                }
                
                // 画像URLを追加
                exchangedStickerData["imageURL"] = downloadURL.absoluteString
                
                // 相手のFirestoreに交換シールを追加
                Firestore.firestore().collection("users").document(friendId).collection("stickers")
                    .addDocument(data: exchangedStickerData) { error in
                        if let error = error {
                            print("❌ 相手へのシール送信に失敗: \(error)")
                            completion(false)
                        } else {
                            print("✅ シールを相手に送信完了: \(friend.name)")
                            completion(true)
                        }
                    }
            }
        }
    }
    
    // シール送信（交換機能のエイリアス）
    func sendStickerToFriend(sticker: StickerItem, image: UIImage, friend: Friend) {
        exchangeSticker(sticker: sticker, image: image, friend: friend) { success in
            if success {
                print("✅ シール交換が完了しました")
            } else {
                print("❌ シール交換に失敗しました")
            }
        }
    }
}

// MARK: - テキスト要素データモデル
struct TextElementData: Codable {
    let id: String
    let text: String
    let x: Double
    let y: Double
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let fontSize: Double
    let rotation: Double
}


