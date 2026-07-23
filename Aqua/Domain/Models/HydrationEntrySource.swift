enum HydrationEntrySource: String, Codable, CaseIterable, Sendable {
    case manual
    case quickAdd
    case appIntent
    case shortcut
    case widget
    case healthKit
    case foundationModelTool
    case plan
}
