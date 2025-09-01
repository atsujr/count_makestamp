//
//  UserProfileView.swift
//  apukou
//
//  Created by Claude on 2025/08/08.
//

import SwiftUI

// シール帳のデータ構造
struct StickerNotebook: Identifiable {
    let id: Int
    let title: String
    let stickerCount: Int
    let coverColor: Color
}

struct UserProfileView: View {
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var dataManager = StickerDataManager.shared
    @ObservedObject private var friendsManager = FriendsManager.shared
    @State private var showingFriendList = false
    @State private var showingOther = false
    
    private let mainPink = Color(red: 255/255, green: 202/255, blue: 227/255) //#FFCAE3
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let darkPurple = Color(red: 211/255, green: 123/255, blue: 255/255)//#D37BFF
    
    private var profileBackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [mainPink, mainBlue]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                profileBackgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Avatar
                            if let profileImageURL = userManager.currentUser?.profileImageURL,
                               !profileImageURL.isEmpty {
                                AsyncImage(url: URL(string: profileImageURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                                             
                                } placeholder: {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 100))
                                        .foregroundColor(.blue.opacity(0.7))
                                        .frame(width: 120, height: 120)
                                }
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 100))
                                    .foregroundColor(.blue.opacity(0.7))
                                    .frame(width: 120, height: 120)
                            }
                            
                            VStack(spacing: 8) {
                                Text(userManager.currentUser?.name ?? "ユーザー名")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    
                                    
                                
                                Text("@\(userManager.currentUser?.username ?? "username")")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                if let bio = userManager.currentUser?.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 4)
                                }
                            }
                            
                            // 統計情報
                            HStack(spacing: 32) {
                                Button {
                                    showingFriendList = true
                                } label: {
                                    StatView(
                                        title: "友達",
                                        value: "\(friendsManager.friends.count)"
                                    )
                                }
                                StatView(
                                    title: "シール",
                                    value: "\(dataManager.stickers.count)"
                                )
                                StatView(
                                    title: "レベル",
                                    value: "\(calculateLevel())"
                                )
                            }
                            .padding(.top, 10)
                        }
                        .padding(.top, 10)
                        
                        // 私のシール帳一覧
                        VStack(alignment: .leading, spacing: 16) {
                            
//                            Rectangle()
//                                .fill(Color.white.opacity(0.8))
//                                .frame(height: 2)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                                ForEach(getStickerNotebooks(), id: \.id) { notebook in
                                    StickerNotebookCoverView(notebook: notebook)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 12)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                // ナビゲーションバーを透明にする
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFriendList = true
                    } label: {
                        Image(systemName: "person.fill.badge.plus")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingOther = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationDestination(isPresented: $showingOther) {
                SettingView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showingOther = false
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width > 100 && abs(value.translation.height) < 50 {
                                    showingOther = false
                                }
                            }
                    )
            }
            .sheet(isPresented: $showingFriendList) {
                FriendsManageSheet(isPresented: $showingFriendList)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func calculateLevel() -> Int {
        // 達成チャレンジ数でレベルを計算
        let challengeManager = ChallengeManager.shared
        let completedChallenges = challengeManager.getTotalCompletedChallenges()
        return max(1, completedChallenges + 1) // 最低レベル1、チャレンジ達成数+1
    }
    
    private func getStickerNotebooks() -> [StickerNotebook] {
        // 仮データ：実際の実装では複数のシール帳を管理
        return [
            StickerNotebook(id: 1, title: "メインコレクション", stickerCount: dataManager.stickers.count, coverColor: .blue),
            StickerNotebook(id: 2, title: "チャレンジ記録", stickerCount: 0, coverColor: .orange),
            StickerNotebook(id: 3, title: "友達との思い出", stickerCount: 0, coverColor: .green)
        ]
    }
    
    
    struct StatView: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(spacing: 8) {
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            }
            .frame(minWidth: 60)
        }
    }
    
    struct ProfileInfoRow: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
}

// シール帳の表紙ビュー
struct StickerNotebookCoverView: View {
    let notebook: StickerNotebook
    
    var body: some View {
        VStack(spacing: 8) {
            // 表紙
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [notebook.coverColor, notebook.coverColor.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(maxWidth: 130)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                
            }
            
            // タイトルとシール数
            VStack(spacing: 4) {
                Text("\(notebook.title) #\(notebook.id)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(notebook.stickerCount)枚")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    UserProfileView()
}
