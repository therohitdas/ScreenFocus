// SPDX-License-Identifier: MPL-2.0

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

struct TopBorderLayout: Equatable {
    struct CutoutRoute: Equatable {
        let leftX: CGFloat
        let rightX: CGFloat
        let bottomY: CGFloat
        let cornerRadius: CGFloat
    }

    let frame: CGRect
    let lineThickness: CGFloat
    let topY: CGFloat
    let cutoutRoute: CutoutRoute?
}

struct TopBorderGeometry {
    static func layout(
        displayFrame: CGRect,
        cutoutFrame: CGRect?,
        gap: CGFloat,
        thickness: CGFloat
    ) -> TopBorderLayout {
        let straightFrame = BorderGeometry.frame(
            for: .top,
            displayFrame: displayFrame,
            gap: gap,
            thickness: thickness
        )
        let depth = straightFrame.height
        let straightLayout = TopBorderLayout(
            frame: straightFrame,
            lineThickness: depth,
            topY: depth / 2,
            cutoutRoute: nil
        )

        guard
            let cutoutFrame,
            !cutoutFrame.isNull,
            cutoutFrame.width > 0,
            cutoutFrame.height > 0
        else {
            return straightLayout
        }

        let cutout = cutoutFrame.intersection(displayFrame)
        guard
            !cutout.isNull,
            cutout.width > 0,
            cutout.height > 0,
            straightFrame.maxY > cutout.minY
        else {
            return straightLayout
        }

        let inset = max(0, gap.rounded())
        let innerFrame = displayFrame.insetBy(dx: inset, dy: inset)
        let topCenter = innerFrame.maxY - (depth / 2)
        let leftCenter = cutout.minX - inset - (depth / 2)
        let rightCenter = cutout.maxX + inset + (depth / 2)
        let bottomCenter = cutout.minY - inset - (depth / 2)

        guard
            leftCenter > innerFrame.minX,
            rightCenter < innerFrame.maxX,
            leftCenter < rightCenter,
            bottomCenter > innerFrame.minY,
            bottomCenter < topCenter
        else {
            return straightLayout
        }

        let panelMinY = bottomCenter - (depth / 2)
        let panelFrame = CGRect(
            x: innerFrame.minX,
            y: panelMinY,
            width: innerFrame.width,
            height: innerFrame.maxY - panelMinY
        )
        let localTopY = topCenter - panelMinY
        let localBottomY = bottomCenter - panelMinY
        let localLeftX = leftCenter - innerFrame.minX
        let localRightX = rightCenter - innerFrame.minX
        let radius = min(
            12,
            (localTopY - localBottomY) / 3,
            (localRightX - localLeftX) / 4
        )

        return TopBorderLayout(
            frame: panelFrame,
            lineThickness: depth,
            topY: localTopY,
            cutoutRoute: TopBorderLayout.CutoutRoute(
                leftX: localLeftX,
                rightX: localRightX,
                bottomY: localBottomY,
                cornerRadius: max(0, radius)
            )
        )
    }

    static func path(
        for layout: TopBorderLayout,
        bounds: CGRect
    ) -> CGPath? {
        guard let route = layout.cutoutRoute else {
            return nil
        }

        let radius = route.cornerRadius
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: layout.topY))
        path.addLine(
            to: CGPoint(
                x: route.leftX - radius,
                y: layout.topY
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: route.leftX,
                y: layout.topY - radius
            ),
            control: CGPoint(x: route.leftX, y: layout.topY)
        )
        path.addLine(
            to: CGPoint(
                x: route.leftX,
                y: route.bottomY + radius
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: route.leftX + radius,
                y: route.bottomY
            ),
            control: CGPoint(x: route.leftX, y: route.bottomY)
        )
        path.addLine(
            to: CGPoint(
                x: route.rightX - radius,
                y: route.bottomY
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: route.rightX,
                y: route.bottomY + radius
            ),
            control: CGPoint(x: route.rightX, y: route.bottomY)
        )
        path.addLine(
            to: CGPoint(
                x: route.rightX,
                y: layout.topY - radius
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: route.rightX + radius,
                y: layout.topY
            ),
            control: CGPoint(x: route.rightX, y: layout.topY)
        )
        path.addLine(to: CGPoint(x: bounds.width, y: layout.topY))
        return path
    }
}

struct BuiltInBorderLayout: Equatable {
    let frame: CGRect
    let lineThickness: CGFloat
    let perimeter: CGRect
    let cornerRadius: CGFloat
    let cutoutRoute: TopBorderLayout.CutoutRoute?
}

