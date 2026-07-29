import XCTest
@testable import Aqua

final class WaterLogUnitTests: XCTestCase {
    func testShortcutDoesNotDefaultTheUnit() {
        XCTAssertNil(LogWaterIntent().unit)
    }

    func testShortcutOffersOnlySupportedWaterUnits() {
        XCTAssertEqual(
            WaterLogUnit.allCases,
            [.milliliters, .liters, .fluidOunces]
        )
    }

    func testShortcutUnitsProduceTheExpectedMeasurements() {
        XCTAssertEqual(
            WaterLogUnit.milliliters.measurement(value: 1).converted(to: .milliliters).value,
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            WaterLogUnit.liters.measurement(value: 1).converted(to: .milliliters).value,
            1_000,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            WaterLogUnit.fluidOunces.measurement(value: 1).converted(to: .milliliters).value,
            29.573_5,
            accuracy: 0.000_001
        )
    }
}
