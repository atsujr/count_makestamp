//
//  FriendsManager.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class FriendsManager: ObservableObject {
    static let shared = FriendsManager()
    
    @Published var friends: [Friend] = []
    @Published var friendRequests: [Friend] = []
    @Published var sentRequests: [Friend] = []
    
    private let db = Firestore.firestore()
    private var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // 全ユーザー（友達+友達じゃない）
    @Published var allUsers: [Friend] = []
    
    private init() {
        print("🔧 FriendsManager初期化開始")
        loadFriends()
        loadFriendRequests()
        loadSentRequests()
        loadAllUsers()
    }
    
    // MARK: - データ読み込み
    private func loadFriends() {
        guard let userId = currentUserId else { 
            print("⚠️ loadFriends: ユーザーIDが取得できません")
            return 
        }
        
        print("👥 友達一覧を読み込み中: userID=\(userId)")
        
        db.collection("users").document(userId).collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("友達の読み込みエラー: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                print("👥 取得した友達数: \(documents.count) for userID: \(userId)")
                
                DispatchQueue.main.async {
                    self?.friends = documents.compactMap { doc in
                        let data = doc.data()
                        let friend = Friend(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "Unknown",
                            username: data["username"] as? String ?? "@unknown",
                            avatarName: data["avatarName"] as? String ?? "person.circle.fill",
                            profileImageURL: data["profileImageURL"] as? String,
                            userId: data["userId"] as? String ?? doc.documentID
                        )
                        print("👥 読み込んだ友達: \(friend.name) (ID: \(doc.documentID))")
                        return friend
                    }
                    print("👥 最終的な友達配列サイズ: \(self?.friends.count ?? 0)")
                }
            }
    }
    
    private func loadFriendRequests() {
        guard let userId = currentUserId else { return }
        print("📥 友達リクエストを読み込み中: userID=\(userId)")
        
        db.collection("users").document(userId).collection("friendRequests")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("友達リクエストの読み込みエラー: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                print("📥 受信した友達リクエスト数: \(documents.count)")
                
                DispatchQueue.main.async {
                    self?.friendRequests = documents.compactMap { doc in
                        let data = doc.data()
                        let friend = Friend(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "Unknown",
                            username: data["username"] as? String ?? "@unknown",
                            avatarName: data["avatarName"] as? String ?? "person.circle.fill",
                            profileImageURL: data["profileImageURL"] as? String,
                            userId: data["userId"] as? String ?? doc.documentID
                        )
                        print("📥 受信したリクエスト: \(friend.name) (\(friend.id ?? "no-id"))")
                        return friend
                    }
                    print("📥 最終的な友達リクエスト数: \(self?.friendRequests.count ?? 0)")
                }
            }
    }
    
    private func loadSentRequests() {
        guard let userId = currentUserId else { return }
        print("📤 送信済みリクエストを読み込み中: userID=\(userId)")
        
        db.collection("users").document(userId).collection("sentRequests")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("送信済みリクエストの読み込みエラー: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                print("📤 送信済みリクエスト数: \(documents.count)")
                
                DispatchQueue.main.async {
                    self?.sentRequests = documents.compactMap { doc in
                        let data = doc.data()
                        return Friend(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "Unknown",
                            username: data["username"] as? String ?? "@unknown",
                            avatarName: data["avatarName"] as? String ?? "person.circle.fill",
                            profileImageURL: data["profileImageURL"] as? String,
                            userId: data["userId"] as? String ?? doc.documentID
                        )
                    }
                }
            }
    }
    
    private func loadAllUsers() {
        db.collection("users")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("全ユーザーの読み込みエラー: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.allUsers = documents.compactMap { doc -> Friend? in
                        let data = doc.data()
                        return Friend(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "",
                            username: data["username"] as? String ?? "",
                            avatarName: data["avatarName"] as? String ?? "person.circle.fill",
                            profileImageURL: data["profileImageURL"] as? String,
                            userId: doc.documentID
                        )
                    }
                }
            }
    }
    
    // MARK: - 友達操作
    func addFriend(_ friend: Friend) {
        guard let userId = currentUserId else { return }
        
        do {
            try db.collection("users").document(userId).collection("friends").document(friend.id ?? "").setData(from: friend)
            print("✅ 友達をFirestoreに追加: \(friend.name) → userID: \(userId)")
            
            // ローカルの配列にも追加（重複チェック）
            DispatchQueue.main.async {
                if !self.friends.contains(where: { $0.id == friend.id }) {
                    self.friends.append(friend)
                    print("✅ 友達をローカル配列に追加: \(friend.name)")
                } else {
                    print("⚠️ 友達は既にローカル配列に存在: \(friend.name)")
                }
            }
        } catch {
            print("友達追加エラー: \(error)")
        }
    }
    
    func removeFriend(_ friend: Friend) {
        guard let userId = currentUserId, let friendId = friend.id else { return }
        
        db.collection("users").document(userId).collection("friends").document(friendId).delete { [weak self] error in
            if let error = error {
                print("友達削除エラー: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.friends.removeAll { $0.id == friend.id }
                }
            }
        }
    }
    
    func acceptFriendRequest(_ request: Friend) {
        guard let userId = currentUserId, let requestId = request.id else { return }
        print("🤝 友達申請を承認: 承認者=\(userId), 申請者=\(requestId)")
        
        // 1. 自分の友達に追加（Firebaseのみ、ローカル配列はスナップショットリスナーで自動更新）
        do {
            try db.collection("users").document(userId).collection("friends").document(requestId).setData(from: request)
            print("✅ 自分の友達リストに追加: \(request.name)")
        } catch {
            print("❌ 自分の友達追加エラー: \(error)")
            return
        }
        
        // 2. 現在のユーザー情報を取得して、申請者の友達リストにも追加
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let document = snapshot,
                  document.exists,
                  let data = document.data() else {
                print("現在のユーザー情報取得エラー: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // 申請者の友達リストに自分を追加
            let currentUserAsFriend = Friend(
                id: userId,
                name: data["name"] as? String ?? "Unknown",
                username: data["username"] as? String ?? "@unknown",
                avatarName: data["avatarName"] as? String ?? "person.circle.fill",
                profileImageURL: data["profileImageURL"] as? String,
                userId: userId
            )
            
            do {
                try self.db.collection("users").document(requestId).collection("friends").document(userId).setData(from: currentUserAsFriend)
                print("✅ 申請者の友達リストに追加完了: \(requestId)")
            } catch {
                print("申請者への友達追加エラー: \(error)")
            }
            
            // 申請者の送信済みリクエストからも削除
            self.db.collection("users").document(requestId).collection("sentRequests").document(userId).delete { error in
                if let error = error {
                    print("申請者の送信済みリクエスト削除エラー: \(error)")
                } else {
                    print("✅ 申請者の送信済みリクエスト削除完了")
                }
            }
        }
        
        // 3. 友達リクエストから削除
        db.collection("users").document(userId).collection("friendRequests").document(requestId).delete { [weak self] error in
            if let error = error {
                print("友達リクエスト削除エラー: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.friendRequests.removeAll { $0.id == request.id }
                }
            }
        }
    }
    
    func declineFriendRequest(_ request: Friend) {
        guard let userId = currentUserId, let requestId = request.id else { return }
        
        db.collection("users").document(userId).collection("friendRequests").document(requestId).delete { [weak self] error in
            if let error = error {
                print("友達リクエスト削除エラー: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.friendRequests.removeAll { $0.id == request.id }
                }
            }
        }
    }
    
    func sendFriendRequest(to user: Friend) {
        guard let userId = currentUserId, let targetUserId = user.id else { return }
        print("🔄 友達申請送信開始: \(userId) → \(targetUserId)")
        
        // 現在のユーザー情報をFirestoreから取得
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let document = snapshot,
                  document.exists,
                  let data = document.data() else {
                print("現在のユーザー情報取得エラー: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                // 送信済みリストに追加
                print("📤 送信済みリストに追加: user=\(userId), target=\(targetUserId)")
                try self.db.collection("users").document(userId).collection("sentRequests").document(targetUserId).setData(from: user)
                
                // 相手の友達リクエストに追加（正しいユーザー情報を使用）
                let senderFriend = Friend(
                    id: userId,
                    name: data["name"] as? String ?? "Unknown",
                    username: data["username"] as? String ?? "@unknown",
                    avatarName: data["avatarName"] as? String ?? "person.circle.fill",
                    profileImageURL: data["profileImageURL"] as? String,
                    userId: userId
                )
                
                print("📥 相手のリクエスト欄に追加: sender=\(userId), target=\(targetUserId)")
                try self.db.collection("users").document(targetUserId).collection("friendRequests").document(userId).setData(from: senderFriend)
                
                // ローカルの配列にも追加
                DispatchQueue.main.async {
                    if !self.sentRequests.contains(where: { $0.id == user.id }) {
                        self.sentRequests.append(user)
                    }
                }
            } catch {
                print("友達リクエスト送信エラー: \(error)")
            }
        }
    }
    
    func isFriend(_ user: Friend) -> Bool {
        return friends.contains { $0.id == user.id }
    }
    
    func filteredUsers(searchText: String) -> [Friend] {
        if searchText.isEmpty {
            return friends
        } else {
            return allUsers.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func resetUserData() {
        DispatchQueue.main.async {
            self.friends = []
            self.friendRequests = []
            self.sentRequests = []
            self.allUsers = []
            print("✅ FriendsManager データをリセットしました")
        }
    }
    
    func reloadUserData() {
        print("🔄 FriendsManager データを再読み込み中...")
        // まずデータをクリアしてから再読み込み
        DispatchQueue.main.async {
            self.friends = []
            self.friendRequests = []
            self.sentRequests = []
            self.allUsers = []
        }
        
        // 少し待ってから新しいデータを読み込み
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadFriends()
            self.loadFriendRequests()
            self.loadSentRequests()
            self.loadAllUsers()
        }
    }
}