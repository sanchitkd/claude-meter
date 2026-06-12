import AppKit
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings: SettingsManager
    private let logger: AppLogger?
    private let onQuit: (() -> Void)?
    @State private var logSize: String = "—"
    public init(settings: SettingsManager, logger: AppLogger? = nil, onQuit: (() -> Void)? = nil) {
        self.settings = settings
        self.logger = logger
        self.onQuit = onQuit
    }

    public var body: some View {
        Form {
            Section("Updates") {
                HStack(spacing: 12) {
                    Text("Refresh every")
                    Slider(value: refreshIntervalBinding, in: 60...1800)
                    Text("\(Int(settings.refreshInterval)) sec")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                }
                Toggle("Enable animations", isOn: $settings.animationsEnabled)
            }

            Section("App") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)

                Picker("Appearance", selection: $settings.appearanceOverride) {
                    ForEach(AppearanceOverride.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Pill Position") {
                Picker("Show pill on", selection: $settings.pillScreenMode) {
                    ForEach(PillScreenMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if settings.pillScreenMode == .specific {
                    Picker("Display", selection: $settings.pillDisplayID) {
                        ForEach(connectedDisplays(), id: \.id) { display in
                            Text(display.name).tag(display.id)
                        }
                    }
                }
            }
            Section("Usage Colors") {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    ColorRow(title: "0-20%", color: colorBinding(\.green))
                    ColorRow(title: "20-40%", color: colorBinding(\.cyan))
                    ColorRow(title: "40-60%", color: colorBinding(\.blue))
                    ColorRow(title: "60-75%", color: colorBinding(\.yellow))
                    ColorRow(title: "75-85%", color: colorBinding(\.orange))
                    ColorRow(title: "85-95%", color: colorBinding(\.red))
                    ColorRow(title: "95-99%", color: colorBinding(\.darkRed))
                    ColorRow(title: "100%", color: colorBinding(\.exhausted))
                    ColorRow(title: "Unavailable", color: colorBinding(\.unavailable))
                }

                Button("Reset Colors") {
                    settings.resetPalette()
                }
            }
            Section("Logs") {
                HStack {
                    Text("Current size")
                    Spacer()
                    Text(logSize).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Rotate") { logger?.rotate(); refreshLogSize(after: 0.3) }
                    Button("Clear") { logger?.clear(); refreshLogSize(after: 0.3) }
                    Spacer()
                    Button("Show in Finder") {
                        if let url = logger?.logFileURL {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                }
                }
            Section {
                Button(role: .destructive) { onQuit?() } label: {
                    Text("Quit Claude Meter").frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshLogSize() }
        .padding(20)
        .frame(width: 520, height: 640)
    }

    private var refreshIntervalBinding: Binding<Double> {
        Binding(
            get: { settings.refreshInterval },
            set: { let v = max(60, min(3_600, $0)); settings.refreshInterval = (v / 30).rounded() * 30 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        )
    }

    private func refreshLogSize(after delay: Double = 0) {
        func update() { logSize = logger?.formattedSize() ?? "—" }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { update() }
        } else { update() }
    }
    private func connectedDisplays() -> [(id: Int, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return nil }
            return (Int(num), screen.localizedName)
        }
    }
    private func colorBinding(_ keyPath: WritableKeyPath<UsageColorPalette, String>) -> Binding<Color> {
        Binding(
            get: {
                Color(nsColor: NSColor(hex: settings.colorPalette[keyPath: keyPath]) ?? .systemGray)
            },
            set: { newColor in
                var next = settings.colorPalette
                next[keyPath: keyPath] = NSColor(newColor).hexString()
                settings.colorPalette = next
            }
        )
    }
}

private struct ColorRow: View {
    let title: String
    @Binding var color: Color

    init(title: String, color: Binding<Color>) {
        self.title = title
        self._color = color
    }

    var body: some View {
        GridRow {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)
            ColorPicker(title, selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
    }
}
