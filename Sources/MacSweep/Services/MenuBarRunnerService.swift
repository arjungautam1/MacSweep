import Foundation
import SwiftUI
import AppKit
import Combine

public enum RunnerTheme: String, CaseIterable, Identifiable, Sendable {
    case brush = "Clean Brush (Default)"
    case broom = "Sweeper Broom"
    case sparkles = "Sparkle Magic"
    case runcat = "Running Cat"
    case beagle = "Beagle Dog"
    case rabbit = "White Rabbit"
    case dinosaur = "Dinosaur"

    public var id: String { rawValue }

    public var isVectorSymbol: Bool {
        switch self {
        case .brush, .broom, .sparkles: return true
        default: return false
        }
    }

    public var systemSymbolName: String? {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .broom: return "broom.fill"
        case .sparkles: return "sparkles"
        default: return nil
        }
    }

    public var sheetName: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .broom: return "broom.fill"
        case .sparkles: return "sparkles"
        case .runcat: return "runner-runcat"
        case .beagle: return "runner-beagle"
        case .rabbit: return "runner-rabbit"
        case .dinosaur: return "runner-dinosaur"
        }
    }

    public var frameDimensions: (width: CGFloat, height: CGFloat) {
        switch self {
        case .brush, .broom, .sparkles: return (22, 18)
        case .runcat: return (126, 77)
        case .beagle: return (60, 36)
        case .rabbit: return (43, 36)
        case .dinosaur: return (51, 36)
        }
    }
}

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case runnerAndMetrics = "Icon & Data"
    case runnerOnly = "Icon Only"
    case metricsOnly = "Data Only"

    public var id: String { rawValue }
}

@MainActor
public final class MenuBarRunnerService: ObservableObject {
    public static let shared = MenuBarRunnerService()

    @Published public var currentTheme: RunnerTheme = .brush
    @Published public var displayMode: MenuBarDisplayMode = .runnerAndMetrics
    @Published public var currentFrameIndex: Int = 0
    @Published public var frames: [NSImage] = []

    private var animationTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        loadFrames()

        // Re-adjust animation speed when CPU telemetry changes
        SystemTelemetryService.shared.$cpuUsagePercentage
            .sink { [weak self] cpu in
                self?.adjustAnimationSpeed(cpu: cpu)
            }
            .store(in: &cancellables)
    }

    public func setTheme(_ theme: RunnerTheme) {
        self.currentTheme = theme
        loadFrames()
    }

    public func setDisplayMode(_ mode: MenuBarDisplayMode) {
        self.displayMode = mode
    }

    private func loadFrames() {
        if currentTheme.isVectorSymbol, let symbol = currentTheme.systemSymbolName {
            // Generate clean sweeping brush/broom frames
            self.frames = MenuBarRunnerService.generateSweepingFrames(systemName: symbol)
        } else {
            let (w, h) = currentTheme.frameDimensions
            let extracted = AssetLoader.extractSpriteFrames(from: currentTheme.sheetName, frameWidth: w, frameHeight: h)
            if !extracted.isEmpty {
                self.frames = extracted
            } else {
                self.frames = MenuBarRunnerService.generateSweepingFrames(systemName: "paintbrush.pointed.fill")
            }
        }
        self.currentFrameIndex = 0
        adjustAnimationSpeed(cpu: SystemTelemetryService.shared.cpuUsagePercentage)
    }

    private func adjustAnimationSpeed(cpu: Double) {
        animationTimer?.cancel()
        guard !frames.isEmpty else { return }

        // Interval ranges from 0.28s (idle) down to 0.04s (100% load)
        let normalized = min(1.0, max(0.0, cpu / 100.0))
        let interval = 0.28 - (normalized * 0.24)

        animationTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.frames.isEmpty else { return }
                self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
            }
    }

    public var currentFrameImage: NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[currentFrameIndex % frames.count]
    }

    /// Generates animated sweeping brush or broom frames with subtle angular rotation
    private static func generateSweepingFrames(systemName: String) -> [NSImage] {
        var resultFrames: [NSImage] = []
        let angles: [CGFloat] = [-14.0, -8.0, -2.0, 4.0, 10.0, 4.0, -2.0, -8.0]
        let canvasSize = NSSize(width: 20, height: 18)

        let baseConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        guard let baseSymbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(baseConfig) else {
            return []
        }

        for angle in angles {
            let frameImg = NSImage(size: canvasSize)
            frameImg.lockFocus()

            let context = NSGraphicsContext.current?.cgContext
            context?.saveGState()

            // Rotate around bottom-center to mimic sweeping motion
            context?.translateBy(x: canvasSize.width / 2.0, y: 4.0)
            context?.rotate(by: angle * .pi / 180.0)

            let drawRect = NSRect(
                x: -canvasSize.width / 2.0,
                y: -4.0,
                width: canvasSize.width,
                height: canvasSize.height
            )
            baseSymbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

            context?.restoreGState()
            frameImg.unlockFocus()
            frameImg.isTemplate = true // Ensures perfect contrast in light and dark mode menu bars
            resultFrames.append(frameImg)
        }

        return resultFrames
    }
}
