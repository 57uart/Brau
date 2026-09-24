import XCTest
import AppKit
@testable import mnml

final class FloatTests: XCTestCase {
    private let area = NSRect(x: 0, y: 0, width: 1000, height: 600)
    private let size = NSSize(width: 200, height: 100)

    private func at(_ x: CGFloat, _ y: CGFloat) -> NSRect { NSRect(origin: NSPoint(x: x, y: y), size: size) }

    func testFlicksGoToCorners() {
        let bottomRight = at(776, 24)
        // Up from bottom right: top right.
        XCTAssertEqual(mnml.Float.corner(for: bottomRight, in: area, toward: CGVector(dx: 2, dy: 40)), NSPoint(x: 776, y: 476))
        // Left from top right: top left.
        XCTAssertEqual(mnml.Float.corner(for: at(776, 476), in: area, toward: CGVector(dx: -40, dy: 5)), NSPoint(x: 24, y: 476))
        // Down from top left: bottom left.
        XCTAssertEqual(mnml.Float.corner(for: at(24, 476), in: area, toward: CGVector(dx: 0, dy: -30)), NSPoint(x: 24, y: 24))
        // Right from bottom left: back to bottom right.
        XCTAssertEqual(mnml.Float.corner(for: at(24, 24), in: area, toward: CGVector(dx: 30, dy: 0)), bottomRight.origin)
    }

    func testFromAnywhereToTheNearerCorner() {
        // Dragged somewhere near the top left, then flicked right: top right.
        XCTAssertEqual(mnml.Float.corner(for: at(150, 400), in: area, toward: CGVector(dx: 50, dy: -10)), NSPoint(x: 776, y: 476))
        // Near the bottom right, flicked up: top right.
        XCTAssertEqual(mnml.Float.corner(for: at(700, 60), in: area, toward: CGVector(dx: 0, dy: 50)), NSPoint(x: 776, y: 476))
    }
}
