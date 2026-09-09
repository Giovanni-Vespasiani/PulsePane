import AppKit
import SwiftUI

/// A hosting view that clips its content to a rounded rectangle.
/// This ensures the widget has clean rounded corners without rectangular shadow artifacts.
final class RoundedHostingView<Content: View>: NSHostingView<Content> {
    private let cornerRadius: CGFloat

    init(rootView: Content, cornerRadius: CGFloat = 28) {
        self.cornerRadius = cornerRadius
        super.init(rootView: rootView)
        setupView()
    }

    required init(rootView: Content) {
        self.cornerRadius = 28
        super.init(rootView: rootView)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateCornerRadius()
    }

    private func setupView() {
        // Ensure the view itself doesn't draw a background
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        
        // Subtle shadow with explicit path to prevent rectangular artifact on light wallpapers
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.12
        layer?.shadowOffset = CGSize(width: 0, height: 1)
        layer?.shadowRadius = 4
        layer?.shadowPath = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        layer?.masksToBounds = false
    }

    private func updateCornerRadius() {
        layer?.cornerRadius = cornerRadius
    }

    // MARK: - Drag handling (Candidate A: NSWindow.performDrag)

    override func mouseDown(with event: NSEvent) {
        // Only initiate window drag on left mouse button; allow right-click for context menu.
        if event.type == .leftMouseDown {
            window?.performDrag(with: event)
            // After the drag ends, notify to snap and persist.
            if let win = window {
                NotificationCenter.default.post(name: .pulsePaneWindowDragEnded, object: win)
            }
        } else {
            super.mouseDown(with: event)
        }
    }
}