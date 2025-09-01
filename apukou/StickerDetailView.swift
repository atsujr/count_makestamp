//
//  StickerDetailView.swift
//  apukou
//
//  Created by yuka on 2025/07/14.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers



struct StickerDetailView: View {
    let stickerItem: StickerItem
    @State var showFriendList: Bool = false
    @State private var showingDeleteAlert = false
    @State private var showingEditor = false
    @State private var showShareSheet = false
    @State private var showingFriendSelection = false
    @State private var showingSendAlert = false
    @State private var sendResultMessage = ""
    @ObservedObject var dataManager: StickerDataManager
    @Environment(\.dismiss) private var dismiss
    //交換かどうか
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
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
            
            VStack(spacing: 30) {
            Spacer()
            
            //アイコン
            ZStack {
                if stickerItem.isObtained {
                    if let customImage = stickerItem.customImage {
                        // カスタム作成されたシール（ローカル）
                        let shape = StickerShape(rawValue: stickerItem.shape ?? "circle") ?? .circle
                        DetailShapedImageView(image: customImage, shape: shape)
                            .frame(width: 150, height: 150)
                    } else if let firebaseImageURL = stickerItem.firebaseImageURL {
                        // Firebaseからのシール
                        let shape = StickerShape(rawValue: stickerItem.shape ?? "circle") ?? .circle
                        AsyncImage(url: URL(string: firebaseImageURL)) { image in
                            DetailShapedImageView(image: UIImage(), shape: shape, asyncImage: image)
                                .frame(width: 150, height: 150)
                        } placeholder: {
                            ProgressView()
                                .frame(width: 150, height: 150)
                        }
                    } else {
                        // デフォルトシール
                        Image(systemName: "star.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.blue)
                    }
                } else {
                    // 未取得シール - 背景付きで表示
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 150, height: 150)
                        Image(systemName: "questionmark")
                            .font(.system(size: 54))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 180, height: 180) // 固定フレームサイズ
            
            //シール名のみ表示
            if let stickerName = stickerItem.stickerName, !stickerName.isEmpty {
                Text(stickerName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            
            //日付情報
            VStack(spacing: 16) {
                //作成日
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("作成日")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(stickerItem.createDate))
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                //交換日
                if stickerItem.isFromExchange, let exchangeDate = stickerItem.exchangeDate {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.secondary)
                        Text("交換日")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(exchangeDate))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // チャレンジ情報または交換相手の表示
            if let challengeTitle = stickerItem.challengeTitle {
                // チャレンジでもらったシール
                VStack(spacing: 12) {
                    Text("ゲット方法")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .center) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "figure.walk.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(challengeTitle)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("歩数チャレンジ達成")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else if stickerItem.isFromExchange {
                // 交換でもらったシール
                VStack(spacing:12) {
                    Text("交換相手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .center) {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: stickerItem.recipientAvatarName ?? "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(stickerItem.recipientName ?? "不明なユーザー")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("@\(stickerItem.recipientUsername ?? "unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            //交換ボタン
            Button {
                showingFriendSelection = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                    Text("交換する")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(darkPink)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        
        .navigationTitle(stickerItem.stickerName?.isEmpty == false ? stickerItem.stickerName! : "シール #\(stickerItem.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("編集する")
                        }
                    }
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("削除する")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .menuActionDismissBehavior(.enabled)
                .menuOrder(.fixed)
            }
        }
        
        .sheet(isPresented: $showingEditor) {
            StickerCreatorView(dataManager: dataManager, editingStickerItem: stickerItem)
        }
        .sheet(isPresented: $showingFriendSelection) {
            FriendSelectionSheet(
                isPresented: $showingFriendSelection,
                onFriendSelected: { friend in
                    sendStickerToFriend(friend)
                }
            )
        }
        .alert("シール送信", isPresented: $showingSendAlert) {
            Button("確認") { }
        } message: {
            Text(sendResultMessage)
        }
        .alert("シールを削除しますか？", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                dataManager.deleteSticker(stickerItem)
                dismiss()
            }
        } message: {
            Text("この操作は取り消せません")
        }
        }
    }
    
    
    //日付フォーマット関数
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    //シール画像作成関数
    private func createStickerImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 背景色
            UIColor.systemBlue.withAlphaComponent(0.1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // シール画像を描画
            if let customImage = stickerItem.customImage {
                customImage.draw(in: CGRect(origin: .zero, size: size))
            } else {
                // デフォルト画像
                UIColor.systemBlue.setFill()
                let circlePath = UIBezierPath(
                    arcCenter: CGPoint(x: size.width/2, y: size.height/2),
                    radius: 80,
                    startAngle: 0,
                    endAngle: .pi * 2,
                    clockwise: true
                )
                circlePath.fill()
            }
        }
    }
    
    //シール共有データ作成関数
    private func createStickerShareData() -> String {
        // シールのメタデータをBase64エンコードして含むカスタムURL
        let imageData = createStickerImage().jpegData(compressionQuality: 0.8) ?? Data()
        let imageBase64 = imageData.base64EncodedString()
        
        let stickerName = stickerItem.stickerName ?? "シール #\(stickerItem.id)"
        let shareURL = "apukou://sticker?name=\(stickerName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&image=\(imageBase64)"
        
        return shareURL
    }
    
    
    struct DetailShapedImageView: View {
        let image: UIImage
        let shape: StickerShape
        let asyncImage: Image?
        
        init(image: UIImage, shape: StickerShape) {
            self.image = image
            self.shape = shape
            self.asyncImage = nil
        }
        
        init(image: UIImage, shape: StickerShape, asyncImage: Image?) {
            self.image = image
            self.shape = shape
            self.asyncImage = asyncImage
        }
        
        var body: some View {
            Group {
                if let asyncImage = asyncImage {
                    asyncImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .clipShape(shapeClipPath)
        }
        
        private var shapeClipPath: AnyShape {
            switch shape {
            case .circle:
                return AnyShape(Circle())
            case .square:
                return AnyShape(Rectangle())
            case .triangle:
                return AnyShape(TriangleShape())
            case .star:
                return AnyShape(StarShape())
            case .heart:
                return AnyShape(HeartShape())
            case .original:
                return AnyShape(Rectangle())
            }
        }
    }
    
    private func sendStickerToFriend(_ friend: Friend) {
        let stickerImage = createStickerImage()
        
        // 1. 相手にシールを送信（完全なシール情報を含む）
        dataManager.sendStickerToFriend(
            sticker: stickerItem,
            image: stickerImage,
            friend: friend
        )
        
        // 2. 自分のシールを削除
        dataManager.deleteSticker(stickerItem)
        
        sendResultMessage = "\(friend.name)さんにシールを送信しました！"
        showingSendAlert = true
        dismiss() // シールが削除されたのでDetailViewを閉じる
        print("✅ シールを送信しました: 送信先=\(friend.name)")
    }
    
    
}

// 友達選択シート
struct FriendSelectionSheet: View {
    @Binding var isPresented: Bool
    let onFriendSelected: (Friend) -> Void
    @ObservedObject private var friendsManager = FriendsManager.shared
    
    private let mainBlue = Color(red: 162/255, green: 242/255, blue: 251/255) //#A2F2FB
    private let darkBlue = Color(red: 37/255, green: 162/255, blue: 220/255) //#25A2DC
    
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [mainBlue, Color.white]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                List {
                    Section {
                        if friendsManager.friends.isEmpty {
                            Text("友達がいません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(friendsManager.friends) { friend in
                                Button {
                                    onFriendSelected(friend)
                                    isPresented = false
                                } label: {
                                    HStack(spacing: 12) {
                                        FriendAvatarView(friend: friend, size: 40)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(friend.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(friend.username)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("送る")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue)
                                            .cornerRadius(15)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } header: {
                        Text("シールを送る友達を選択")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("友達選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

extension UIImage: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            return image.pngData() ?? Data()
        }
    }
}
