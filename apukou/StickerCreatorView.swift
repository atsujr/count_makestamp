//
//  StickerCreatorView.swift
//  apukou
//
//  Created by Claude on 2025/08/01.
//

import SwiftUI
import PhotosUI
import PencilKit

enum StickerShape: String, CaseIterable {
    case circle = "circle"
    case square = "square"
    case triangle = "triangle"
    case star = "star"
    case heart = "heart"
    case original = "original"
    
    var displayName: String {
        switch self {
        case .circle: return "丸"
        case .square: return "四角"
        case .triangle: return "三角"
        case .star: return "星"
        case .heart: return "ハート"
        case .original: return "元の形"
        }
    }
    
    var systemImage: String {
        switch self {
        case .circle: return "circle.fill"
        case .square: return "square.fill"
        case .triangle: return "triangle.fill"
        case .star: return "star.fill"
        case .heart: return "heart.fill"
        case .original: return "photo"
        }
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let centerX = rect.midX
        let centerY = rect.midY
        let halfSize = size / 2
        
        path.move(to: CGPoint(x: centerX, y: centerY - halfSize))
        path.addLine(to: CGPoint(x: centerX - halfSize, y: centerY + halfSize))
        path.addLine(to: CGPoint(x: centerX + halfSize, y: centerY + halfSize))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = size / 2
        let innerRadius = outerRadius * 0.4
        
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5 - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let size = min(rect.width, rect.height)
        let centerX = rect.midX
        let centerY = rect.midY
        let scale = size * 0.5
        
        // ハートの底部（先端）
        path.move(to: CGPoint(x: centerX, y: centerY + scale * 0.8))
        
        // 左側のカーブ
        path.addCurve(
            to: CGPoint(x: centerX - scale * 0.7, y: centerY - scale * 0.1),
            control1: CGPoint(x: centerX - scale * 0.3, y: centerY + scale * 0.3),
            control2: CGPoint(x: centerX - scale * 0.7, y: centerY + scale * 0.2)
        )
        
        // 左上の丸い部分
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY - scale * 0.5),
            control1: CGPoint(x: centerX - scale * 0.7, y: centerY - scale * 0.5),
            control2: CGPoint(x: centerX - scale * 0.3, y: centerY - scale * 0.7)
        )
        
        // 右上の丸い部分
        path.addCurve(
            to: CGPoint(x: centerX + scale * 0.7, y: centerY - scale * 0.1),
            control1: CGPoint(x: centerX + scale * 0.3, y: centerY - scale * 0.7),
            control2: CGPoint(x: centerX + scale * 0.7, y: centerY - scale * 0.5)
        )
        
        // 右側のカーブ（底部へ戻る）
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY + scale * 0.8),
            control1: CGPoint(x: centerX + scale * 0.7, y: centerY + scale * 0.2),
            control2: CGPoint(x: centerX + scale * 0.3, y: centerY + scale * 0.3)
        )
        
        path.closeSubpath()
        return path
    }
}

struct SquareShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let centerX = rect.midX
        let centerY = rect.midY
        let halfSize = size / 2
        
        let squareRect = CGRect(
            x: centerX - halfSize,
            y: centerY - halfSize,
            width: size,
            height: size
        )
        
        path.addRect(squareRect)
        return path
    }
}