struct BuiltInBorderGeometry {
    static let recommendedCornerRadius: CGFloat = 14

    static func layout(
        displayFrame: CGRect,
        cutoutFrame: CGRect?,
        gap: CGFloat,
        thickness: CGFloat
    ) -> BuiltInBorderLayout {
        let inset = max(0, gap.rounded())
        let frame = displayFrame.insetBy(dx: inset, dy: inset)
        let lineThickness = min(
            max(1, thickness.rounded()),
            frame.width / 2,
            frame.height / 2
        )
        let halfThickness = lineThickness / 2
        let perimeter = CGRect(origin: .zero, size: frame.size).insetBy(
            dx: halfThickness,
            dy: halfThickness
        )
        let cornerRadius = min(
            recommendedCornerRadius,
            perimeter.width / 2,
            perimeter.height / 2
        )
        let topLayout = TopBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: cutoutFrame,
            gap: gap,
            thickness: thickness
        )
        let cutoutRoute = topLayout.cutoutRoute.map { route in
            TopBorderLayout.CutoutRoute(
                leftX: topLayout.frame.minX + route.leftX - frame.minX,
                rightX: topLayout.frame.minX + route.rightX - frame.minX,
                bottomY: topLayout.frame.minY + route.bottomY - frame.minY,
                cornerRadius: route.cornerRadius
            )
        }

