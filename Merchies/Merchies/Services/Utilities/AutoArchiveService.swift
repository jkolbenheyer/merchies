import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

class AutoArchiveService: ObservableObject {
    @Published var isAutoArchiveEnabled = false
    @Published var lastAutoArchiveDate: Date?
    @Published var autoArchiveCount = 0
    
    private let firestoreService = FirestoreService()
    private var autoArchiveTimer: Timer?
    
    init() {
        loadAutoArchiveSettings()
        setupAutoArchiveTimer()
    }
    
    deinit {
        autoArchiveTimer?.invalidate()
    }
    
    // MARK: - Settings Management
    
    private func loadAutoArchiveSettings() {
        isAutoArchiveEnabled = UserDefaults.standard.bool(forKey: "autoArchiveEnabled")
        if let lastDate = UserDefaults.standard.object(forKey: "lastAutoArchiveDate") as? Date {
            lastAutoArchiveDate = lastDate
        }
        autoArchiveCount = UserDefaults.standard.integer(forKey: "autoArchiveCount")
    }
    
    private func saveAutoArchiveSettings() {
        UserDefaults.standard.set(isAutoArchiveEnabled, forKey: "autoArchiveEnabled")
        if let lastDate = lastAutoArchiveDate {
            UserDefaults.standard.set(lastDate, forKey: "lastAutoArchiveDate")
        }
        UserDefaults.standard.set(autoArchiveCount, forKey: "autoArchiveCount")
    }
    
    func toggleAutoArchive() {
        isAutoArchiveEnabled.toggle()
        saveAutoArchiveSettings()
        
        if isAutoArchiveEnabled {
            setupAutoArchiveTimer()
        } else {
            autoArchiveTimer?.invalidate()
            autoArchiveTimer = nil
        }
        
        print(isAutoArchiveEnabled ? "✅ Auto-archive enabled" : "❌ Auto-archive disabled")
    }
    
    // MARK: - Auto Archive Timer
    
    private func setupAutoArchiveTimer() {
        guard isAutoArchiveEnabled else { return }
        
        // Check every hour
        autoArchiveTimer?.invalidate()
        autoArchiveTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performAutoArchiveCheck()
        }
        
        print("🕐 Auto-archive timer setup - checking every hour")
    }
    
    private func performAutoArchiveCheck() {
        guard isAutoArchiveEnabled else { return }
        
        // Only run once per day
        let now = Date()
        if let lastRun = lastAutoArchiveDate {
            let calendar = Calendar.current
            if calendar.isDate(lastRun, inSameDayAs: now) {
                return // Already ran today
            }
        }
        
        print("🔄 Performing auto-archive check...")
        
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user for auto-archive")
            return
        }
        
        runAutoArchive(for: currentUser.uid)
    }
    
    // MARK: - Manual Archive Operations
    
    func runAutoArchive(for merchantId: String) {
        print("🗂️ Running auto-archive for merchant: \(merchantId)")
        
        firestoreService.autoArchiveExpiredEvents(for: merchantId) { [weak self] archivedCount, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Auto-archive failed: \(error.localizedDescription)")
                } else {
                    print("✅ Auto-archived \(archivedCount) events")
                    self?.autoArchiveCount += archivedCount
                    self?.lastAutoArchiveDate = Date()
                    self?.saveAutoArchiveSettings()
                    
                    if archivedCount > 0 {
                        self?.sendAutoArchiveNotification(count: archivedCount)
                    }
                }
            }
        }
    }
    
    func runManualArchiveCheck(for merchantId: String, completion: @escaping (Int) -> Void) {
        print("🗂️ Running manual archive check for merchant: \(merchantId)")
        
        firestoreService.autoArchiveExpiredEvents(for: merchantId) { [weak self] archivedCount, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Manual archive check failed: \(error.localizedDescription)")
                    completion(0)
                } else {
                    print("✅ Manual archive check completed: \(archivedCount) events archived")
                    if archivedCount > 0 {
                        self?.autoArchiveCount += archivedCount
                        self?.lastAutoArchiveDate = Date()
                        self?.saveAutoArchiveSettings()
                    }
                    completion(archivedCount)
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    private func sendAutoArchiveNotification(count: Int) {
        // Send local notification
        let content = UNMutableNotificationContent()
        content.title = "Events Archived"
        content.body = "\(count) expired event\(count == 1 ? "" : "s") \(count == 1 ? "has" : "have") been automatically archived"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "auto_archive_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send auto-archive notification: \(error.localizedDescription)")
            } else {
                print("✅ Auto-archive notification sent")
            }
        }
    }
    
    // MARK: - Statistics
    
    var formattedLastArchiveDate: String {
        guard let lastDate = lastAutoArchiveDate else {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastDate)
    }
    
    var daysSinceLastArchive: Int {
        guard let lastDate = lastAutoArchiveDate else {
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastDate, to: Date())
        return components.day ?? 0
    }
}

// MARK: - Auto Archive Settings View

struct AutoArchiveSettingsView: View {
    @ObservedObject var autoArchiveService: AutoArchiveService
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingManualArchiveAlert = false
    @State private var manualArchiveCount = 0
    @State private var isRunningManualArchive = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "archivebox")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto Archive")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Automatically archive expired events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { autoArchiveService.isAutoArchiveEnabled },
                    set: { _ in autoArchiveService.toggleAutoArchive() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .purple))
            }
            
            if autoArchiveService.isAutoArchiveEnabled {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Statistics
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Run")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(autoArchiveService.formattedLastArchiveDate)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Archived")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(autoArchiveService.autoArchiveCount)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    // Manual archive button
                    Button(action: {
                        runManualArchive()
                    }) {
                        HStack {
                            if isRunningManualArchive {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "archivebox.fill")
                            }
                            Text("Archive Expired Events Now")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningManualArchive)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Events Archived", isPresented: $showingManualArchiveAlert) {
            Button("OK") { }
        } message: {
            Text("\(manualArchiveCount) expired event\(manualArchiveCount == 1 ? "" : "s") \(manualArchiveCount == 1 ? "has" : "have") been archived.")
        }
    }
    
    private func runManualArchive() {
        guard let user = authViewModel.user else { return }
        
        isRunningManualArchive = true
        autoArchiveService.runManualArchiveCheck(for: user.uid) { count in
            manualArchiveCount = count
            isRunningManualArchive = false
            showingManualArchiveAlert = true
        }
    }
}