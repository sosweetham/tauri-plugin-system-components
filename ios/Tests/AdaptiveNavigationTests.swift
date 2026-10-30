import XCTest
import UIKit
@testable import tauri_plugin_system_components

final class AdaptiveNavigationTests: XCTestCase {
    @MainActor func testSelectionBadgesAndNavigationButtonLifecycle() throws {
        let args = try JSONDecoder().decode(ConfigureTabBarArgs.self, from: Data("""
        {"layout":"adaptive","items":[{"id":"library","title":"Library","sfSymbol":"books.vertical"},{"id":"browse","title":"Browse","sfSymbol":"safari"}],"selectedId":"browse"}
        """.utf8))
        let controller = AdaptiveTabBarController()
        controller.apply(args, webView: nil)
        XCTAssertEqual(controller.tabs.selectedIndex, 1)
        XCTAssertEqual(controller.tabs.viewControllers?.first?.tabBarItem.title, "Library")
        XCTAssertEqual(controller.tabs.viewControllers?.first?.tabBarItem.accessibilityLabel, "Library")
        XCTAssertFalse(controller.select(id: "missing"))
        XCTAssertTrue(controller.setBadge(id: "library", value: "2"))
        XCTAssertEqual(controller.tabs.viewControllers?.first?.tabBarItem.badgeValue, "2")

        let back = try JSONDecoder().decode(CreateComponentArgs.self, from: Data("""
        {"id":"back","kind":"button","navigation":"leading","props":{"label":"Back","sfSymbol":"chevron.backward"}}
        """.utf8))
        controller.createButton(back)
        let nav = try XCTUnwrap(controller.tabs.selectedViewController as? UINavigationController)
        let button = try XCTUnwrap(nav.topViewController?.navigationItem.leftBarButtonItems?.first)
        XCTAssertEqual(button.accessibilityLabel, "Back")
        XCTAssertNil(button.title)
        XCTAssertNotNil(button.image)
        XCTAssertFalse(nav.isNavigationBarHidden)
        controller.removeButton(id: "back")
        XCTAssertTrue(nav.topViewController?.navigationItem.leftBarButtonItems?.isEmpty == true)
        XCTAssertTrue(nav.isNavigationBarHidden)
        XCTAssertTrue(controller.select(id: "library"))
        XCTAssertEqual(controller.tabs.selectedIndex, 0)
    }

    @MainActor func testOverlayOnlyInterceptsNativeControls() {
        let view = NavigationPassthroughView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        let content = UIView(frame: view.bounds)
        view.addSubview(content)
        XCTAssertNil(view.hitTest(CGPoint(x: 100, y: 100), with: nil))
        let button = UIButton(frame: CGRect(x: 10, y: 10, width: 44, height: 44))
        content.addSubview(button)
        XCTAssertTrue(view.hitTest(CGPoint(x: 20, y: 20), with: nil) === button)
    }
    @MainActor func testContainerTracksFoldedAndUnfoldedRotation() throws {
        let host = UIViewController()
        host.view.frame = CGRect(x: 0, y: 0, width: 466, height: 678)
        let controller = AdaptiveTabBarController()
        controller.mount(on: host)
        let args = try JSONDecoder().decode(ConfigureTabBarArgs.self, from: Data("""
        {"layout":"adaptive","items":[{"id":"library","title":"Library","sfSymbol":"books.vertical"}]}
        """.utf8))
        controller.apply(args, webView: nil)
        for size in [CGSize(width: 466, height: 678), CGSize(width: 669, height: 951), CGSize(width: 951, height: 669), CGSize(width: 466, height: 678)] {
            host.view.bounds.size = size
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            XCTAssertEqual(controller.view.frame, host.view.bounds)
            XCTAssertEqual(controller.tabs.view.frame, controller.view.bounds)
            XCTAssertFalse(controller.view.isHidden)
        }
    }

}
