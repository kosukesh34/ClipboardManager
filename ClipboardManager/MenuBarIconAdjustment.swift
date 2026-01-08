import AppKit

protocol MenuBarIconApplying: AnyObject {
    func applyMenuBarIconAdjustments()
}

struct ImageAdjustmentSettings: Equatable {
    var isPaddingEnabled: Bool
    var padding: CGFloat
    var isResizeEnabled: Bool
    var targetWidth: CGFloat
    var targetHeight: CGFloat
    var backgroundColor: NSColor
    
    static let `default` = ImageAdjustmentSettings(
        isPaddingEnabled: false,
        padding: 0,
        isResizeEnabled: false,
        targetWidth: 18,
        targetHeight: 18,
        backgroundColor: NSColor.clear
    )
    
    var usesCustomColors: Bool {
        return isPaddingEnabled && padding > 0 && backgroundColor.alphaComponent > 0
    }
    
    var hasAdjustments: Bool {
        return (isPaddingEnabled && padding > 0) || isResizeEnabled
    }
}

final class ImageAdjustmentSettingsStore {
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
        static let isPaddingEnabled = "ImageAdjustment.isPaddingEnabled"
        static let padding = "ImageAdjustment.padding"
        static let isResizeEnabled = "ImageAdjustment.isResizeEnabled"
        static let targetWidth = "ImageAdjustment.targetWidth"
        static let targetHeight = "ImageAdjustment.targetHeight"
        static let colorRed = "ImageAdjustment.colorRed"
        static let colorGreen = "ImageAdjustment.colorGreen"
        static let colorBlue = "ImageAdjustment.colorBlue"
        static let colorAlpha = "ImageAdjustment.colorAlpha"
    }
}

final class MenuBarIconAdjuster {
    func adjustedImage(from image: NSImage, settings: ImageAdjustmentSettings) -> NSImage {
        guard settings.hasAdjustments else {
            return image
        }
        
        var workingImage = image
        
        if settings.isResizeEnabled {
            let size = NSSize(
                width: max(settings.targetWidth, 1),
                height: max(settings.targetHeight, 1)
            )
            workingImage = resizedImage(from: workingImage, size: size)
        }
        
        if settings.isPaddingEnabled, settings.padding > 0 {
            workingImage = paddedImage(
                from: workingImage,
                padding: settings.padding,
                backgroundColor: settings.backgroundColor
            )
        }
        
        return workingImage
    }
    
    private func resizedImage(from image: NSImage, size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }
    
    private func paddedImage(from image: NSImage, padding: CGFloat, backgroundColor: NSColor) -> NSImage {
        let newSize = NSSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        backgroundColor.setFill()
        NSRect(origin: .zero, size: newSize).fill()
        let origin = NSPoint(x: padding, y: padding)
        image.draw(in: NSRect(origin: origin, size: image.size))
        newImage.unlockFocus()
        return newImage
    }
}

extension NSColor {
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        let rgbColor = usingColorSpace(.deviceRGB) ?? self
        return (
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
    }
}
