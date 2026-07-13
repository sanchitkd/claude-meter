import AppKit
import SwiftUI

public struct IslandView: View {
    @ObservedObject private var stateManager: UsageStateManager
    @ObservedObject private var settings: SettingsManager
    @ObservedObject private var actions: AppActions

    @State private var isHovered = false
    @State private var shakeTrigger: CGFloat = 0

    public init(
        stateManager: UsageStateManager,
        settings: SettingsManager,
        actions: AppActions
    ) {
        self.stateManager = stateManager
        self.settings = settings
        self.actions = actions
    }

    public var body: some View {
        let expanded = isHovered
        let maxUsage = currentMaxUsage
        let pulseActive = maxUsage >= 85
        let strongPulse = maxUsage >= 95
        let exhausted = maxUsage >= 100
        let accent = UsageColorResolver.color(for: maxUsage, palette: settings.colorPalette)

        ZStack(alignment: .top) {
            if expanded {
                ExpandedIslandView(
                    snapshot: stateManager.snapshot,
                    now: stateManager.now,
                    isRefreshing: stateManager.isRefreshing,
                    sessionCountdown: stateManager.sessionCountdownText(),
                    weeklyCountdown: stateManager.weeklyCountdownText(),
                    onSettings: { actions.openPreferences() }
                )
                .padding(.top, 38)   // drop card below the menu-bar / notch row
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                CollapsedIslandView(
                    snapshot: stateManager.snapshot,
                    palette: settings.colorPalette,
                    isRefreshing: stateManager.isRefreshing
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .frame(width: expanded ? 520 : 128, height: expanded ? 186 : 26)
        .background {
            VisualEffectBlur(material: .hudWindow)
                .clipShape(RoundedRectangle(cornerRadius: expanded ? 30 : 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: expanded ? 30 : 13, style: .continuous)
                        .fill(.black.opacity(expanded ? 0.44 : 0))
                }
                .opacity(expanded ? 1 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 30 : 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: expanded ? 30 : 13, style: .continuous)
                .stroke(.white.opacity(expanded ? 0.18 : 0), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.38), radius: expanded ? 22 : 12, y: expanded ? 12 : 6)
        .modifier(
            PulseOverlay(
                active: pulseActive,
                strong: strongPulse,
                enabled: settings.animationsEnabled,
                color: accent
            )
        )
        .modifier(
            ShakeEffect(
                travelDistance: exhausted ? 5 : 0,
                shakesPerUnit: 4,
                animatableData: shakeTrigger
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: expanded ? 30 : 22, style: .continuous))
        .onHover { hovering in
            withOptionalAnimation {
                isHovered = hovering
            }
            if hovering {
                let age = stateManager.now.timeIntervalSince(stateManager.snapshot.capturedAt)
                if age > 60 { actions.refresh() }
            }
        }
        .onTapGesture(count: 2) {
            actions.openUsagePage()
        }
        .onTapGesture(count: 1) {
            actions.refresh()
        }
        .contextMenu {
            IslandContextMenu(actions: actions)
        }
        .onChange(of: exhausted) { _, newValue in
            guard newValue, settings.animationsEnabled else {
                return
            }
            withAnimation(.linear(duration: 0.42)) {
                shakeTrigger += 1
            }
        }
        .animation(
            settings.animationsEnabled ? .spring(response: 0.34, dampingFraction: 0.82) : nil,
            value: isHovered
        )
        .animation(
            settings.animationsEnabled ? .easeInOut(duration: 0.45) : nil,
            value: stateManager.snapshot.session?.usagePercentage
        )
        .animation(
            settings.animationsEnabled ? .easeInOut(duration: 0.45) : nil,
            value: stateManager.snapshot.weekly?.usagePercentage
        )
    }

    private var currentMaxUsage: Double {
        let session = stateManager.snapshot.session?.usagePercentage ?? 0
        let weekly = stateManager.snapshot.weekly?.usagePercentage ?? 0
        return max(session, weekly)
    }

    private func withOptionalAnimation(_ changes: @escaping () -> Void) {
        if settings.animationsEnabled {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82), changes)
        } else {
            changes()
        }
    }
}

private struct CollapsedIslandView: View {
    let snapshot: UsageSnapshot
    let palette: UsageColorPalette
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 0) {
            half(
                label: "S",
                marker: nil,
                value: snapshot.session?.usagePercentage,
                leading: true
            )
            .accessibilityLabel("Current session usage")

            half(
                label: "W",
                marker: snapshot.weeklyMarker,
                value: snapshot.weekly?.usagePercentage,
                leading: false
            )
            .accessibilityLabel(weeklyAccessibilityLabel)
        }
        .frame(width: 128, height: 26)
        .clipShape(Capsule(style: .continuous))
        .overlay {
            if isRefreshing {
                ProgressView().scaleEffect(0.4).tint(.white.opacity(0.85))
            }
        }
    }

    private var weeklyAccessibilityLabel: String {
        if let driver = snapshot.weeklyDriver {
            return "Weekly usage, currently capped by \(driver)"
        }
        return "Weekly usage, all models"
    }

    /// `marker` appears only when a model cap — not the all-models cap — is the one that
    /// will stop you. "W·F 100%" says *why* the pill is red without opening the card.
    private func half(label: String, marker: String?, value: Double?, leading: Bool) -> some View {
        let fill = UsageColorResolver.color(for: value, palette: palette)
        let txt = UsageColorResolver.textColor(for: value, palette: palette)
        let valueText = value.map { "\(Int($0.rounded()))%" } ?? "—"
        return HStack(spacing: 3) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .opacity(0.75)
                if let marker {
                    Text("·\(marker)")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .opacity(0.95)
                }
            }
            Text(valueText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .foregroundStyle(txt)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, leading ? 4 : 0)
        .padding(.trailing, leading ? 0 : 4)
        .background(fill)
    }
}

