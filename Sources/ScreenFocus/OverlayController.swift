import AppKit
import CoreGraphics
import Foundation

enum OverlayStyle: Equatable {
    case aligned
    case guarded
    case failed
}

enum CornerPosition: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum BorderEdge: CaseIterable, Hashable {
    case top
    case right
    case bottom
    case left
}

struct BorderGeometry {
    static func frame(
        for edge: BorderEdge,
        displayFrame: CGRect,
        gap: CGFloat,
        thickness: CGFloat
    ) -> CGRect {
        let inset = max(0, gap.rounded())
        let innerFrame = displayFrame.insetBy(dx: inset, dy: inset)
        let depth = min(
            max(1, thickness.rounded()),
            innerFrame.width / 2,
            innerFrame.height / 2
        )
        let verticalLength = max(0, innerFrame.height - (depth * 2))

        switch edge {
        case .top:
            return CGRect(
                x: innerFrame.minX,
                y: innerFrame.maxY - depth,
                width: innerFrame.width,
                height: depth
            )
        case .right:
            return CGRect(
                x: innerFrame.maxX - depth,
                y: innerFrame.minY + depth,
                width: depth,
                height: verticalLength
            )
        case .bottom:
            return CGRect(
                x: innerFrame.minX,
                y: innerFrame.minY,
                width: innerFrame.width,
                height: depth
            )
        case .left:
            return CGRect(
                x: innerFrame.minX,
                y: innerFrame.minY + depth,
                width: depth,
                height: verticalLength
            )
        }
    }
}

struct CornerGeometry {
    static func rectangles(
        for corner: CornerPosition,
        bounds: CGRect,
        thickness: CGFloat
    ) -> (horizontal: CGRect, vertical: CGRect) {
        let depth = min(
            max(1, thickness.rounded()),
            bounds.width / 2,
            bounds.height / 2
        )
        let verticalHeight = max(0, bounds.height - depth)

        switch corner {
        case .topLeft:
            return (
                CGRect(
                    x: 0,
                    y: bounds.height - depth,
                    width: bounds.width,
                    height: depth
                ),
                CGRect(x: 0, y: 0, width: depth, height: verticalHeight)
            )
        case .topRight:
            return (
                CGRect(
                    x: 0,
                    y: bounds.height - depth,
                    width: bounds.width,
                    height: depth
                ),
                CGRect(
                    x: bounds.width - depth,
                    y: 0,
                    width: depth,
                    height: verticalHeight
                )
            )
        case .bottomLeft:
            return (
                CGRect(x: 0, y: 0, width: bounds.width, height: depth),
                CGRect(
                    x: 0,
                    y: depth,
                    width: depth,
                    height: verticalHeight
                )
            )
        case .bottomRight:
            return (
                CGRect(x: 0, y: 0, width: bounds.width, height: depth),
                CGRect(
                    x: bounds.width - depth,
                    y: depth,
                    width: depth,
                    height: verticalHeight
                )
            )
        }
    }
}

@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: [HighlightPanel]] = [:]
    private var displays: [DisplayDescriptor] = []
    private var settings: AppSettings?
    private var builtHighlightStyle: HighlightStyle?
    private var activeDisplayID: CGDirectDisplayID?
    private var activeStyle: OverlayStyle = .aligned

    func rebuild(displays: [DisplayDescriptor], settings: AppSettings) {
        panels.values.flatMap { $0 }.forEach { $0.close() }
        panels.removeAll()

        self.displays = displays
        self.settings = settings
        builtHighlightStyle = settings.highlightStyle

        for display in displays {
            switch settings.highlightStyle {
            case .fullBorder:
                panels[display.id] = BorderEdge.allCases.map { edge in
                    BorderPanel(edge: edge)
                }
            case .cornerMarkers:
                panels[display.id] = CornerPosition.allCases.map { corner in
                    CornerPanel(corner: corner)
                }
            case .none:
                panels[display.id] = []
            }
        }

        refreshLayout()
    }

    func refreshLayout() {
        guard let settings else { return }

        if builtHighlightStyle != settings.highlightStyle {
            rebuild(displays: displays, settings: settings)
            return
        }

        for display in displays {
            guard let displayPanels = panels[display.id] else { continue }
            for panel in displayPanels {
                panel.configure(
                    displayFrame: display.frame,
                    settings: settings,
                    color: color(for: activeStyle, settings: settings)
                )
            }
        }

        if settings.enabled, let activeDisplayID {
            show(displayID: activeDisplayID, style: activeStyle)
        } else {
            hideAll()
        }
    }

    func show(displayID: CGDirectDisplayID, style: OverlayStyle) {
        guard let settings, settings.enabled else {
            hideAll()
            return
        }

        activeDisplayID = displayID
        activeStyle = style

        for (id, displayPanels) in panels {
            if id == displayID {
                for panel in displayPanels {
                    panel.update(
                        color: color(for: style, settings: settings),
                        opacity: settings.overlayOpacity
                    )
                    panel.orderFrontRegardless()
                }
            } else {
                displayPanels.forEach { $0.orderOut(nil) }
            }
        }
    }

    func hideAll() {
        panels.values.flatMap { $0 }.forEach { $0.orderOut(nil) }
    }

    private func color(for style: OverlayStyle, settings: AppSettings) -> NSColor {
        switch style {
        case .aligned, .guarded:
            settings.highlightColor
        case .failed:
            .systemRed
        }
    }
}

