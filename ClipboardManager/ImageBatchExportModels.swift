import AppKit
import Foundation
import PDFKit

struct ImageFileItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let displayName: String
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.displayName = url.lastPathComponent
    }
}

struct OutputSizePreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var width: Double
    var height: Double
    
    init(id: UUID = UUID(), name: String, width: Double, height: Double) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
    }
    
    var size: NSSize {
        NSSize(width: max(width, 1), height: max(height, 1))
    }
}

final class OutputSizePresetStore {
    private let userDefaults: UserDefaults
    private let key = "ImageBatch.OutputPresets"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> [OutputSizePreset] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([OutputSizePreset].self, from: data) else {
            return Self.defaultPresets
        }
        return decoded
    }
    
    func save(_ presets: [OutputSizePreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        userDefaults.set(data, forKey: key)
    }
    
    static let defaultPresets: [OutputSizePreset] = [
        OutputSizePreset(name: "iPhone 6.7 (1290x2796)", width: 1290, height: 2796),
        OutputSizePreset(name: "iPhone 6.5 (1242x2688)", width: 1242, height: 2688),
        OutputSizePreset(name: "iPhone 6.1 (1179x2556)", width: 1179, height: 2556),
        OutputSizePreset(name: "iPad 12.9 (2048x2732)", width: 2048, height: 2732),
        OutputSizePreset(name: "iPad 11 (1668x2388)", width: 1668, height: 2388),
        OutputSizePreset(name: "Mac 13 (2560x1600)", width: 2560, height: 1600),
        OutputSizePreset(name: "Mac 16 (2880x1800)", width: 2880, height: 1800)
    ]
}

final class OutputLocationStore {
    private let userDefaults: UserDefaults
    private let key = "ImageBatch.OutputFolder"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> URL? {
        guard let path = userDefaults.string(forKey: key) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    func save(_ url: URL?) {
        userDefaults.set(url?.path, forKey: key)
    }
    
    static var downloadsURL: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
}

final class ImageBatchSettingsStore {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> ImageAdjustmentSettings {
        let defaults = userDefaults
        var settings = ImageAdjustmentSettings.default
        
        if defaults.object(forKey: Keys.isPaddingEnabled) != nil {
            settings.isPaddingEnabled = defaults.bool(forKey: Keys.isPaddingEnabled)
        }
        if defaults.object(forKey: Keys.padding) != nil {
            settings.padding = CGFloat(defaults.double(forKey: Keys.padding))
        }
        if defaults.object(forKey: Keys.isResizeEnabled) != nil {
            settings.isResizeEnabled = defaults.bool(forKey: Keys.isResizeEnabled)
        }
        if defaults.object(forKey: Keys.targetWidth) != nil {
            settings.targetWidth = CGFloat(defaults.double(forKey: Keys.targetWidth))
        }
        if defaults.object(forKey: Keys.targetHeight) != nil {
            settings.targetHeight = CGFloat(defaults.double(forKey: Keys.targetHeight))
        }
        
        if defaults.object(forKey: Keys.colorRed) != nil {
            let red = defaults.double(forKey: Keys.colorRed)
            let green = defaults.double(forKey: Keys.colorGreen)
            let blue = defaults.double(forKey: Keys.colorBlue)
            let alpha = defaults.double(forKey: Keys.colorAlpha)
            settings.backgroundColor = NSColor(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )
        }
        
        return settings
    }
    
    func save(_ settings: ImageAdjustmentSettings) {
        let defaults = userDefaults
        defaults.set(settings.isPaddingEnabled, forKey: Keys.isPaddingEnabled)
        defaults.set(Double(settings.padding), forKey: Keys.padding)
        defaults.set(settings.isResizeEnabled, forKey: Keys.isResizeEnabled)
        defaults.set(Double(settings.targetWidth), forKey: Keys.targetWidth)
        defaults.set(Double(settings.targetHeight), forKey: Keys.targetHeight)
        
        let color = settings.backgroundColor.usingColorSpace(.deviceRGB) ?? settings.backgroundColor
        let components = color.rgbaComponents
        defaults.set(components.red, forKey: Keys.colorRed)
        defaults.set(components.green, forKey: Keys.colorGreen)
        defaults.set(components.blue, forKey: Keys.colorBlue)
        defaults.set(components.alpha, forKey: Keys.colorAlpha)
    }
    
