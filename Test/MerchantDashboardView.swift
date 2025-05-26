import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore

struct MerchantEventsView: View {
    @State private var events: [Event] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if events.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Events Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Create or join an event to see it listed here.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                    .padding(.top, 50)
                } else {
                    List(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.headline)
                            Text(event.venueName)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("From \(formattedDate(event.startDate)) to \(formattedDate(event.endDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Your Events")
            .onAppear {
                loadEvents()
            }
        }
    }

    func loadEvents() {
        guard let user = authViewModel.user else {
            errorMessage = "User not logged in"
            return
        }

        isLoading = true
        let db = Firestore.firestore()

        db.collection("events")
            .whereField("merchant_ids", arrayContains: user.uid)
            .getDocuments { snapshot, error in
                isLoading = false

                if let error = error {
                    errorMessage = "Error fetching events: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else {
                    events = []
                    return
                }

                events = documents.compactMap { doc in
                    try? doc.data(as: Event.self)
                }
            }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var venueName: String
    var address: String
    var startDate: Date
    var endDate: Date
    var latitude: Double
    var longitude: Double
    var geofenceRadius: Double
    var active: Bool
    var merchantIds: [String]
}
