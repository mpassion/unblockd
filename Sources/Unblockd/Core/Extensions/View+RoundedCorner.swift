import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPathWrapper.roundedRect(rect, byRoundingCorners: corners, cornerRadius: radius)
        return Path(path)
    }
}

struct RectCorner: OptionSet, Sendable {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)

    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct UIBezierPathWrapper {
    static func roundedRect(_ rect: CGRect, byRoundingCorners corners: RectCorner, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()

        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: topLeft.x + cornerRadius, y: topLeft.y))
        } else {
            path.move(to: topLeft)
        }

        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: topRight.x - cornerRadius, y: topRight.y))
            path.addArc(center: CGPoint(x: topRight.x - cornerRadius, y: topRight.y + cornerRadius), radius: cornerRadius, startAngle: -.pi/2, endAngle: 0, clockwise: false)
        } else {
            path.addLine(to: topRight)
        }

        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - cornerRadius))
             path.addArc(center: CGPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: .pi/2, clockwise: false)
        } else {
            path.addLine(to: bottomRight)
        }

        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y))
            path.addArc(center: CGPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y - cornerRadius), radius: cornerRadius, startAngle: .pi/2, endAngle: .pi, clockwise: false)
        } else {
            path.addLine(to: bottomLeft)
        }

        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + cornerRadius))
            path.addArc(center: CGPoint(x: topLeft.x + cornerRadius, y: topLeft.y + cornerRadius), radius: cornerRadius, startAngle: .pi, endAngle: -.pi/2, clockwise: false)
        } else {
            path.addLine(to: topLeft)
        }

        path.closeSubpath()
        return path
    }
}