    private enum Keys {
        static let isPaddingEnabled = "ImageBatch.isPaddingEnabled"
        static let padding = "ImageBatch.padding"
        static let isResizeEnabled = "ImageBatch.isResizeEnabled"
        static let targetWidth = "ImageBatch.targetWidth"
        static let targetHeight = "ImageBatch.targetHeight"
        static let colorRed = "ImageBatch.colorRed"
        static let colorGreen = "ImageBatch.colorGreen"
        static let colorBlue = "ImageBatch.colorBlue"
        static let colorAlpha = "ImageBatch.colorAlpha"
    }
}

final class ImageProcessingTodoStore {
    private let userDefaults: UserDefaults
    private let key = "ImageBatch.Todos"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> [TodoItem] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func save(_ todos: [TodoItem]) {
        guard let data = try? JSONEncoder().encode(todos) else { return }
        userDefaults.set(data, forKey: key)
    }
}

final class ImageFileLoader {
    func loadImage(from url: URL) -> NSImage? {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            return renderPDF(at: url)
        }
        return NSImage(contentsOf: url)
    }
    
    private func renderPDF(at url: URL) -> NSImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        
        let rect = page.bounds(for: .mediaBox)
        let image = NSImage(size: rect.size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.translateBy(x: 0, y: rect.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }
        image.unlockFocus()
        return image
    }
}

final class ImageBatchProcessor {
    private let loader: ImageFileLoader
    private let adjuster: MenuBarIconAdjuster
    
    init(loader: ImageFileLoader = ImageFileLoader(),
         adjuster: MenuBarIconAdjuster = MenuBarIconAdjuster()) {
        self.loader = loader
        self.adjuster = adjuster
    }
    
    func exportImages(
        items: [ImageFileItem],
        settings: ImageAdjustmentSettings,
        outputPresets: [OutputSizePreset],
        outputFolder: URL
    ) throws -> [URL] {
        var outputURLs: [URL] = []
        
        for item in items {
            guard let baseImage = loader.loadImage(from: item.url) else {
                continue
            }
            
            let adjustedImage = adjuster.adjustedImage(from: baseImage, settings: settings)
            let baseName = item.url.deletingPathExtension().lastPathComponent
            
            if outputPresets.isEmpty {
                let filename = "\(baseName)_adjusted.png"
                let url = outputFolder.appendingPathComponent(filename)
                if let data = pngData(from: adjustedImage) {
                    try data.write(to: url)
                    outputURLs.append(url)
                }
                continue
            }
            
            for preset in outputPresets {
                let rendered = render(
                    image: adjustedImage,
                    targetSize: preset.size,
                    backgroundColor: settings.backgroundColor
                )
                let filename = "\(baseName)_\(Int(preset.width))x\(Int(preset.height)).png"
                let url = outputFolder.appendingPathComponent(filename)
                if let data = pngData(from: rendered) {
                    try data.write(to: url)
                    outputURLs.append(url)
                }
            }
        }
        
        return outputURLs
    }
    
    private func render(image: NSImage, targetSize: NSSize, backgroundColor: NSColor) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        backgroundColor.setFill()
        NSRect(origin: .zero, size: targetSize).fill()
        
        let drawRect = aspectFitRect(imageSize: image.size, targetSize: targetSize)
        image.draw(in: drawRect)
        newImage.unlockFocus()
        return newImage
    }
    
    private func aspectFitRect(imageSize: NSSize, targetSize: NSSize) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSRect(origin: .zero, size: targetSize)
        }
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = NSPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )
        return NSRect(origin: origin, size: scaledSize)
    }
    
    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
