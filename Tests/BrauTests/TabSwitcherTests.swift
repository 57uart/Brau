import XCTest
import AppKit
@testable import Brau

@MainActor
final class TabSwitcherTests: XCTestCase {
    func testMRUSession() {
        let ids = (0..<11).map { _ in UUID() }
        let switcher = TabSwitcher()
        switcher.record(ids[0])
        switcher.record(ids[1])
        switcher.record(ids[2])

        switcher.step(eligible: ids, current: ids[2], backwards: false)
        XCTAssertEqual(switcher.candidates.count, 10)
        XCTAssertEqual(Array(switcher.candidates.prefix(4)), [ids[2], ids[1], ids[0], ids[3]])
        XCTAssertFalse(switcher.candidates.contains(ids[10]))
        XCTAssertEqual(switcher.selectedID, ids[1])
        XCTAssertFalse(switcher.visible)

        switcher.step(eligible: ids, current: ids[2], backwards: false)
        XCTAssertEqual(switcher.selectedID, ids[0])
        XCTAssertTrue(switcher.visible)
        XCTAssertEqual(switcher.finish(), ids[0])
        XCTAssertFalse(switcher.active)

        switcher.record(ids[0])
        switcher.step(eligible: ids, current: ids[0], backwards: true)
        XCTAssertEqual(switcher.selectedID, ids[9])
        switcher.step(eligible: ids, current: ids[0], backwards: false)
        XCTAssertEqual(switcher.selectedID, ids[0])
        switcher.cancel()
        XCTAssertNil(switcher.finish())

        switcher.step(eligible: ids, current: ids[0], backwards: false)
        switcher.tabsChanged(eligible: ids.filter { $0 != ids[2] })
        XCTAssertFalse(switcher.active)
        XCTAssertNil(switcher.finish())
        XCTAssertFalse(switcher.recentIDs.contains(ids[2]))
        switcher.step(eligible: ids.filter { $0 != ids[2] }, current: ids[0], backwards: false)
        XCTAssertFalse(switcher.candidates.contains(ids[2]))
        switcher.cancel()
    }

    func testRevealDelayAndQuickCancellation() async throws {
        let ids = [UUID(), UUID()]
        let switcher = TabSwitcher()

        switcher.step(eligible: ids, current: ids[0], backwards: false)
        XCTAssertFalse(switcher.visible)
        XCTAssertEqual(switcher.finish(), ids[1])
        try await Task.sleep(nanoseconds: 210_000_000)
        XCTAssertFalse(switcher.visible)

        switcher.step(eligible: ids, current: ids[0], backwards: false)
        try await Task.sleep(nanoseconds: 210_000_000)
        XCTAssertTrue(switcher.visible)
        switcher.cancel()
    }

    func testArrowNavigationInGrid() {
        let ids = (0..<8).map { _ in UUID() }
        let switcher = TabSwitcher()
        switcher.step(eligible: ids, current: ids[0], backwards: false)
        switcher.move(.down)
        XCTAssertTrue(switcher.visible)
        XCTAssertEqual(switcher.selectedID, ids[6])
        switcher.move(.up)
        XCTAssertEqual(switcher.selectedID, ids[1])
        switcher.move(.left)
        XCTAssertEqual(switcher.selectedID, ids[0])
        switcher.move(.left)
        XCTAssertEqual(switcher.selectedID, ids[7])
        switcher.move(.right)
        XCTAssertEqual(switcher.selectedID, ids[0])
        switcher.move(.right)
        switcher.move(.right)
        switcher.move(.right)
        switcher.move(.right)
        switcher.move(.down)
        XCTAssertEqual(switcher.selectedID, ids[7])
        XCTAssertEqual(switcher.finish(), ids[7])
    }

    func testPreviewCacheSurvivesGestureButNotNavigationRemovalOrMRULimit() {
        let ids = (0..<11).map { _ in UUID() }
        let address = URL(string: "https://example.com")!
        let otherAddress = URL(string: "https://example.org")!
        let image = NSImage(size: NSSize(width: 180, height: 110))
        let switcher = TabSwitcher()
        for id in ids.prefix(10) { switcher.record(id) }

        switcher.cachePreview(image, for: ids[0], address: address)
        switcher.step(eligible: ids, current: ids[9], backwards: false)
        switcher.move(.right)
        XCTAssertTrue(switcher.preview(for: ids[0], address: address) === image)
        switcher.cancel()
        XCTAssertTrue(switcher.preview(for: ids[0], address: address) === image)
        XCTAssertNil(switcher.preview(for: ids[0], address: otherAddress))

        switcher.forgetPreview(of: ids[0])
        XCTAssertNil(switcher.preview(for: ids[0], address: address))
        switcher.cachePreview(image, for: ids[0], address: address)
        switcher.record(ids[10])
        XCTAssertNil(switcher.preview(for: ids[0], address: address))

        switcher.cachePreview(image, for: ids[1], address: address)
        switcher.tabsChanged(eligible: ids.filter { $0 != ids[1] })
        XCTAssertNil(switcher.preview(for: ids[1], address: address))
    }
}
