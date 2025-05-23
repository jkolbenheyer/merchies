import Foundation

struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
    
    init(message: String) {
        self.message = message
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    
    init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}
