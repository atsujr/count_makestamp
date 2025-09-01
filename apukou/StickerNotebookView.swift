//
//  StickerNotebookView.swift
//  apukou
//
//  Created by Claude on 2025/08/28.
//

import SwiftUI

struct StickerNotebookView: View {
    @StateObject private var dataManager = StickerDataManager.shared
    @State private var currentPageIndex = 0
    @State private var showingStickerCreator = false
    @State private var selectedStickerIndex: Int? = nil
    @State private var animateGradient = false
    @State private var creationChances = 0
    
    private let stickersPerPage = 6
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    
    // カラーパレット
    private let lightBlue = Color(red: 162/255, green: 242/255, blue: 251/255)
    private let lightPink = Color(red: 255/255, green: 202/255, blue: 227/255)
    private let lightPurple = Color(red: 221/255, green: 191/255, blue: 255/255)
    
    // MeshGradient背景
    private var meshGradientBackground: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                
                RadialGradient(
                    colors: [lightBlue.opacity(0.6), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.3 : 0.2, y: animateGradient ? 0.2 : 0.1),
                    startRadius: 0,
                    endRadius: geometry.size.width * (animateGradient ? 0.7 : 0.6)
                )
                
                RadialGradient(
                    colors: [lightPink.opacity(0.5), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.7 : 0.8, y: animateGradient ? 0.3 : 0.2),
                    startRadius: 0,
                    endRadius: geometry.size.width * (animateGradient ? 0.6 : 0.5)
                )
                
                RadialGradient(
                    colors: [lightPurple.opacity(0.4), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.2 : 0.1, y: animateGradient ? 0.5 : 0.6),
                    startRadius: 0,
                    endRadius: geometry.size.height * (animateGradient ? 0.5 : 0.4)
                )
                
                RadialGradient(
                    colors: [lightBlue.opacity(0.3), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.8 : 0.7, y: animateGradient ? 0.6 : 0.7),
                    startRadius: 0,
                    endRadius: geometry.size.width * (animateGradient ? 0.5 : 0.45)
                )
                
                RadialGradient(
                    colors: [lightPink.opacity(0.4), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.4 : 0.5, y: animateGradient ? 0.5 : 0.4),
                    startRadius: 0,
                    endRadius: min(geometry.size.width, geometry.size.height) * (animateGradient ? 0.4 : 0.35)
                )
                
                RadialGradient(
                    colors: [lightPurple.opacity(0.3), Color.clear],
                    center: UnitPoint(x: animateGradient ? 0.8 : 0.9, y: animateGradient ? 0.8 : 0.9),
                    startRadius: 0,
                    endRadius: geometry.size.height * (animateGradient ? 0.35 : 0.3)
                )
            }
            .blendMode(.multiply)