@MainActor
private class HighlightPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.contentView = contentView
        setAccessibilityElement(false)
    }

    func configure(
        displayFrame: CGRect,
        settings: AppSettings,
        color: NSColor
    ) {
        fatalError("Subclasses must implement configure(displayFrame:settings:color:)")
    }

    func update(color: NSColor, opacity: Double) {
        fatalError("Subclasses must implement update(color:opacity:)")
    }
}

@MainActor
private final class CornerPanel: HighlightPanel {
    private let corner: CornerPosition
    private let cornerView: CornerView

    init(corner: CornerPosition) {
        self.corner = corner
        cornerView = CornerView(corner: corner)
        super.init(contentView: cornerView)
    }

    override func configure(
        displayFrame: CGRect,
        settings: AppSettings,
        color: NSColor
    ) {
        let size = CGFloat(settings.cornerLength)
        let inset = CGFloat(settings.edgeGap)

        let origin: CGPoint
        switch corner {
        case .topLeft:
            origin = CGPoint(
                x: displayFrame.minX + inset,
                y: displayFrame.maxY - inset - size
            )
        case .topRight:
            origin = CGPoint(
                x: displayFrame.maxX - inset - size,
                y: displayFrame.maxY - inset - size
            )
        case .bottomLeft:
            origin = CGPoint(
                x: displayFrame.minX + inset,
                y: displayFrame.minY + inset
            )
        case .bottomRight:
            origin = CGPoint(
                x: displayFrame.maxX - inset - size,
                y: displayFrame.minY + inset
            )
        }

        setFrame(
            CGRect(origin: origin, size: CGSize(width: size, height: size)),
            display: false
        )
        cornerView.configure(
            color: color,
            thickness: CGFloat(settings.cornerThickness),
            opacity: settings.overlayOpacity
        )
    }

    override func update(color: NSColor, opacity: Double) {
        cornerView.color = color
        cornerView.markerOpacity = opacity
        cornerView.needsDisplay = true
    }
}

@MainActor
private final class BorderPanel: HighlightPanel {
    private let edge: BorderEdge
    private let edgeView: BorderEdgeView

    init(edge: BorderEdge) {
        self.edge = edge
        edgeView = BorderEdgeView(edge: edge)
        super.init(contentView: edgeView)
    }

    override func configure(
        displayFrame: CGRect,
        settings: AppSettings,
        color: NSColor
    ) {
        let thickness = CGFloat(settings.cornerThickness).rounded()
        setFrame(
            BorderGeometry.frame(
                for: edge,
                displayFrame: displayFrame,
                gap: CGFloat(settings.edgeGap),
                thickness: thickness
            ),
            display: false
        )
        edgeView.configure(
            color: color,
            thickness: thickness,
            opacity: settings.overlayOpacity
        )
    }

    override func update(color: NSColor, opacity: Double) {
        edgeView.color = color
        edgeView.markerOpacity = opacity
        edgeView.needsDisplay = true
    }
}

@MainActor
private final class CornerView: NSView {
    var color: NSColor = .systemBlue
    var markerOpacity: Double = 0.90
    private let corner: CornerPosition
    private var thickness: CGFloat = 3

    init(corner: CornerPosition) {
        self.corner = corner
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(color: NSColor, thickness: CGFloat, opacity: Double) {
        self.color = color
        self.thickness = thickness
        markerOpacity = opacity
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        color.withAlphaComponent(markerOpacity).setFill()
        let rectangles = CornerGeometry.rectangles(
            for: corner,
            bounds: bounds,
            thickness: thickness
        )
        NSBezierPath(rect: rectangles.horizontal).fill()
        NSBezierPath(rect: rectangles.vertical).fill()
    }
}

@MainActor
private final class BorderEdgeView: NSView {
    var color: NSColor = .systemBlue
    var markerOpacity: Double = 0.90
    private let edge: BorderEdge
    private var thickness: CGFloat = 3

    init(edge: BorderEdge) {
        self.edge = edge
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        color: NSColor,
        thickness: CGFloat,
        opacity: Double
    ) {
        self.color = color
        self.thickness = thickness
        markerOpacity = opacity
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let lineThickness: CGFloat
        let lineRect: CGRect

        switch edge {
        case .top, .bottom:
            lineThickness = min(thickness, bounds.height)
            lineRect = CGRect(
                x: 0,
                y: max(0, (bounds.height - lineThickness) / 2),
                width: bounds.width,
                height: lineThickness
            )
        case .left, .right:
            lineThickness = min(thickness, bounds.width)
            lineRect = CGRect(
                x: max(0, (bounds.width - lineThickness) / 2),
                y: 0,
                width: lineThickness,
                height: bounds.height
            )
        }

        context.setFillColor(color.withAlphaComponent(markerOpacity).cgColor)
        context.fill(lineRect)
    }
}