struct StickerCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    let dataManager: StickerDataManager
    let editingStickerItem: StickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var currentTool: CreatorTool = .none
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var textElements: [TextElement] = []
    @State private var showingTextEditor = false
    @State private var selectedShape: StickerShape = .circle
    @State private var imageOffset: CGSize = .zero
    @State private var stickerName: String = ""
    @State private var showingNameInput = false
    @State private var finalImage: UIImage?
    @State private var isImageEditingMode = true
    @State private var imageScale: CGFloat = 1.0
    @State private var imageTranslation: CGSize = .zero
    @State private var isLoadingExistingData = false
    
    // Use Environment UndoManager
    @Environment(\.undoManager) private var undoManager
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var undoHistory: [PKStroke] = []
    
    enum UndoAction {
        case imageChange(UIImage?)
        case textAdded(TextElement)
        case textRemoved(TextElement, Int)
        case drawingChanged(Data?)
        case canvasCleared(Data?)
    }
    
    enum CreatorTool: CaseIterable {
        case none, pen, text
        
        var icon: String {
            switch self {
            case .none: return "hand.tap"
            case .pen: return "pencil"
            case .text: return "textformat"
            }
        }
        
        var title: String {
            switch self {
            case .none: return "選択"
            case .pen: return "ペン"
            case .text: return "テキスト"
            }
        }
    }
    
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 162/255, green: 242/255, blue: 251/255),
                Color.white
            ]),
            center: .center,
            startRadius: 50,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                VStack(spacing: 0) {
                    // Safe area for toolbar
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60)
                    
                    // Canvas area
                    ZStack {
                        // Background
                        Rectangle()
                            .fill(Color.white)
                            .border(Color.gray.opacity(0.3))
                        
                        // Base image with shape - 最大サイズを制限
                        if let image = selectedImage {
                            if isImageEditingMode {
                                EditableShapedImageView(
                                    image: image,
                                    shape: selectedShape,
                                    scale: $imageScale,
                                    translation: $imageTranslation,
                                    onShapeChange: { cycleToNextShape() }
                                )
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 400, maxHeight: 400)
                            } else {
                                ShapedImageView(image: image, shape: selectedShape, scale: imageScale, translation: imageTranslation)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 400, maxHeight: 400)
                            }
                        }
                        
                        // PencilKit Canvas - only in drawing mode
                        if !isImageEditingMode {
                            PencilKitCanvasView(
                                canvasView: $canvasView,
                                toolPicker: $toolPicker,
                                isDrawingEnabled: currentTool == .pen,
                                onNewDrawingStarted: {
                                    clearHistory()
                                    updateUndoState()
                                },
                                onDrawingChanged: {
                                    updateUndoState()
                                }
                            )
                            
                            // Text elements - only in drawing mode
                            ForEach(textElements.indices, id: \.self) { index in
                                DraggableTextView(
                                    textElement: $textElements[index],
                                    isSelected: currentTool == .text,
                                    onDelete: {
                                        removeTextElement(at: index)
                                    },
                                    onTextChanged: {
                                        updateUndoState()
                                    }
                                )
                            }
                        }
                    }
                    .frame(height: 400)
                    .clipped()
                    
                    // Image picker
                    if selectedImage == nil {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(red: 245/255, green: 114/255, blue: 182/255))
                                Text("写真を選択")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 245/255, green: 114/255, blue: 182/255))
                               
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding()
                        }
                    } else if isImageEditingMode {
                        // Image editing mode instructions
                        VStack(spacing: 8) {
                            Text("現在の形状: \(selectedShape.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            VStack(spacing: 4) {
                                Text("タップ: 形を変更")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("ピンチ: 拡大縮小")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("ドラッグ: 画像位置を調整")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 12) {
                                // 画像再選択ボタン
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text("画像変更")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Button("完了") {
                                    isImageEditingMode = false
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 80, height: 40)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    } else {
                        // Drawing mode - shape selection button
                        VStack(spacing: 8) {
                            Text("現在の形状: \(selectedShape.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Button("形状を変更") {
                                    isImageEditingMode = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                
                                // 画像再選択ボタン
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text("画像変更")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Tool selection - only in drawing mode
                    if !isImageEditingMode {
                        HStack(spacing: 20) {
                            ForEach(CreatorTool.allCases, id: \.self) { tool in
                                if tool != .none || selectedImage != nil {
                                    ToolButton(
                                        tool: tool,
                                        isSelected: currentTool == tool,
                                        action: { selectTool(tool) }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // PencilKit Tool Picker
                    if selectedImage != nil && currentTool == .pen {
                        Text("ペンツールを選択中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                // Top toolbar - always on top
                VStack {
                    HStack {
                        HStack(spacing: 16) {
                            Button("キャンセル") {
                                dismiss()
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            
                            HStack(spacing: 8) {
                                Button {
                                    performUndo()
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                .disabled(!canUndo)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                                
                                Button {
                                    performRedo()
                                } label: {
                                    Image(systemName: "arrow.uturn.forward")
                                }
                                .disabled(!canRedo)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                        
                        Button("次へ") {
                            prepareForNaming()
                        }
                        .disabled(selectedImage == nil)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedImage == nil ? Color.gray : Color.blue)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.clear)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showingNameInput) {
                if let finalImage = finalImage {
                    StickerNameInputView(
                        finalImage: finalImage,
                        dataManager: dataManager,
                        editingStickerItem: editingStickerItem,
                        selectedShape: selectedShape,
                        textElementsData: convertTextElementsToData(),
                        drawingData: getDrawingData(),
                        imageScale: imageScale,
                        imageTranslation: imageTranslation,
                        onSaveComplete: {
                            // When save is complete, dismiss the CreatorView as well
                            dismiss()
                        }
                    )
                }
            }
            .onAppear {
                if let editingSticker = editingStickerItem {
                    loadExistingStickerData(editingSticker)
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    // 既存データ読み込み中は処理をスキップ
                    if isLoadingExistingData { return }
                    
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        // 編集モードでない場合のみ状態をリセット
                        selectedImage = image
                        imageOffset = .zero
                        
                        if editingStickerItem == nil {
                            // 新規作成時のみリセット
                            imageScale = 1.0
                            imageTranslation = .zero
                            isImageEditingMode = true
                            
                            // 描画とテキストもリセット
                            canvasView.drawing = PKDrawing()
                            textElements = []
                            
                            // ツールをリセット
                            currentTool = .none
                            toolPicker.setVisible(false, forFirstResponder: canvasView)
                        } else {
                            // 編集時は画像編集モードに戻るのみ
                            isImageEditingMode = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTextEditor) {
                TextEditorSheet { text, color in
                    addTextElement(text, color: color)
                }
            }
            .preferredColorScheme(.light)
        }
    }
    
    private func selectTool(_ tool: CreatorTool) {
        currentTool = tool
        
        switch tool {
        case .pen:
            // Show tool picker when pen is selected
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        case .text:
            showingTextEditor = true
        case .none:
            // Hide tool picker when not using pen
            toolPicker.setVisible(false, forFirstResponder: canvasView)
        }
    }
    
    private func addTextElement(_ text: String, color: Color) {
        // キャンバスの中央に配置（400x400の中央）
        let newElement = TextElement(
            id: UUID(),
            text: text,
            position: CGPoint(x: 200, y: 200),
            color: color,
            fontSize: 24,
            rotation: 0
        )
        
        textElements.append(newElement)
    }
    
    private func removeTextElement(at index: Int) {
        guard index < textElements.count else { return }
        
        textElements.remove(at: index)
    }
    
    private func prepareForNaming() {
        guard let baseImage = selectedImage else { return }
        
        finalImage = generateFinalImage(baseImage: baseImage)
        showingNameInput = true
    }
    
    private func generateFinalImage(baseImage: UIImage) -> UIImage {
        // 最終出力サイズは1024x1024に統一
        let outputSize = CGSize(width: 1024, height: 1024)
        
        // Create a new image with all the drawings and text
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景を白で塗りつぶし
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: outputSize))
            
            // 画像を出力サイズ全体に配置し、ユーザーが調整したスケールと位置を適用
            cgContext.saveGState()
            
            // ユーザーの画像変形を適用（中心を基準に）
            let centerX = outputSize.width / 2
            let centerY = outputSize.height / 2
            cgContext.translateBy(x: centerX, y: centerY)
            cgContext.scaleBy(x: imageScale, y: imageScale)
            cgContext.translateBy(x: imageTranslation.width * (outputSize.width / 400), y: imageTranslation.height * (outputSize.height / 400))
            cgContext.translateBy(x: -centerX, y: -centerY)
            
            // 画像をaspectFillで出力サイズ全体に描画
            let imageAspectRatio = baseImage.size.width / baseImage.size.height
            let outputAspectRatio = outputSize.width / outputSize.height
            
            var drawRect: CGRect
            if imageAspectRatio > outputAspectRatio {
                // 画像の方が横長：高さを基準にして幅をトリミング
                let scaledHeight = outputSize.height
                let scaledWidth = scaledHeight * imageAspectRatio
                let xOffset = (outputSize.width - scaledWidth) / 2
                drawRect = CGRect(x: xOffset, y: 0, width: scaledWidth, height: scaledHeight)
            } else {
                // 画像の方が縦長または同じ：幅を基準にして高さをトリミング
                let scaledWidth = outputSize.width
                let scaledHeight = scaledWidth / imageAspectRatio
                let yOffset = (outputSize.height - scaledHeight) / 2
                drawRect = CGRect(x: 0, y: yOffset, width: scaledWidth, height: scaledHeight)
            }
            
            // ベース画像を描画
            baseImage.draw(in: drawRect)
            cgContext.restoreGState()
            
            // PencilKit描画を描画
            if !canvasView.drawing.bounds.isEmpty {
                let drawingImage = canvasView.drawing.image(from: canvasView.drawing.bounds, scale: 1.0)
                
                cgContext.saveGState()
                
                // キャンバス座標系(400x400)から出力座標系(1024x1024)への変換
                let scaleX = outputSize.width / 400
                let scaleY = outputSize.height / 400
                cgContext.scaleBy(x: scaleX, y: scaleY)
                
                // 画像の変形（スケール・移動）を描画にも適用
                cgContext.scaleBy(x: imageScale, y: imageScale)
                cgContext.translateBy(x: imageTranslation.width, y: imageTranslation.height)
                
                drawingImage.draw(at: .zero)
                cgContext.restoreGState()
            }
            
            // テキスト要素を描画
            for textElement in textElements {
                let scaleX = outputSize.width / 400
                let scaleY = outputSize.height / 400
                let scaledFontSize = textElement.fontSize * min(scaleX, scaleY)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: scaledFontSize),
                    .foregroundColor: UIColor(textElement.color)
                ]
                
                let size = textElement.text.size(withAttributes: attributes)
                
                // 回転とスケールを適用（画像の変形も考慮）
                cgContext.saveGState()
                cgContext.translateBy(
                    x: (textElement.position.x + imageTranslation.width) * scaleX * imageScale,
                    y: (textElement.position.y + imageTranslation.height) * scaleY * imageScale
                )
                cgContext.rotate(by: CGFloat(textElement.rotation) * .pi / 180)
                
                let rect = CGRect(
                    x: -size.width / 2,
                    y: -size.height / 2,
                    width: size.width,
                    height: size.height
                )
                
                textElement.text.draw(in: rect, withAttributes: attributes)
                cgContext.restoreGState()
            }
        }
    }
    
    private func convertTextElementsToData() -> [TextElementData]? {
        guard !textElements.isEmpty else { return nil }
        
        return textElements.map { element in
            let uiColor = UIColor(element.color)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            return TextElementData(
                id: element.id.uuidString,
                text: element.text,
                x: element.position.x,
                y: element.position.y,
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha),
                fontSize: element.fontSize,
                rotation: element.rotation
            )
        }
    }
    
    private func getDrawingData() -> Data? {
        guard !canvasView.drawing.bounds.isEmpty else { return nil }
        
        do {
            return try canvasView.drawing.dataRepresentation()
        } catch {
            print("描画データの変換に失敗しました: \(error)")
            return nil
        }
    }
    
    private func loadExistingStickerData(_ stickerItem: StickerItem) {
        isLoadingExistingData = true
        
        // Load the existing shape
        if let shapeString = stickerItem.shape,
           let shape = StickerShape(rawValue: shapeString) {
            selectedShape = shape
        }
        
        // Load the existing image
        if let customImage = stickerItem.customImage {
            selectedImage = customImage
            imageOffset = .zero
            // 編集時は描画モードから開始（画像編集は既に完了済み）
            isImageEditingMode = false
            // 画像変形情報を復元
            imageScale = stickerItem.imageScale
            imageTranslation = stickerItem.imageTranslation
            isLoadingExistingData = false
        } else if let firebaseImageURL = stickerItem.firebaseImageURL {
            // Firebase画像の場合は非同期でロード
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: URL(string: firebaseImageURL)!)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                            imageOffset = .zero
                            isImageEditingMode = false
                            imageScale = stickerItem.imageScale
                            imageTranslation = stickerItem.imageTranslation
                            isLoadingExistingData = false
                        }
                    }
                } catch {
                    print("Firebase画像の読み込みに失敗しました: \(error)")
                    await MainActor.run {
                        isLoadingExistingData = false
                    }
                }
            }
        } else {
            isLoadingExistingData = false
        }
        
        // Load existing drawing data if available
        if let drawingData = stickerItem.drawingData {
            do {
                canvasView.drawing = try PKDrawing(data: drawingData)
            } catch {
                print("Failed to load drawing data: \(error)")
            }
        }
        
        // Load existing text elements if available
        if let textElementsData = stickerItem.textElements {
            textElements = textElementsData.compactMap { elementData in
                guard let id = UUID(uuidString: elementData.id) else { return nil }
                return TextElement(
                    id: id,
                    text: elementData.text,
                    position: CGPoint(x: elementData.x, y: elementData.y),
                    color: Color(.sRGB, red: elementData.red, green: elementData.green, blue: elementData.blue, opacity: elementData.alpha),
                    fontSize: elementData.fontSize,
                    rotation: elementData.rotation
                )
            }
        }
        
        // Load existing sticker name if available
        if let stickerName = stickerItem.stickerName {
            self.stickerName = stickerName
        }
    }
    
    private func updateUndoState() {
        canUndo = !canvasView.drawing.strokes.isEmpty
        canRedo = !undoHistory.isEmpty
    }
    
    private func performUndo() {
        guard !canvasView.drawing.strokes.isEmpty else { return }
        
        let lastStroke = canvasView.drawing.strokes.last!
        undoHistory.append(lastStroke)
        
        var drawing = canvasView.drawing
        drawing.strokes.removeLast()
        canvasView.drawing = drawing
        
        updateUndoState()
    }
    
    private func performRedo() {
        guard !undoHistory.isEmpty else { return }
        
        let strokeToRedo = undoHistory.removeLast()
        
        var drawing = canvasView.drawing
        drawing.strokes.append(strokeToRedo)
        canvasView.drawing = drawing
        
        updateUndoState()
    }
    
    private func clearHistory() {
        undoHistory.removeAll()
    }
    
    private func cycleToNextShape() {
        let allShapes = StickerShape.allCases
        guard let currentIndex = allShapes.firstIndex(of: selectedShape) else { return }
        let nextIndex = (currentIndex + 1) % allShapes.count
        selectedShape = allShapes[nextIndex]
    }
}

struct PencilKitCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    let isDrawingEnabled: Bool
    let onNewDrawingStarted: () -> Void
    let onDrawingChanged: () -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = UIColor.clear
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isDrawingEnabled
        
        if isDrawingEnabled {
            toolPicker.setVisible(true, forFirstResponder: uiView)
            uiView.becomeFirstResponder()
        } else {
            toolPicker.setVisible(false, forFirstResponder: uiView)
            uiView.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitCanvasView
        private var isDrawing = false
        
        init(_ parent: PencilKitCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            if !isDrawing {
                isDrawing = true
                parent.onNewDrawingStarted()
            }
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = false
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged()
        }
    }
}

struct TextElement: Identifiable {
    let id: UUID
    var text: String
    var position: CGPoint
    var color: Color
    var fontSize: CGFloat
    var rotation: Double
}

struct ToolButton: View {
    let tool: StickerCreatorView.CreatorTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20))
                Text(tool.title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 60, height: 60)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

struct DraggableTextView: View {
    @Binding var textElement: TextElement
    let isSelected: Bool
    let onDelete: () -> Void
    let onTextChanged: () -> Void
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var lastRotationAngle: Angle = .zero
    @State private var showDeleteButton = false
    
    var body: some View {
        ZStack {
            Text(textElement.text)
                .font(.system(size: textElement.fontSize))
                .foregroundColor(textElement.color)
                .rotationEffect(.degrees(textElement.rotation))
                .position(textElement.position)
            
            if showDeleteButton {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .position(x: textElement.position.x + textElement.fontSize/2 + 10,
                          y: textElement.position.y - textElement.fontSize/2 - 10)
            }
        }
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        textElement.position = value.location
                        onTextChanged()
                    },
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let deltaScale = value / lastScaleValue
                            textElement.fontSize = max(8, min(100, textElement.fontSize * deltaScale))
                            lastScaleValue = value
                            onTextChanged()
                        }
                        .onEnded { _ in
                            lastScaleValue = 1.0
                        },
                    RotationGesture()
                        .onChanged { value in
                            let deltaAngle = value - lastRotationAngle
                            textElement.rotation += deltaAngle.degrees
                            lastRotationAngle = value
                            onTextChanged()
                        }
                        .onEnded { _ in
                            lastRotationAngle = .zero
                        }
                )
            )
        )
        .onTapGesture {
            if isSelected {
                showDeleteButton.toggle()
            }
        }
        .onLongPressGesture {
            onDelete()
        }
    }
}

