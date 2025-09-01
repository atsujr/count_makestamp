//
//  StickerItemView.swift
//  apukou
//
//  Created by yuka on 2025/07/13.
//

import SwiftUI



struct StickerButtonView: View {
    let stickerItem: StickerItem
    
    var body: some View {
        VStack(spacing: 4) {
            // 固定サイズフレーム内にシールを配置
            ZStack {
                if stickerItem.isObtained {
                    if let customImage = stickerItem.customImage {
                        // カスタム作成されたシール（ローカル）
                        let shape = StickerShape(rawValue: stickerItem.shape ?? "circle") ?? .circle
                        SmallShapedImageView(image: customImage, shape: shape)
                            .frame(width: 60, height: 60)
                    } else if let firebaseImageURL = stickerItem.firebaseImageURL {
                        // Firebaseからのシール
                        let shape = StickerShape(rawValue: stickerItem.shape ?? "circle") ?? .circle
                        AsyncImage(url: URL(string: firebaseImageURL)) { image in
                            SmallShapedImageView(image: UIImage(), shape: shape, asyncImage: image)
                                .frame(width: 60, height: 60)
                        } placeholder: {
                            ProgressView()
                                .frame(width: 60, height: 60)
                        }
                    } else {
                        // デフォルトシール
                        Image(systemName: "star.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                } else {
                    // 未取得シール - 背景付きで表示
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                        Image(systemName: "questionmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 80, height: 80) // 固定フレームサイズで間隔統一
            
            // シール名表示エリア（常に一定の高さを確保）
            Text(stickerItem.stickerName?.isEmpty == false ? stickerItem.stickerName! : "シール #\(stickerItem.id)")
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(height: 30) // 固定高さで統一
        }
        
        .buttonStyle(PlainButtonStyle())
        
    }
}

struct SmallShapedImageView: View {
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

    
    
