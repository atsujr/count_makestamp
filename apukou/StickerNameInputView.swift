//
//  StickerNameInputView.swift
//  apukou
//
//  Created by Claude on 2025/08/09.
//

import SwiftUI
import PencilKit

struct StickerNameInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    let finalImage: UIImage
    let dataManager: StickerDataManager
    let editingStickerItem: StickerItem?
    let selectedShape: StickerShape
    let textElementsData: [TextElementData]?
    let drawingData: Data?
    let imageScale: CGFloat
    let imageTranslation: CGSize
    let onSaveComplete: () -> Void
    
    @State private var stickerName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // プレビュー画像（すべて合成済み）
                Image(uiImage: finalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .clipShape(shapeClipPath)
                    .shadow(radius: 8)
                
                
                // 名前入力フィールド
                VStack(alignment: .leading, spacing: 12) {
                    Text("シールに名前を付ける（任意）")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("シール名を入力...", text: $stickerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .submitLabel(.done)
                    
                    Text("名前を付けない場合はそのまま保存してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 保存ボタン
                Button(action: {
                    saveSticker()
                }) {
                    Text("保存")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationTitle("シール名")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func saveSticker() {
        let finalStickerName = stickerName.isEmpty ? nil : stickerName
        
        // Add to sticker collection or update existing sticker
        if let editingSticker = editingStickerItem {
            // Update existing sticker
            print("🔄 Editing existing sticker with ID: \(editingSticker.id)")
            dataManager.updateSticker(
                editingSticker,
                newImage: finalImage,
                drawingData: drawingData,
                textElements: textElementsData,
                shape: selectedShape.rawValue,
                stickerName: finalStickerName,
                imageScale: imageScale,
                imageTranslation: imageTranslation
            )
            
            // Call completion callback and dismiss
            onSaveComplete()
            dismiss()
        } else {
            // Add new sticker 
            let nextEmptySlotIndex = dataManager.stickerSlots.firstIndex(where: { $0 == nil })
            let hasEmptyInitialSlots = nextEmptySlotIndex != nil && nextEmptySlotIndex! < 10
            
            if hasEmptyInitialSlots {
                // 初期10個の空きスロットがある場合は無条件で作成
                print("➕ Creating new sticker in slot \(nextEmptySlotIndex!) (initial slots)")
                dataManager.addCreatedSticker(
                    image: finalImage,
                    drawingData: drawingData,
                    textElements: textElementsData,
                    shape: selectedShape.rawValue,
                    stickerName: finalStickerName,
                    imageScale: imageScale,
                    imageTranslation: imageTranslation,
                    isInitialSlot: true
                )
                
                onSaveComplete()
                dismiss()
            } else if dataManager.canCreateNewSticker() {
                // 初期10個を使い切った後は制限チェック
                print("➕ Creating new sticker (post-initial, checking restrictions)")
                dataManager.addCreatedSticker(
                    image: finalImage,
                    drawingData: drawingData,
                    textElements: textElementsData,
                    shape: selectedShape.rawValue,
                    stickerName: finalStickerName,
                    imageScale: imageScale,
                    imageTranslation: imageTranslation,
                    isInitialSlot: false
                )
                
                onSaveComplete()
                dismiss()
            } else {
                print("❌ 作成制限に達しています")
                dismiss()
            }
        }
    }
    
    private var shapeClipPath: some Shape {
        switch selectedShape {
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