struct TextEditorSheet: View {
    let onSave: (String, Color) -> Void
    @State private var text = ""
    @State private var selectedColor: Color = .black
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("テキストを入力", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("色を選択")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ColorPicker("色を選択", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .padding(.horizontal)
                }
                
                Text("プレビュー")
                    .font(.headline)
                    .padding(.horizontal)
                
                Text(text.isEmpty ? "テキストを入力してください" : text)
                    .font(.system(size: 24))
                    .foregroundColor(selectedColor)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("テキスト追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        if !text.isEmpty {
                            onSave(text, selectedColor)
                        }
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

struct EditableShapedImageView: View {
    let image: UIImage
    let shape: StickerShape
    @Binding var scale: CGFloat
    @Binding var translation: CGSize
    let onShapeChange: () -> Void
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .scaleEffect(scale)
            .offset(translation)
            .clipShape(shapeClipPath)
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            translation = value.translation
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.5, min(3.0, value))
                        }
                )
            )
            .onTapGesture {
                onShapeChange()
            }
    }
    
    private var shapeClipPath: AnyShape {
        switch shape {
        case .circle:
            return AnyShape(Circle())
        case .square:
            return AnyShape(SquareShape())
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

struct ShapedImageView: View {
    let image: UIImage
    let shape: StickerShape
    let scale: CGFloat
    let translation: CGSize
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .scaleEffect(scale)
            .offset(translation)
            .clipShape(shapeClipPath)
    }
    
    private var shapeClipPath: AnyShape {
        switch shape {
        case .circle:
            return AnyShape(Circle())
        case .square:
            return AnyShape(SquareShape())
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
