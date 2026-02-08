import SwiftUI
import AppKit

struct StatusItemTooltip: NSViewRepresentable {
    let tooltip: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // We delay slightly to ensure the view has been added to the window hierarchy
        DispatchQueue.main.async {
            self.updateTooltip(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateTooltip(for: nsView)
    }

    private static var lastTooltip: String = ""

    private func updateTooltip(for view: NSView) {
        if tooltip.isEmpty { return }

        // Optimization: Don't scan windows if tooltip text hasn't changed
        if StatusItemTooltip.lastTooltip == tooltip { return }
        StatusItemTooltip.lastTooltip = tooltip

        let allWindows = NSApplication.shared.windows
        for window in allWindows where window.className == "NSStatusBarWindow" {
            if let button = findButton(in: window.contentView?.superview ?? window.contentView!) {
                button.toolTip = tooltip
            }
        }
    }

    private func findButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let found = findButton(in: subview) { return found }
        }
        return nil
    }
}

extension NSView {
    func firstSubview<T: NSView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let match = subview.firstSubview(of: type) { return match }
        }
        return nil
    }
}

extension View {
    func menuBarTooltip(_ tooltip: String) -> some View {
        self.background(StatusItemTooltip(tooltip: tooltip))
    }
}
