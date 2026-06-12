import AppKit
import Combine
import SwiftUI

@MainActor
public final class IslandPanelController {
    private let panel: IslandPanel
    private let panelSize = NSSize(width: 560, height: 210)
    private var cancellables: Set<AnyCancellable> = []
    private let settings: SettingsManager

    public init<Content: View>(rootView: Content, settings: SettingsManager) {
        self.settings = settings
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(origin: .zero, size: panelSize)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        self.panel = IslandPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        panel.ignoresMouseEvents = false
        panel.appearance = NSAppearance(named: .darkAqua)   // pill + card always dark

        observeScreens()
        reposition()
    }

    public func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    public func reposition() {
        guard let screen = targetScreen() else { return }
        let frame = screen.frame

        // Notch displays: park the pill in the usable strip LEFT of the notch so it
        // never hides behind the camera. Non-notch: top-center.
        let hasNotch = screen.safeAreaInsets.top > 0
        var centerX = frame.midX
        if hasNotch, let leftArea = screen.auxiliaryTopLeftArea {
            centerX = leftArea.maxX - 90   // pill center ~90pt left of the notch
        }

        var originX = centerX - panelSize.width / 2
        originX = min(max(originX, frame.minX + 8), frame.maxX - panelSize.width - 8)
        let originY = frame.maxY - panelSize.height - 1
        panel.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: panelSize), display: true)
        panel.orderFrontRegardless()
        NSLog("ClaudeMeter: pill on screen \(frame) origin (\(Int(originX)),\(Int(originY))) notch=\(hasNotch)")
    }

    private func targetScreen() -> NSScreen? {
        switch settings.pillScreenMode {
        case .builtIn:    return builtInScreen() ?? NSScreen.main ?? NSScreen.screens.first
        case .activeScreen: return NSScreen.main ?? mouseScreen() ?? NSScreen.screens.first
        case .underMouse: return mouseScreen() ?? NSScreen.main ?? NSScreen.screens.first
        case .specific:
            let wanted = CGDirectDisplayID(settings.pillDisplayID)
            return NSScreen.screens.first(where: { displayID(of: $0) == wanted })
                ?? mouseScreen() ?? NSScreen.main ?? NSScreen.screens.first
        }
    }
    private func mouseScreen() -> NSScreen? {
        let m = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(m, $0.frame, false) })
    }
    private func builtInScreen() -> NSScreen? {
        NSScreen.screens.first(where: { displayID(of: $0) != 0 && CGDisplayIsBuiltin(displayID(of: $0)) != 0 })
    }
    private func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    private func observeScreens() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in Task { @MainActor [weak self] in self?.reposition() } }
            .store(in: &cancellables)
        settings.$pillScreenMode.combineLatest(settings.$pillDisplayID)
            .sink { [weak self] _, _ in Task { @MainActor [weak self] in self?.reposition() } }
            .store(in: &cancellables)
    }
}
