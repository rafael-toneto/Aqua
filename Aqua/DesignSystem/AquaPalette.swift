import SwiftUI

/// Semantic colors shared by every AquaFlow screen.
///
/// Neutral colors carry the layout hierarchy while the brand blue is reserved
/// for interactive controls, navigation selection, and hydration progress.
struct AquaPalette {
    let background: Color
    let controlBackground: Color
    let meterTrack: Color
    let primary: Color
    let secondary: Color
    let divider: Color
    let accent: Color
    let success: Color
    let warning: Color
    let danger: Color
    let prominentButtonForeground: Color

    var error: Color { danger }

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(red: 0.055, green: 0.067, blue: 0.071)
            controlBackground = Color(red: 0.094, green: 0.114, blue: 0.122)
            meterTrack = Color(red: 0.153, green: 0.184, blue: 0.196)
            primary = Color(red: 0.941, green: 0.957, blue: 0.961)
            secondary = Color(red: 0.655, green: 0.702, blue: 0.722)
            divider = Color(red: 0.188, green: 0.227, blue: 0.243)
            accent = Color(red: 0.20, green: 0.71, blue: 0.85)
            success = Color(red: 0.29, green: 0.78, blue: 0.55)
            warning = Color(red: 0.94, green: 0.67, blue: 0.33)
            danger = Color(red: 0.95, green: 0.42, blue: 0.45)
            prominentButtonForeground = Color(red: 0.055, green: 0.067, blue: 0.071)
        } else {
            background = Color(red: 0.957, green: 0.965, blue: 0.965)
            controlBackground = .white
            meterTrack = Color(red: 0.886, green: 0.906, blue: 0.910)
            primary = Color(red: 0.086, green: 0.125, blue: 0.137)
            secondary = Color(red: 0.353, green: 0.404, blue: 0.424)
            divider = Color(red: 0.835, green: 0.863, blue: 0.867)
            accent = Color(red: 0.03, green: 0.49, blue: 0.64)
            success = Color(red: 0.14, green: 0.53, blue: 0.36)
            warning = Color(red: 0.68, green: 0.40, blue: 0.09)
            danger = Color(red: 0.72, green: 0.24, blue: 0.26)
            prominentButtonForeground = .white
        }
    }
}

typealias TodayPalette = AquaPalette
typealias HistoryPalette = AquaPalette
typealias InsightsPalette = AquaPalette
typealias PlanPalette = AquaPalette
typealias AddWaterPalette = AquaPalette
typealias SettingsPalette = AquaPalette
