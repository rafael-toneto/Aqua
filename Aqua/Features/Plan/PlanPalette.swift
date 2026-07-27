import SwiftUI

/// Visual tokens used by the Plan experience.
///
/// These values intentionally mirror the palette used by Today and History so
/// the three hydration-focused tabs feel like one continuous experience.
struct PlanPalette {
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

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(red: 0.025, green: 0.075, blue: 0.12)
            controlBackground = Color(red: 0.035, green: 0.12, blue: 0.18)
            meterTrack = Color(red: 0.045, green: 0.12, blue: 0.20)
            primary = Color(red: 0.81, green: 0.91, blue: 0.96)
            secondary = Color(red: 0.30, green: 0.55, blue: 0.68)
            divider = Color(red: 0.10, green: 0.25, blue: 0.34)
            accent = Color(red: 0.05, green: 0.78, blue: 0.94)
            success = Color(red: 0.30, green: 0.82, blue: 0.58)
            warning = Color(red: 0.96, green: 0.66, blue: 0.28)
            danger = Color(red: 0.96, green: 0.40, blue: 0.42)
        } else {
            background = Color(red: 0.95, green: 0.98, blue: 0.99)
            controlBackground = Color.white.opacity(0.82)
            meterTrack = Color(red: 0.86, green: 0.92, blue: 0.95)
            primary = Color(red: 0.05, green: 0.16, blue: 0.22)
            secondary = Color(red: 0.27, green: 0.47, blue: 0.57)
            divider = Color(red: 0.76, green: 0.86, blue: 0.90)
            accent = Color(red: 0.00, green: 0.56, blue: 0.76)
            success = Color(red: 0.08, green: 0.58, blue: 0.36)
            warning = Color(red: 0.76, green: 0.42, blue: 0.06)
            danger = Color(red: 0.78, green: 0.20, blue: 0.23)
        }
    }
}
