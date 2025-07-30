//
//  ContentView.swift
//  finalPic
//
//  Created by 刘瑞 on 2025/7/25.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var selectedImage: NSImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isImagePickerPresented = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero
    @State private var selectedFilter: ImageFilter = .none
    @State private var filterIntensity: Double = 0.5
    @State private var showingImageInfo = false

    enum ImageFilter: String, CaseIterable {
        case none = "无滤镜"
        case sepia = "复古"
        case noir = "黑白"
        case vibrant = "鲜艳"
        case blur = "模糊"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题
                HStack {
                    Text("图片选择器")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()
                    // 如果选择了图片
                    if selectedImage != nil {
                        Button(action: { showingImageInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .popover(isPresented: $showingImageInfo) {
                            ImageInfoView(image: selectedImage!)
                        }
                    }
                }
                .padding(.top)

                // 图片显示区域
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 400)

                    if let selectedImage = selectedImage {
                        Image(nsImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(imageScale)
                            .offset(imageOffset)
                            .modifier(ImageFilterModifier(filter: selectedFilter, intensity: filterIntensity))
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        imageScale = value
                                    }
                                    .simultaneously(with: DragGesture()
                                        .onChanged { value in
                                            imageOffset = CGSize(
                                                width: lastImageOffset.width + value.translation.width,
                                                height: lastImageOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastImageOffset = imageOffset
                                        }
                                    )
                            )
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("请选择一张图片")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()

                // 控制按钮
                HStack(spacing: 20) {
                    // 选择图片按钮
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("选择图片", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    // 重置按钮
                    Button(action: resetImage) {
                        Label("重置", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedImage == nil)

                    // 保存按钮
                    Button(action: saveImage) {
                        Label("保存", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedImage == nil)
                }

                // 滤镜控制
                if selectedImage != nil {
                    VStack(spacing: 15) {
                        Text("滤镜效果")
                            .font(.headline)

                        Picker("滤镜", selection: $selectedFilter) {
                            ForEach(ImageFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if selectedFilter != .none {
                            VStack {
                                Text("强度: \(Int(filterIntensity * 100))%")
                                    .font(.caption)
                                Slider(value: $filterIntensity, in: 0 ... 1)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                // 缩放控制
                if selectedImage != nil {
                    VStack(spacing: 10) {
                        Text("缩放控制")
                            .font(.headline)

                        HStack {
                            Button(action: { imageScale = max(0.1, imageScale - 0.1) }) {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.title2)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            Text("\(Int(imageScale * 100))%")
                                .font(.headline)
                                .frame(minWidth: 60)

                            Button(action: { imageScale = min(5.0, imageScale + 0.1) }) {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.title2)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 700, minHeight: 800)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = NSImage(data: data)
                {
                    selectedImage = image
                    resetImageTransform()
                }
            }
        }
    }

    // 重置图片
    private func resetImage() {
        selectedImage = nil
        selectedItem = nil
        resetImageTransform()
        selectedFilter = .none
        filterIntensity = 0.5
    }

    // 重置图片透明度
    private func resetImageTransform() {
        imageScale = 1.0
        imageOffset = .zero
        lastImageOffset = .zero
    }

    // 保存图片
    private func saveImage() {
        guard let image = selectedImage else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "edited_image.png"
        savePanel.title = "保存图片"
        savePanel.message = "选择保存位置和文件名"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    if let tiffData = image.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData)
                    {
                        let fileExtension = url.pathExtension.lowercased()
                        let imageData: Data?

                        if fileExtension == "jpg" || fileExtension == "jpeg" {
                            imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
                        } else {
                            imageData = bitmapImage.representation(using: .png, properties: [:])
                        }

                        if let data = imageData {
                            try data.write(to: url)

                            // 显示成功消息
                            DispatchQueue.main.async {
                                let alert = NSAlert()
                                alert.messageText = "保存成功"
                                alert.informativeText = "图片已保存到: \(url.lastPathComponent)"
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "确定")
                                alert.runModal()
                            }
                        }
                    }
                } catch {
                    // 显示错误消息
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "保存失败"
                        alert.informativeText = "无法保存图片: \(error.localizedDescription)"
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                    }
                }
            }
        }
    }
}

// 图片滤镜修饰符
struct ImageFilterModifier: ViewModifier {
    let filter: ContentView.ImageFilter
    let intensity: Double

    func body(content: Content) -> some View {
        switch filter {
        case .none:
            content
        case .sepia:
            content
                .colorMultiply(Color(red: 1.0, green: 0.8, blue: 0.6))
                .opacity(0.8 + intensity * 0.2)
        case .noir:
            content
                .saturation(1.0 - intensity)
        case .vibrant:
            content
                .saturation(1.0 + intensity)
                .contrast(1.0 + intensity * 0.5)
        case .blur:
            content
                .blur(radius: intensity * 10)
        }
    }
}

// 图片信息视图
struct ImageInfoView: View {
    let image: NSImage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("图片信息")
                .font(.headline)
                .padding(.bottom, 5)

            Text("尺寸: \(Int(image.size.width)) × \(Int(image.size.height))")
            Text("文件大小: \(imageFileSize)")

            Spacer()
        }
        .padding()
        .frame(width: 200, height: 100)
    }

    private var imageFileSize: String {
        if let tiffData = image.tiffRepresentation {
            let sizeInBytes = tiffData.count
            let sizeInKB = Double(sizeInBytes) / 1024.0
            return String(format: "%.1f KB", sizeInKB)
        }
        return "未知"
    }
}

#Preview {
    ContentView()
}
