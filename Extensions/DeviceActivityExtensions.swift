import DeviceActivity

// MARK: - DeviceActivity Extensions

extension DeviceActivityName {
    static let se7enDaily = DeviceActivityName("se7en.daily")
}

extension DeviceActivityEvent.Name {
    static func warningEvent(for bundleID: String) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("se7en.warning.\(bundleID)")
    }
    
    static func limitEvent(for bundleID: String) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("se7en.limit.\(bundleID)")
    }
}