private struct ExpandedIslandView: View {
    let snapshot: UsageSnapshot
    let now: Date
    let isRefreshing: Bool
    let sessionCountdown: String
    let weeklyCountdown: String
    let onSettings: () -> Void

    /// Only worth showing chips when there's more than one weekly cap in play.
    private var weeklyRows: [UsageLimit] {
        let rows = snapshot.weeklyLimits
        return rows.count > 1 ? rows : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        title: "Currently Used",
                        value: UsageFormatters.percentageString(snapshot.session?.usagePercentage)
                    )
                    MetricRow(title: "Current Reset", value: sessionCountdown)
                }
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        title: weeklyTitle,
                        value: UsageFormatters.percentageString(snapshot.weekly?.usagePercentage)
                    )
                    MetricRow(title: "Weekly Reset", value: weeklyCountdown)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                MetricRow(title: "Last Refresh", value: UsageFormatters.timestampString(snapshot.capturedAt))

                if !weeklyRows.isEmpty {
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        ForEach(weeklyRows) { limit in
                            LimitChip(
                                limit: limit,
                                isBinding: limit.id == weeklyRows.first?.id   // sorted worst-first
                            )
                        }
                    }
                }
            }

            footer
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(width: 520, height: 148, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    /// "Weekly Used" normally; "Weekly · Fable" when a model cap is the binding one.
    private var weeklyTitle: String {
        if let driver = snapshot.weeklyDriver {
            return "Weekly · \(driver)"
        }
        return "Weekly Used"
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Claude Meter")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)

            if isRefreshing {
                ProgressView().scaleEffect(0.5).tint(.white.opacity(0.85))
            }

            Spacer(minLength: 12)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            statusDot
            Text(snapshot.status.message ?? snapshot.sourceDescription)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(snapshot.status.message == nil ? 0.48 : 0.78))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Link(destination: AppLinks.feedback) {
                HStack(spacing: 5) {
                    Image(systemName: "paperplane.fill").font(.system(size: 9, weight: .semibold))
                    Text("Feedback").font(.system(size: 10.5, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .foregroundStyle(.white)
                .background(Capsule().fill(.white.opacity(0.18)))
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Send feedback · about Claude Meter")
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(snapshot.status.message == nil ? .green.opacity(0.8) : .yellow.opacity(0.88))
            .frame(width: 6, height: 6)
    }
}

/// One weekly cap, as reported. Tinted by Anthropic's own `severity` — not by the user's
/// palette, which stays in charge of the pill itself.
private struct LimitChip: View {
    let limit: UsageLimit
    let isBinding: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(limit.displayName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Text("\(Int(limit.percent.rounded()))%")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(isBinding ? 0.14 : 0.06)))
        .overlay(Capsule().stroke(tint.opacity(isBinding ? 0.85 : 0.28), lineWidth: 1))
        .help(helpText)
    }

    private var tint: Color {
        switch limit.severity {
        case .critical: .red
        case .warning: .orange
        case .normal: .green
        case .unknown: .gray
        }
    }

    private var helpText: String {
        isBinding
            ? "\(limit.displayName) — this is the limit currently capping you"
            : limit.displayName
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 112, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 108, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct IslandContextMenu: View {
    @ObservedObject var actions: AppActions

    var body: some View {
        Button("Sign in to Claude") {
            actions.signIn()
        }
        Button("Refresh") {
            actions.refresh()
        }
        Button("Open Claude") {
            actions.openClaude()
        }
        Button("Open Usage Page") {
            actions.openUsagePage()
        }
        Divider()
        Button("Open Logs") {
            actions.openLogs()
        }
        Button("Preferences") {
            actions.openPreferences()
        }
        Button("Send Feedback…") {
            NSWorkspace.shared.open(AppLinks.feedback)
        }
        Divider()
        Button("Quit") {
            actions.quit()
        }
    }
}
