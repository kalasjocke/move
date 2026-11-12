import CoreGraphics

/// Converts a rectangle between AppKit coordinates (origin at the bottom left
/// of the main screen, y up) and Accessibility coordinates (origin at the top
/// left of the main screen, y down). The conversion is its own inverse.
public func flip(_ rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
    CGRect(
        x: rect.minX,
        y: mainScreenHeight - rect.maxY,
        width: rect.width,
        height: rect.height
    )
}

/// The pixel rectangle for a frame inside a usable area, both in
/// Accessibility coordinates. Each edge is rounded on its own, so frames that
/// share an edge, such as two halves, meet exactly.
public func target(_ frame: Frame, in area: CGRect) -> CGRect {
    let left = (area.minX + frame.x * area.width).rounded()
    let right = (area.minX + (frame.x + frame.w) * area.width).rounded()
    let top = (area.minY + frame.y * area.height).rounded()
    let bottom = (area.minY + (frame.y + frame.h) * area.height).rounded()
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
}

/// The index of the screen that contains a point, or else the screen closest
/// to it. Screens and point are in the same coordinates. Returns nil only when
/// there are no screens.
public func screenIndex(containing point: CGPoint, in screens: [CGRect]) -> Int? {
    if let index = screens.firstIndex(where: { $0.contains(point) }) {
        return index
    }
    return screens.indices.min { distance(point, screens[$0]) < distance(point, screens[$1]) }
}

private func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return dx * dx + dy * dy
}
