import AppKit
import SwiftUI

@MainActor
final class OverlayBarController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<OverlayBarView>
    private weak var appState: AppState?
    private var observationTask: Task<Void, Never>?

    private static let panelHeight: CGFloat = 28

    init(appState: AppState) {
        self.appState = appState

        let panelWidth = CGFloat(appState.settings.overlayWidth)
        let view = OverlayBarView(utilization: appState.rateLimitData?.sevenDayUtilization ?? 0, width: panelWidth)
        self.hostingView = NSHostingView(rootView: view)

        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView

        positionPanel()

        if appState.rateLimitData?.sevenDayUtilization != nil {
            panel.orderFront(nil)
        }

        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func positionPanel() {
        let screens = NSScreen.screens
        let settings = appState?.settings
        let index = settings?.overlayScreenIndex ?? 0
        let screen = (index < screens.count ? screens[index] : nil) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let panelWidth = CGFloat(settings?.overlayWidth ?? 220)
        let topOffset = CGFloat(settings?.overlayTopOffset ?? 0)
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - Self.panelHeight - topOffset
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: Self.panelHeight), display: true)
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let appState = self.appState else { return }

                let utilization: Double? = withObservationTracking {
                    appState.rateLimitData?.sevenDayUtilization
                } onChange: {
                    // Will resume the continuation below
                }

                if let utilization {
                    let w = CGFloat(appState.settings.overlayWidth)
                    self.hostingView.rootView = OverlayBarView(utilization: utilization, width: w)
                    self.positionPanel()
                    if !self.panel.isVisible {
                        self.panel.orderFront(nil)
                    }
                } else {
                    self.panel.orderOut(nil)
                }

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = appState.rateLimitData
                        _ = appState.settings.overlayScreenIndex
                        _ = appState.settings.overlayWidth
                        _ = appState.settings.overlayTopOffset
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
