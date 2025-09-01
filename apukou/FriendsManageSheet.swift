//
//  FriendsManageSheet.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI

// MARK: - 個別セル
struct FriendRow: View {
    let user: Friend
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(friend: user, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name).font(.headline)
                Text(user.username).font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("友達を削除する", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuActionDismissBehavior(.enabled)
            .menuOrder(.fixed)
        }
        .padding(.vertical, 4)
    }
}

struct RequestRow: View {
    let request: Friend
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(friend: request, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.name).font(.headline)
                Text(request.username).font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("承認") { onAccept() }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.blue).cornerRadius(15)
                    .buttonStyle(PlainButtonStyle())
                
                Button("削除") { onDecline() }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.red).cornerRadius(15)
                    .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - メインビュー
struct FriendsManageSheet: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var friendToDelete: Friend?
    @ObservedObject private var friendsManager = FriendsManager.shared
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6ƒ
    
    // 送信済みリクエストのIDセットを作成して検索を高速化
    private var sentRequestIds: Set<String> {
        Set(friendsManager.sentRequests.compactMap { $0.id })
    }
    
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [mainBlue,Color.white]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    // フィルタ済みユーザー
    private var filteredUsers: [Friend] {
        friendsManager.filteredUsers(searchText: searchText)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                List {
                    if searchText.isEmpty {
                        requestsSection
                        friendsSection
                    } else {
                        searchSection
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("友達")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "友達を検索、または申請")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { isPresented = false } label: {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.blue)
                    }
                }
            }
            .alert("友達を削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let friend = friendToDelete {
                        friendsManager.removeFriend(friend)
                        print("Deleted friend: \(friend.name)")
                    }
                }
            } message: {
                if let friend = friendToDelete {
                    Text("\(friend.name)を友達から削除しますか？")
                }
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - サブビュー（セクション）
    private var requestsSection: some View {
        Section {
            if friendsManager.friendRequests.isEmpty {
                Text("友達リクエストはありません")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            } else {
                ForEach(friendsManager.friendRequests) { request in
                    RequestRow(
                        request: request,
                        onAccept: {
                            friendsManager.acceptFriendRequest(request)
                            print("Accepted friend request from: \(request.name)")
                        },
                        onDecline: {
                            friendsManager.declineFriendRequest(request)
                            print("Declined friend request from: \(request.name)")
                        }
                    )
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                }
            }
        } header: {
            HStack {
                Text("友達リクエスト")
                Spacer()
                NavigationLink(destination: SentRequestsSheet(sentRequests: $friendsManager.sentRequests)) {
                    HStack(spacing: 4) {
                        Text("送信済み").font(.subheadline).foregroundColor(.blue)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var friendsSection: some View {
        Section {
            ForEach(friendsManager.friends) { user in
                FriendRow(user: user) {
                    friendToDelete = user
                    showingDeleteAlert = true
                }
            }
        } header: {
            Text("友達一覧")
        }
    }
    
    private var searchSection: some View {
        Section {
            ForEach(filteredUsers) { user in
            HStack(spacing: 12) {
                FriendAvatarView(friend: user, size: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name).font(.headline)
                    Text(user.username).font(.subheadline).foregroundColor(.secondary)
                }
                
                Spacer()
                
                if friendsManager.isFriend(user) {
                    Menu {
                        Button(role: .destructive) {
                            friendToDelete = user
                            showingDeleteAlert = true
                        } label: {
                            Label("友達を削除する", systemImage: "person.fill.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(.gray)
                    }
                } else if let userId = user.id, sentRequestIds.contains(userId) {
                    Text("申請中")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(darkPink).cornerRadius(20)
                } else {
                    Button {
                        friendsManager.sendFriendRequest(to: user)
                        print("Friend request sent to: \(user.name)")
                    } label: {
                        Text("申請")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(darkBlue).cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - 送信済みリクエスト画面
struct SentRequestsSheet: View {
    @Binding var sentRequests: [Friend]
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    private let darkPink = Color(red: 245/255, green: 114/255, blue: 182/255) //#F572B6
    
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [mainBlue,Color.white]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            List(sentRequests) { request in
            HStack(spacing: 12) {
                FriendAvatarView(friend: request, size: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.name).font(.headline)
                    Text(request.username).font(.subheadline).foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("申請中")
                    .font(.caption).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(darkPink)
                    .cornerRadius(20)
            }
            .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("送信済みリクエスト")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }
}

// MARK: - プレビュー
#Preview {
    FriendsManageSheet(isPresented: .constant(true))
}
