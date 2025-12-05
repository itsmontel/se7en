import DeviceActivity

// MARK: - DeviceActivity Extensions

extension DeviceActivityName {
    static let se7enDaily = DeviceActivityName("se7en.daily")
}

extension DeviceActivityEvent.Name {
    static func warning(for bundleID: String) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("warning.\(bundleID)")
    }
    
    static func limit(for bundleID: String) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("limit.\(bundleID)")
    }
}