//            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animateGradient)
        }
        .ignoresSafeArea()
    }
    
    // ノートページの背景グラデーション
    private var notePageBackground: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white,
                Color(red: 250/255, green: 248/255, blue: 243/255)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var totalPages: Int {
        // 実際のシール数に基づいてページ数を計算
        let totalStickerCount = dataManager.stickers.count
        // 最低2ページ（10スロット）は保証し、シールが追加されれば自動でページ増加
        let minimumPages = 2
        let calculatedPages = Int(ceil(Double(totalStickerCount) / Double(stickersPerPage)))
        return max(minimumPages, calculatedPages)
    }
    
    private var currentPageStickers: [StickerItem] {
        let sortedStickers = dataManager.stickers.sorted { $0.createDate > $1.createDate }
        let startIndex = currentPageIndex * stickersPerPage
        let endIndex = min(startIndex + stickersPerPage, sortedStickers.count)
        
        if startIndex < sortedStickers.count {
            return Array(sortedStickers[startIndex..<endIndex])
        }
        return []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ノートのヘッダー
                notebookHeader
                
                // ページ表示エリア
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<totalPages, id: \.self) { pageIndex in
                        notePage(for: pageIndex)
                            .tag(pageIndex)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // ページナビゲーション
                pageNavigation
            }
            .background(meshGradientBackground)
            .navigationTitle("シールノート")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedStickerIndex) { index in
                if index < 10, let stickerItem = dataManager.stickerSlots[index] {
                    // スロット内のシール（0-9）
                    StickerDetailView(stickerItem: stickerItem, dataManager: dataManager)
                } else if let stickerItem = dataManager.stickers.first(where: { $0.id == index }) {
                    // 11個目以降のシール
                    StickerDetailView(stickerItem: stickerItem, dataManager: dataManager)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(creationChances)/5")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if dataManager.canCreateNewSticker() {
                            showingStickerCreator = true
                        }
                    }) {
                        Image(systemName: "hand.rays")
                            .foregroundColor(dataManager.canCreateTodaysSticker ? .primary : .primary.opacity(0.3))
                    }
                }
            }
            .sheet(isPresented: $showingStickerCreator) {
                StickerCreatorView(dataManager: dataManager, editingStickerItem: nil)
            }
            .onAppear {
                // アプリ再開時に制限状態をチェック
                _ = dataManager.canCreateNewSticker()
                // アニメーション開始（軽量化のため無効化）
                // animateGradient = true
                creationChances = dataManager.getAvailableCreationChances()
            }
            .onReceive(dataManager.$availableCreationChances) { newValue in
                creationChances = newValue
            }
            .preferredColorScheme(.light)
        }
    }
    
    // ノートブックのヘッダー
    private var notebookHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Sticker Notebook")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("シール総数: \(dataManager.stickers.count)枚")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // ページインジケーター
            Text("\(currentPageIndex + 1) / \(totalPages)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.8))
                .cornerRadius(16)
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.9))
    }
    
    // 個別のノートページ
    private func notePage(for pageIndex: Int) -> some View {
        let sortedStickers = dataManager.stickers.sorted { $0.createDate > $1.createDate }
        let startIndex = pageIndex * stickersPerPage
        let endIndex = min(startIndex + stickersPerPage, sortedStickers.count)
        let pageStickers = startIndex < sortedStickers.count ? 
            Array(sortedStickers[startIndex..<endIndex]) : []
        
        return VStack(spacing: 0) {
            // ノートページの見た目（線や穴など）
            ZStack {
                // ページ背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(notePageBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 2, y: 4)
                
                // ノートの線
                VStack(spacing: 30) {
                    ForEach(0..<6, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 40)
                
                // ノートの穴（左端）
                HStack {
                    VStack(spacing: 60) {
                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                }
                
                // シールのグリッド表示（常に6枚分のグリッドを維持）
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(0..<stickersPerPage, id: \.self) { slotIndex in
                        let globalIndex = pageIndex * stickersPerPage + slotIndex
                        
                        if slotIndex < pageStickers.count {
                            // 実際のシールがある場合
                            StickerPageView(stickerItem: pageStickers[slotIndex])
                                .onTapGesture {
                                    selectedStickerIndex = pageStickers[slotIndex].id
                                }
                        } else if globalIndex < 10 {
                            // 最初の10スロットで空きがある場合は作成機能付き
                            CreateStickerSlot(dataManager: dataManager, showingStickerCreator: $showingStickerCreator, isInitialSlot: true)
                        } else {
                            // 11個目以降のページでは通常の作成スロットを表示
                            CreateStickerSlot(dataManager: dataManager, showingStickerCreator: $showingStickerCreator, isInitialSlot: false)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    // ページナビゲーション
    private var pageNavigation: some View {
        HStack(spacing: 24) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPageIndex > 0 {
                        currentPageIndex -= 1
                    }
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("前のページ")
                        .font(.subheadline)
                }
                .foregroundColor(currentPageIndex > 0 ? .blue : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.8))
                .cornerRadius(20)
            }
            .disabled(currentPageIndex <= 0)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPageIndex < totalPages - 1 {
                        currentPageIndex += 1
                    }
                }
            }) {
                HStack {
                    Text("次のページ")
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(currentPageIndex < totalPages - 1 ? .blue : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.8))
                .cornerRadius(20)
            }
            .disabled(currentPageIndex >= totalPages - 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// ページ上のシール表示
struct StickerPageView: View {
    let stickerItem: StickerItem
    @State private var showingStickerCreator = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // シール本体
                if let customImage = stickerItem.customImage {
                    let shape = StickerShape(rawValue: stickerItem.shape ?? "circle") ?? .circle
                    NotebookShapedImageView(image: customImage, shape: shape)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 2)
                } else {
                    Button(action: {
                        showingStickerCreator = true
                    }) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.pink.opacity(0.6), Color.blue.opacity(0.6)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // シール名表示
            Group {
                if let customImage = stickerItem.customImage {
                    // 画像がある場合は名前表示
                    Text(stickerItem.stickerName?.isEmpty == false ? stickerItem.stickerName! : "シール #\(stickerItem.id)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 80)
                } else {
                    // 画像がない場合は「新規作成」
                    Text("新規作成")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 80)
                }
            }
        }
        .sheet(isPresented: $showingStickerCreator) {
            StickerCreatorView(dataManager: StickerDataManager.shared, editingStickerItem: nil)
        }
    }
}

// シール作成スロット（プラスボタン）
struct CreateStickerSlot: View {
    let dataManager: StickerDataManager
    @Binding var showingStickerCreator: Bool
    let isInitialSlot: Bool // 最初の10個かどうか
    
    var body: some View {
        Button(action: {
            if isInitialSlot || dataManager.canCreateNewSticker() {
                showingStickerCreator = true
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // シールの影
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 82, height: 82)
                        .offset(x: 2, y: 2)
                    
                    // メインボタン - lightPink~lightBlueグラデーション
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.pink.opacity(0.6), Color.blue.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Group {
                                if isInitialSlot || dataManager.availableCreationChances > 0 {
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                } else {
                                    VStack(spacing: 2) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        Text("0")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        )
                }
                
                Text("新規作成")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ノートブック用の形状付き画像ビュー
struct NotebookShapedImageView: View {
    let image: UIImage
    let shape: StickerShape
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipShape(shapeClipPath)
            .overlay(
                shapeClipPath
                    .stroke(Color.white, lineWidth: 2)
            )
    }
    
    private var shapeClipPath: AnyShape {
        switch shape {
        case .circle:
            return AnyShape(Circle())
        case .square:
            return AnyShape(RoundedRectangle(cornerRadius: 8))
        case .triangle:
            return AnyShape(TriangleShape())
        case .star:
            return AnyShape(StarShape())
        case .heart:
            return AnyShape(HeartShape())
        case .original:
            return AnyShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    StickerNotebookView()
}
