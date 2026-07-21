import SwiftUI

private struct WaterVolumeUnitEnvironmentKey: EnvironmentKey {
    static let defaultValue: WaterVolumeUnit = .metric
}

extension EnvironmentValues {
    var waterVolumeUnit: WaterVolumeUnit {
        get { self[WaterVolumeUnitEnvironmentKey.self] }
        set { self[WaterVolumeUnitEnvironmentKey.self] = newValue }
    }
}
