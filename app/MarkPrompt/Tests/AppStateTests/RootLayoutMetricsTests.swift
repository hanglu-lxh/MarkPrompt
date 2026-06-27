import CoreGraphics
@testable import MarkPromptKit
import XCTest

final class RootLayoutMetricsTests: XCTestCase {
    func testInspectorWidthDragDirectionAndBounds() {
        XCTAssertEqual(
            RootLayoutMetrics.inspectorWidth(startingWidth: 360, dragTranslationX: -80),
            440,
            accuracy: 0.01
        )
        XCTAssertEqual(
            RootLayoutMetrics.inspectorWidth(startingWidth: 360, dragTranslationX: 120),
            RootLayoutMetrics.minimumInspectorWidth,
            accuracy: 0.01
        )
        XCTAssertEqual(
            RootLayoutMetrics.clampedInspectorWidth(900),
            RootLayoutMetrics.maximumInspectorWidth,
            accuracy: 0.01
        )
    }
}
