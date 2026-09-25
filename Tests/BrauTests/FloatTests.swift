import XCTest
import AppKit
@testable import Brau

final class FloatTests: XCTestCase {
    private let area = NSRect(x: 0, y: 0, width: 1000, height: 600)
    private let size = NSSize(width: 200, height: 100)

    private func at(_ x: CGFloat, _ y: CGFloat) -> NSRect { NSRect(origin: NSPoint(x: x, y: y), size: size) }

    func testFlicksGoToCorners() {
        let bottomRight = at(788, 12)
        // Up from bottom right: top right.
        XCTAssertEqual(Brau.Float.corner(for: bottomRight, in: area, toward: CGVector(dx: 2, dy: 40)), NSPoint(x: 788, y: 488))
        // Left from top right: top left.
        XCTAssertEqual(Brau.Float.corner(for: at(788, 488), in: area, toward: CGVector(dx: -40, dy: 5)), NSPoint(x: 12, y: 488))
        // Down from top left: bottom left.
        XCTAssertEqual(Brau.Float.corner(for: at(12, 488), in: area, toward: CGVector(dx: 0, dy: -30)), NSPoint(x: 12, y: 12))
        // Right from bottom left: back to bottom right.
        XCTAssertEqual(Brau.Float.corner(for: at(12, 12), in: area, toward: CGVector(dx: 30, dy: 0)), bottomRight.origin)
    }

    func testDiagonalSwipes() {
        // Bottom right, up and to the left at 45°: straight to top left.
        XCTAssertEqual(Brau.Float.corner(for: at(788, 12), in: area, toward: CGVector(dx: -30, dy: 30)), NSPoint(x: 12, y: 488))
        // Top left, down and to the right at about 35°: bottom right.
        XCTAssertEqual(Brau.Float.corner(for: at(12, 488), in: area, toward: CGVector(dx: 40, dy: -28)), NSPoint(x: 788, y: 12))
        // About 25° off straight up still counts as diagonal: top left.
        XCTAssertEqual(Brau.Float.corner(for: at(788, 12), in: area, toward: CGVector(dx: -20, dy: 43)), NSPoint(x: 12, y: 488))
        // Mostly up with a little left (about 15°): only up, on its own side.
        XCTAssertEqual(Brau.Float.corner(for: at(788, 12), in: area, toward: CGVector(dx: -10, dy: 40)), NSPoint(x: 788, y: 488))
    }

    func testFromAnywhereToTheNearerCorner() {
        // Dragged somewhere near the top left, then flicked right: top right.
        XCTAssertEqual(Brau.Float.corner(for: at(150, 400), in: area, toward: CGVector(dx: 50, dy: -10)), NSPoint(x: 788, y: 488))
        // Near the bottom right, flicked up: top right.
        XCTAssertEqual(Brau.Float.corner(for: at(700, 60), in: area, toward: CGVector(dx: 0, dy: 50)), NSPoint(x: 788, y: 488))
    }
}
