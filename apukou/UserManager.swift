//
//  UserManager.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

// MARK: - User Data Model
struct AppUser: Identifiable, Codable {
    let id: String
    var name: String
    var username: String
    var email: String
    var bio: String?
    var profileImageURL: String?
    let createdAt: Date
    var updatedAt: Date
    
    // シール作成制限関連
    var dailyCreationCount: Int?
    var totalCreationChances: Int?
    var lastCreationResetDate: String? // "yyyy-MM-dd" 形式
    
    init(id: String, name: String, username: String, email: String, bio: String? = nil, profileImageURL: String? = nil) {
        self.id = id
        self.name = name
        self.username = username
        self.email = email
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // シール作成制限の初期値
        self.dailyCreationCount = 0
        self.totalCreationChances = 5 // 初期作成チャンス
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.lastCreationResetDate = formatter.string(from: Date())
    }
}

// MARK: - User Manager
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()
    
    private init() {
        // 認証状態の監視
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.loadUserData(userId: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    self?.isLoading = false
                }
            }
        }
    }
    
    // MARK: - サインアップ
    @MainActor
    func signUp(name: String, username: String, email: String, password: String, profileImage: UIImage? = nil) async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // ユーザーネームの重複チェック
            let usernameExists = try await checkUsernameExists(username: username)
            if usernameExists {
                self.errorMessage = "このユーザーネームは既に使用されています"
                self.isLoading = false
                return
            }
            
            // Firebase Authでユーザー作成
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // プロフィール画像をアップロード
            var profileImageURL: String? = nil
            if let profileImage = profileImage {
                profileImageURL = try await uploadProfileImage(image: profileImage, userId: result.user.uid)
            }
            
            // Firestoreにユーザー情報を保存
            let newUser = AppUser(id: result.user.uid, name: name, username: username, email: email, profileImageURL: profileImageURL)
            try await saveUserToFirestore(user: newUser)
            
            self.currentUser = newUser
            self.isAuthenticated = true
            self.isLoading = false
            
        } catch {
            self.errorMessage = self.getErrorMessage(from: error)
            self.isLoading = false
        }
    }
    
    // MARK: - サインイン
    @MainActor
    func signIn(email: String, password: String) async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await loadUserData(userId: result.user.uid)
            
            // 新しいユーザーのデータを読み込み
            StickerDataManager.shared.loadStickersFromFirebase()
            FriendsManager.shared.reloadUserData()
            
            print("✅ サインイン成功 - 新しいユーザーデータを読み込みました")
            
        } catch {
            self.errorMessage = self.getErrorMessage(from: error)
            self.isLoading = false
        }
    }
    
    // MARK: - サインアウト
    @MainActor
    func signOut() {
        do {
            try auth.signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            self.errorMessage = nil
            
            // 全マネージャーのデータをリセット
            StickerDataManager.shared.resetUserData()
            ChallengeManager.shared.resetUserData()
            FriendsManager.shared.resetUserData()
            
            print("✅ 全ユーザーデータをリセットしました")
        } catch {
            self.errorMessage = "サインアウトに失敗しました"
        }
    }
    
    // MARK: - ユーザー情報更新
    @MainActor
    func updateUserProfile(name: String, username: String, bio: String? = nil, profileImage: UIImage? = nil) async {
        guard var user = currentUser else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // ユーザーネームの重複チェック（現在のユーザーは除外）
            if username != user.username {
                let usernameExists = try await checkUsernameExists(username: username)
                if usernameExists {
                    self.errorMessage = "このユーザーネームは既に使用されています"
                    self.isLoading = false
                    return
                }
            }
            
            user.name = name
            user.username = username
            if let bio = bio {
                user.bio = bio
            }
            
            // プロフィール画像をアップロード
            if let profileImage = profileImage {
                let profileImageURL = try await uploadProfileImage(image: profileImage, userId: user.id)
                user.profileImageURL = profileImageURL
            }
            
            user.updatedAt = Date()
            
            try await saveUserToFirestore(user: user)
            
            self.currentUser = user
            self.isLoading = false
            
        } catch {
            self.errorMessage = "プロフィールの更新に失敗しました"
            self.isLoading = false
        }
    }
    
    // MARK: - Private Methods
    @MainActor
    private func loadUserData(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let data = document.data() {
                var user = try Firestore.Decoder().decode(AppUser.self, from: data)
                
                // 既存ユーザーのマイグレーション対応
                if data["dailyCreationCount"] == nil {
                    user.dailyCreationCount = 0
                    user.totalCreationChances = 5
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    user.lastCreationResetDate = formatter.string(from: Date())
                    
                    // マイグレーションデータをFirebaseに保存
                    try await saveUserToFirestore(user: user)
                    print("🔄 既存ユーザーのシール制限データをマイグレーションしました")
                }
                
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            } else {
                // ユーザードキュメントが存在しない場合
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
                self.errorMessage = "ユーザー情報が見つかりません。再度サインアップしてください。"
                // Firebase Authからもサインアウト
                try auth.signOut()
            }
        } catch {
            self.errorMessage = "ユーザー情報の読み込みに失敗しました"
            self.isAuthenticated = false
            self.isLoading = false
        }
    }
    
    private func saveUserToFirestore(user: AppUser) async throws {
        let userData = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(user.id).setData(userData)
    }
    
    private func checkUsernameExists(username: String) async throws -> Bool {
        let query = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        
        return !query.documents.isEmpty
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as NSError? {
            switch authError.code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                return "このメールアドレスは既に使用されています"
            case AuthErrorCode.invalidEmail.rawValue:
                return "無効なメールアドレスです"
            case AuthErrorCode.weakPassword.rawValue:
                return "パスワードは6文字以上で入力してください"
            case AuthErrorCode.userNotFound.rawValue:
                return "ユーザーが見つかりません"
            case AuthErrorCode.wrongPassword.rawValue:
                return "パスワードが間違っています"
            default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }
    
    // MARK: - Profile Image Upload
    private func uploadProfileImage(image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - パスワードリセット
    @MainActor
    func sendPasswordResetEmail(email: String) {
        auth.sendPasswordReset(withEmail: email) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.errorMessage = self?.getErrorMessage(from: error)
                } else {
                    self?.errorMessage = "パスワードリセット用のメールを送信しました"
                }
            }
        }
    }
    
    // MARK: - シール作成制限管理
    @MainActor
    func updateCreationLimits() async {
        guard var user = currentUser else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        
        // 日付が変わった場合は制限をリセット
        if user.lastCreationResetDate != todayString {
            // 前日までの未使用作成チャンスをそのまま繰り越し + 新しい日の1チャンスを付与
            // 報酬で増えたチャンスを失わないよう、上限で丸めない
            let unusedChances = max(0, (user.totalCreationChances ?? 0) - (user.dailyCreationCount ?? 0))
            user.totalCreationChances = unusedChances + 1 // 新しい日の1チャンス + 繰り越し
            user.dailyCreationCount = 0
            user.lastCreationResetDate = todayString
            
            // Firebaseに更新
            do {
                try await saveUserToFirestore(user: user)
                self.currentUser = user
            } catch {
                self.errorMessage = "作成制限の更新に失敗しました"
            }
        }
    }
    
    @MainActor
    func canCreateSticker() -> Bool {
        guard let user = currentUser else { return false }
        return (user.dailyCreationCount ?? 0) < (user.totalCreationChances ?? 0)
    }
    
    @MainActor
    func incrementCreationCount() async {
        guard var user = currentUser else { return }
        
        await updateCreationLimits() // 日付チェック
        
        if canCreateSticker() {
            user.dailyCreationCount! += 1
            
            do {
                try await saveUserToFirestore(user: user)
                self.currentUser = user
            } catch {
                self.errorMessage = "作成回数の更新に失敗しました"
            }
        }
    }
    
    @MainActor
    func addCreationChances(_ chances: Int) async {
        guard var user = currentUser else { return }
        
        // チャレンジ報酬の+1を正しく反映するため、上限で丸めない
        user.totalCreationChances = (user.totalCreationChances ?? 0) + chances
        
        do {
            try await saveUserToFirestore(user: user)
            self.currentUser = user
        } catch {
            self.errorMessage = "作成チャンスの更新に失敗しました"
        }
    }
    
    @MainActor
    func restoreCreationChance() async {
        guard var user = currentUser else { return }
        
        // 使用済み作成回数を1減らす（最低0）
        user.dailyCreationCount = max(0, (user.dailyCreationCount ?? 0) - 1)
        
        do {
            try await saveUserToFirestore(user: user)
            self.currentUser = user
        } catch {
            self.errorMessage = "作成チャンスの回復に失敗しました"
        }
    }
    
    func getRemainingCreationChances() -> Int {
        guard let user = currentUser else { return 0 }
        return max(0, (user.totalCreationChances ?? 0) - (user.dailyCreationCount ?? 0))
    }
    
    // MARK: - アカウント削除
    @MainActor
    func deleteAccount() {
        guard let user = auth.currentUser else {
            errorMessage = "認証されていません"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Firestoreからユーザーデータを削除
                try await db.collection("users").document(user.uid).delete()
                
                // プロフィール画像を削除
                if let profileImageURL = currentUser?.profileImageURL,
                   !profileImageURL.isEmpty {
                    let imageRef = storage.reference(forURL: profileImageURL)
                    try await imageRef.delete()
                }
                
                // Firebase Authからアカウントを削除
                try await user.delete()
                
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isLoading = false
                    self.errorMessage = nil
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = self.getErrorMessage(from: error)
                    self.isLoading = false
                }
            }
        }
    }
}