        return BuiltInBorderLayout(
            frame: frame,
            lineThickness: lineThickness,
            perimeter: perimeter,
            cornerRadius: max(0, cornerRadius),
            cutoutRoute: cutoutRoute
        )
    }

    static func path(for layout: BuiltInBorderLayout) -> CGPath {
        let perimeter = layout.perimeter
        let radius = layout.cornerRadius
        let path = CGMutablePath()

        path.move(
            to: CGPoint(
                x: perimeter.minX,
                y: perimeter.minY + radius
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: perimeter.minX + radius,
                y: perimeter.minY
            ),
            control: CGPoint(x: perimeter.minX, y: perimeter.minY)
        )
        path.addLine(
            to: CGPoint(
                x: perimeter.maxX - radius,
                y: perimeter.minY
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: perimeter.maxX,
                y: perimeter.minY + radius
            ),
            control: CGPoint(x: perimeter.maxX, y: perimeter.minY)
        )
        path.addLine(
            to: CGPoint(
                x: perimeter.maxX,
                y: perimeter.maxY - radius
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: perimeter.maxX - radius,
                y: perimeter.maxY
            ),
            control: CGPoint(x: perimeter.maxX, y: perimeter.maxY)
        )

        if let route = layout.cutoutRoute {
            let cutoutRadius = route.cornerRadius
            path.addLine(
                to: CGPoint(
                    x: route.rightX + cutoutRadius,
                    y: perimeter.maxY
                )
            )
            path.addQuadCurve(
                to: CGPoint(
                    x: route.rightX,
                    y: perimeter.maxY - cutoutRadius
                ),
                control: CGPoint(x: route.rightX, y: perimeter.maxY)
            )
            path.addLine(
                to: CGPoint(
                    x: route.rightX,
                    y: route.bottomY + cutoutRadius
                )
            )
            path.addQuadCurve(
                to: CGPoint(
                    x: route.rightX - cutoutRadius,
                    y: route.bottomY
                ),
                control: CGPoint(x: route.rightX, y: route.bottomY)
            )
            path.addLine(
                to: CGPoint(
                    x: route.leftX + cutoutRadius,
                    y: route.bottomY
                )
            )
            path.addQuadCurve(
                to: CGPoint(
                    x: route.leftX,
                    y: route.bottomY + cutoutRadius
                ),
                control: CGPoint(x: route.leftX, y: route.bottomY)
            )
            path.addLine(
                to: CGPoint(
                    x: route.leftX,
                    y: perimeter.maxY - cutoutRadius
                )
            )
            path.addQuadCurve(
                to: CGPoint(
                    x: route.leftX - cutoutRadius,
                    y: perimeter.maxY
                ),
                control: CGPoint(x: route.leftX, y: perimeter.maxY)
            )
        }

        path.addLine(
            to: CGPoint(
                x: perimeter.minX + radius,
                y: perimeter.maxY
            )
        )
        path.addQuadCurve(
            to: CGPoint(
                x: perimeter.minX,
                y: perimeter.maxY - radius
            ),
            control: CGPoint(x: perimeter.minX, y: perimeter.maxY)
        )
        path.closeSubpath()
        return path
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
                if display.isBuiltIn {
                    panels[display.id] = [BuiltInBorderPanel()]
                } else {
                    panels[display.id] = BorderEdge.allCases.map { edge in
                        if edge == .top {
                            TopBorderPanel()
                        } else {
                            BorderPanel(edge: edge)
                        }
                    }
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
                    display: display,
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
        display: DisplayDescriptor,
        settings: AppSettings,
        color: NSColor
    ) {
        fatalError("Subclasses must implement configure(display:settings:color:)")
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
        display: DisplayDescriptor,
        settings: AppSettings,
        color: NSColor
    ) {
        let displayFrame = display.frame
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
private final class BuiltInBorderPanel: HighlightPanel {
    private let borderView = BuiltInBorderView()

    init() {
        super.init(contentView: borderView)
    }

    override func configure(
        display: DisplayDescriptor,
        settings: AppSettings,
        color: NSColor
    ) {
        let layout = BuiltInBorderGeometry.layout(
            displayFrame: display.frame,
            cutoutFrame: display.cutout?.frame,
            gap: CGFloat(settings.edgeGap),
            thickness: CGFloat(settings.cornerThickness)
        )
        setFrame(layout.frame, display: false)
        borderView.configure(
            layout: layout,
            color: color,
            opacity: settings.overlayOpacity
        )
    }

    override func update(color: NSColor, opacity: Double) {
        borderView.color = color
        borderView.markerOpacity = opacity
        borderView.needsDisplay = true
    }
}

@MainActor
private final class TopBorderPanel: HighlightPanel {
    private let borderView = TopBorderView()

    init() {
        super.init(contentView: borderView)
    }

    override func configure(
        display: DisplayDescriptor,
        settings: AppSettings,
        color: NSColor
    ) {
        let layout = TopBorderGeometry.layout(
            displayFrame: display.frame,
            cutoutFrame: display.cutout?.frame,
            gap: CGFloat(settings.edgeGap),
            thickness: CGFloat(settings.cornerThickness)
        )
        setFrame(layout.frame, display: false)
        borderView.configure(
            layout: layout,
            color: color,
            opacity: settings.overlayOpacity
        )
    }

    override func update(color: NSColor, opacity: Double) {
        borderView.color = color
        borderView.markerOpacity = opacity
        borderView.needsDisplay = true
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
        display: DisplayDescriptor,
        settings: AppSettings,
        color: NSColor
    ) {
        let thickness = CGFloat(settings.cornerThickness).rounded()
        setFrame(
            BorderGeometry.frame(
                for: edge,
                displayFrame: display.frame,
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
private final class BuiltInBorderView: NSView {
    var color: NSColor = .systemBlue
    var markerOpacity: Double = 0.90
    private var layout: BuiltInBorderLayout?

    init() {
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        layout: BuiltInBorderLayout,
        color: NSColor,
        opacity: Double
    ) {
        self.layout = layout
        self.color = color
        markerOpacity = opacity
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard
            let context = NSGraphicsContext.current?.cgContext,
            let layout
        else {
            return
        }

        context.setShouldAntialias(true)
        context.setStrokeColor(color.withAlphaComponent(markerOpacity).cgColor)
        context.setLineWidth(layout.lineThickness)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(BuiltInBorderGeometry.path(for: layout))
        context.strokePath()
    }
}

@MainActor
private final class TopBorderView: NSView {
    var color: NSColor = .systemBlue
    var markerOpacity: Double = 0.90
    private var layout: TopBorderLayout?

    init() {
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        layout: TopBorderLayout,
        color: NSColor,
        opacity: Double
    ) {
        self.layout = layout
        self.color = color
        markerOpacity = opacity
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard
            let context = NSGraphicsContext.current?.cgContext,
            let layout
        else {
            return
        }

        context.setFillColor(color.withAlphaComponent(markerOpacity).cgColor)

        guard layout.cutoutRoute != nil else {
            context.fill(
                CGRect(
                    x: 0,
                    y: layout.topY - (layout.lineThickness / 2),
                    width: bounds.width,
                    height: layout.lineThickness
                )
            )
            return
        }

        guard let path = TopBorderGeometry.path(for: layout, bounds: bounds) else {
            return
        }

        context.setShouldAntialias(true)
        context.setStrokeColor(color.withAlphaComponent(markerOpacity).cgColor)
        context.setLineWidth(layout.lineThickness)
        context.setLineJoin(.round)
        context.setLineCap(.butt)
        context.addPath(path)
        context.strokePath()
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
