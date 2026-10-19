import SwiftUI
import AppKit

public enum AssetLoader {
    /// Loads an NSImage by name from Bundle.module, main bundle, or Resources directory
    public static func loadNSImage(named name: String) -> NSImage? {
        // 1. Try Bundle.module (SwiftPM resource bundle)
        #if SWIFT_PACKAGE
        if let image = Bundle.module.image(forResource: name) {
            return image
        }
        if let url = Bundle.module.url(forResource: name, withExtension: nil),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png") ?? Bundle.module.url(forResource: name, withExtension: "jpg"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        #endif

        // 2. Try main bundle
        if let image = NSImage(named: NSImage.Name(name)) {
            return image
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png") ?? Bundle.main.url(forResource: name, withExtension: "jpg"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        // 3. Fallback to direct directory checks
        let searchPaths = [
            Bundle.main.resourcePath,
            FileManager.default.currentDirectoryPath + "/Sources/MacSweep/Resources",
            "/Applications/Mole.app/Contents/Resources"
        ].compactMap { $0 }

        for path in searchPaths {
            for ext in ["", ".png", ".jpg", ".webp"] {
                let fullPath = (path as NSString).appendingPathComponent(name + ext)
                if FileManager.default.fileExists(atPath: fullPath),
                   let image = NSImage(contentsOfFile: fullPath) {
                    return image
                }
            }
        }

        return nil
    }

    /// Loads a SwiftUI Image
    public static func loadImage(named name: String) -> Image? {
        if let nsImage = loadNSImage(named: name) {
            return Image(nsImage: nsImage)
        }
        return nil
    }

    /// Extracts sprite frames from a horizontal sprite sheet
    public static func extractSpriteFrames(from sheetName: String, frameWidth: CGFloat, frameHeight: CGFloat) -> [NSImage] {
        guard let sheet = loadNSImage(named: sheetName) else { return [] }
        guard let rep = sheet.representations.first else { return [] }
        let totalWidth = CGFloat(rep.pixelsWide > 0 ? rep.pixelsWide : Int(sheet.size.width))

        let frameCount = max(1, Int(totalWidth / frameWidth))
        var frames: [NSImage] = []

        for i in 0..<frameCount {
            let xOffset = CGFloat(i) * frameWidth
            let cropRect = NSRect(x: xOffset, y: 0, width: frameWidth, height: frameHeight)
            let frameImage = NSImage(size: NSSize(width: frameWidth, height: frameHeight))
            frameImage.lockFocus()
            sheet.draw(
                in: NSRect(origin: .zero, size: NSSize(width: frameWidth, height: frameHeight)),
                from: cropRect,
                operation: .copy,
                fraction: 1.0
            )
            frameImage.unlockFocus()
            frames.append(frameImage)
        }
        return frames
    }
}
