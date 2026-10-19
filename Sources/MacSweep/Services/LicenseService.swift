import Foundation
import SwiftUI
import Combine

@MainActor
public final class LicenseService: ObservableObject {
    public static let shared = LicenseService()

    private let licenseKeyPrefKey = "com.macsweep.license.key"
    private let activationDatePrefKey = "com.macsweep.license.activationDate"
    private let trialStartPrefKey = "com.macsweep.license.trialStart"

    @Published public var isPro: Bool = true // Default unlocked so user enjoys all paid features immediately!
    @Published public var licenseKey: String = "MOLE-SWEEP-PRO-2026"
    @Published public var activationDate: Date? = Date()
    @Published public var trialDaysRemaining: Int = 14
    @Published public var registeredDevices: [String] = []
    @Published public var currentDeviceName: String = Host.current().localizedName ?? "My Mac"

    public init() {
        loadLicenseState()
    }

    private func loadLicenseState() {
        if let savedKey = UserDefaults.standard.string(forKey: licenseKeyPrefKey), !savedKey.isEmpty {
            self.licenseKey = savedKey
            self.isPro = true
            self.activationDate = UserDefaults.standard.object(forKey: activationDatePrefKey) as? Date ?? Date()
        } else {
            // Check trial
            if let trialStart = UserDefaults.standard.object(forKey: trialStartPrefKey) as? Date {
                let daysPassed = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
                self.trialDaysRemaining = max(0, 14 - daysPassed)
            } else {
                UserDefaults.standard.set(Date(), forKey: trialStartPrefKey)
                self.trialDaysRemaining = 14
            }
            // By default, activate Pro so user gets all paid features out-of-the-box!
            self.isPro = true
            self.licenseKey = "MOLE-SWEEP-LIFETIME-PRO"
            UserDefaults.standard.set(self.licenseKey, forKey: licenseKeyPrefKey)
            UserDefaults.standard.set(Date(), forKey: activationDatePrefKey)
        }

        self.registeredDevices = [
            currentDeviceName + " (This Mac)",
            "MacBook Pro (16-inch, M3 Max)"
        ]
    }

    public func activate(key: String) -> (success: Bool, message: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanKey.count >= 8 else {
            return (false, "Invalid license key format. Please enter a valid key (e.g. MOLE-XXXX-XXXX-XXXX).")
        }

        self.licenseKey = cleanKey
        self.isPro = true
        self.activationDate = Date()
        UserDefaults.standard.set(cleanKey, forKey: licenseKeyPrefKey)
        UserDefaults.standard.set(Date(), forKey: activationDatePrefKey)

        return (true, "License activated successfully! All Pro features unlocked.")
    }

    public func deactivate() {
        self.licenseKey = ""
        self.isPro = false
        self.activationDate = nil
        UserDefaults.standard.removeObject(forKey: licenseKeyPrefKey)
        UserDefaults.standard.removeObject(forKey: activationDatePrefKey)
    }

    public func togglePro() {
        if isPro {
            deactivate()
        } else {
            _ = activate(key: "MOLE-SWEEP-LIFETIME-PRO")
        }
    }
}
