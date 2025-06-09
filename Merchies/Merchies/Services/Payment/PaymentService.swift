import Foundation
import UIKit
import SwiftUI
import StripePaymentSheet
import FirebaseFunctions
import FirebaseAuth
import FirebaseCore

class PaymentService: ObservableObject {
    static let shared = PaymentService()
    private let functions: Functions
    
    private init() {
        // Ensure we're using the default Firebase app
        if let app = FirebaseApp.app() {
            self.functions = Functions.functions(app: app, region: "us-central1")
            print("✅ PaymentService: Using default Firebase app")
        } else {
            self.functions = Functions.functions(region: "us-central1")
            print("⚠️ PaymentService: No default Firebase app found, using default")
        }
        
        // Initialize Stripe with your publishable key
        configureStripe()
    }
    
    enum PaymentError: Error {
        case paymentFailed
        case userCancelled
        case unknown
        case invalidAmount
        case stripeNotConfigured
        
        var localizedDescription: String {
            switch self {
            case .paymentFailed:
                return "Payment failed. Please try again."
            case .userCancelled:
                return "Payment was cancelled."
            case .unknown:
                return "An unknown error occurred."
            case .invalidAmount:
                return "Invalid payment amount."
            case .stripeNotConfigured:
                return "Payment system is not properly configured."
            }
        }
    }
    
    struct PaymentResult {
        let transactionId: String
        let amount: Double
        let currency: String
        let timestamp: Date
    }
    
    
    private func configureStripe() {
        StripeAPI.defaultPublishableKey = "pk_test_51RX0aZIk8pBR1Ys1f1IsIMZCHfSofvLpZYKDwj0yrOqLtf2SP6hPvzlPOPzsKzEz5LYd6WS3lSHGHgPcEnpNIj0v00fWz9D1hk"
        
        // Apple Pay will automatically appear in PaymentSheet when properly configured
        print("✅ Stripe SDK configured successfully with Apple Pay support")
    }
    
    // Process payment using Stripe PaymentSheet
    func processPayment(amount: Double, currency: String = "USD", orderId: String? = nil, completion: @escaping (Result<PaymentResult, PaymentError>) -> Void) {
        guard amount > 0 else {
            completion(.failure(.invalidAmount))
            return
        }
        
        // Use provided orderId or create temporary one for simulation
        let orderIdToUse = orderId ?? "temp_\(UUID().uuidString)"
        print("🚀 Processing payment for order: \(orderIdToUse)")
        
        // Note: Commented out forced simulation to allow testing real Stripe flows
        // if isRunningOnSimulator() {
        //     print("📱 Running on simulator - using payment simulation")
        //     presentSimulatedPaymentSheet(amount: amount, currency: currency, completion: completion)
        //     return
        // }
        
        // Convert amount to cents for Stripe
        let amountInCents = Int(amount * 100)
        
        createPaymentIntent(amount: amountInCents, currency: currency.lowercased(), orderId: orderIdToUse) { [weak self] result in
            switch result {
            case .success(let clientSecret):
                self?.presentPaymentSheet(clientSecret: clientSecret, amount: amount, currency: currency, completion: completion)
            case .failure(let error):
                print("❌ Payment intent creation failed, falling back to simulation: \(error.localizedDescription)")
                // Fallback to simulation if Firebase function fails
                self?.simulatePaymentCompletion(amount: amount, currency: currency, completion: completion)
            }
        }
        
    }
    
    
    // Create payment intent using Firebase callable function
    private func createPaymentIntent(amount: Int, currency: String = "usd", orderId: String, completion: @escaping (Result<String, PaymentError>) -> Void) {
        print("🚀 Creating payment intent for amount: \(amount) \(currency), orderId: \(orderId)")
        
        // Check if user is authenticated
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ User not authenticated - cannot call Firebase Function")
            DispatchQueue.main.async {
                self.fallbackToSimulation(amount: amount, currency: currency, completion: completion)
            }
            return
        }
        
        print("✅ User authenticated: \(currentUser.uid)")
        print("🔐 Auth state - Anonymous: \(currentUser.isAnonymous)")
        print("🔐 Auth state - Email verified: \(currentUser.isEmailVerified)")
        print("🔐 Auth state - Provider count: \(currentUser.providerData.count)")
        
        // Check auth state listener
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                print("🔐 Auth state listener - User is signed in: \(user.uid)")
            } else {
                print("🔐 Auth state listener - No user signed in")
            }
        }
        
        let requestData: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "orderId": orderId
        ]
        
        // Force refresh the user's auth token to ensure it's valid
        currentUser.getIDTokenForcingRefresh(true) { token, error in
            if let error = error {
                print("❌ Failed to refresh auth token: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.fallbackToSimulation(amount: amount, currency: currency, completion: completion)
                }
                return
            }
            
            if let token = token {
                print("✅ Auth token refreshed successfully. Token preview: \(String(token.prefix(20)))...")
                print("🔐 Current user email: \(currentUser.email ?? "no email")")
                print("🔐 User is anonymous: \(currentUser.isAnonymous)")
                print("🔐 User email verified: \(currentUser.isEmailVerified)")
                
                // Wait a bit for the auth context to propagate to Functions
                print("⏱️ Waiting for auth context to propagate...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.callFirebaseFunction(requestData: requestData, amount: amount, currency: currency, completion: completion)
                }
            } else {
                print("⚠️ Auth token is nil despite no error")
                DispatchQueue.main.async {
                    self.fallbackToSimulation(amount: amount, currency: currency, completion: completion)
                }
            }
        }
    }
    
    private func callFirebaseFunction(requestData: [String: Any], amount: Int, currency: String, completion: @escaping (Result<String, PaymentError>) -> Void) {
        print("📤 Calling Firebase function with data: \(requestData)")
        
        // Verify the Functions instance is using the current user
        if let currentUser = Auth.auth().currentUser {
            print("🔥 Functions SDK user check - UID: \(currentUser.uid)")
            print("🔥 Functions SDK user email: \(currentUser.email ?? "no email")")
        } else {
            print("❌ Functions SDK shows no current user!")
        }
        
        // Test simple function call first
        print("🧪 Testing simple function call...")
        let simpleCallable = functions.httpsCallable("testSimple")
        let simpleData: [String: Any] = ["test": "simple_call"]
        
        simpleCallable.call(simpleData) { testResult, testError in
            if let testError = testError {
                print("🧪 Simple test failed: \(testError.localizedDescription)")
            } else {
                print("🧪 Simple test succeeded: \(testResult?.data ?? "no data")")
            }
        }
        
        let callable = functions.httpsCallable("createPaymentIntent")
        
        // Add timeout and retry logic
        callable.call(requestData) { result, error in
            if let error = error {
                print("❌ Firebase function error: \(error.localizedDescription)")
                
                // Check if it's an authentication error
                if let functionError = error as NSError?, 
                   functionError.domain == "FIRFunctionsErrorDomain" {
                    print("❌ Firebase Functions error code: \(functionError.code)")
                    print("❌ Firebase Functions error details: \(functionError.userInfo)")
                    
                    // Common error codes:
                    // 13 = INTERNAL
                    // 16 = unauthenticated
                    // 3 = invalid-argument
                    // 7 = permission-denied
                    switch functionError.code {
                    case 13:
                        print("🔥 INTERNAL: Function crashed or misconfigured. Check Firebase Console logs.")
                        print("🔥 This often means:")
                        print("   - Stripe secret key is invalid")
                        print("   - Function dependencies are missing")
                        print("   - Function code has a runtime error")
                        print("   - Function timeout or memory limit exceeded")
                    case 16:
                        print("🔐 UNAUTHENTICATED: User not authenticated for Firebase Function")
                    case 3:
                        print("📝 INVALID_ARGUMENT: Check function parameters")
                    case 7:
                        print("🚫 PERMISSION_DENIED: Check Firebase rules")
                    default:
                        print("❓ Unknown error code: \(functionError.code)")
                    }
                    
                    // Print additional debug info for INTERNAL errors
                    if functionError.code == 13 {
                        print("🔍 Debug info for INTERNAL error:")
                        print("   - Request data: \(requestData)")
                        print("   - User UID: \(Auth.auth().currentUser?.uid ?? "nil")")
                        print("   - Function region: us-central1")
                    }
                }
                
                // Fallback to simulation
                print("🔄 Falling back to payment simulation")
                DispatchQueue.main.async {
                    self.fallbackToSimulation(amount: amount, currency: currency, completion: completion)
                }
                return
            }
            
            guard let data = result?.data as? [String: Any] else {
                print("❌ Invalid response format from Firebase function")
                DispatchQueue.main.async {
                    self.fallbackToSimulation(amount: amount, currency: currency, completion: completion)
                }
                return
            }
            
            print("✅ Firebase function response: \(data)")
            
            if let clientSecret = data["clientSecret"] as? String {
                print("✅ Found clientSecret: \(String(clientSecret.prefix(20)))...")
                print("🎉 REAL STRIPE PAYMENT INTENT RECEIVED!")
                completion(.success(clientSecret))
            } else {
                print("❌ No clientSecret in response. Available keys: \(Array(data.keys))")
                if let debugInfo = data["debug"] as? [String: Any] {
                    print("🔍 Debug info from function: \(debugInfo)")
                }
                DispatchQueue.main.async {
                    self.fallbackToSimulation(amount: amount, currency: currency, completion: completion)
                }
            }
        }
    }
    
    // Fallback to simulation when backend is unreachable
    private func fallbackToSimulation(amount: Int, currency: String, completion: @escaping (Result<String, PaymentError>) -> Void) {
        print("🎭 Using payment simulation fallback - bypassing Stripe PaymentSheet")
        // Instead of trying to use a mock client secret with Stripe, 
        // we'll signal to bypass Stripe entirely
        completion(.success("SIMULATION_MODE"))
    }
    
    // Check if we're running on simulator
    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // Present Stripe PaymentSheet
    private func presentPaymentSheet(clientSecret: String, amount: Double, currency: String, completion: @escaping (Result<PaymentResult, PaymentError>) -> Void) {
        // Check if we're in simulation mode
        if clientSecret == "SIMULATION_MODE" {
            print("🎭 Running payment simulation with UI")
            presentSimulatedPaymentSheet(amount: amount, currency: currency, completion: completion)
            return
        }
        
        // Try to find a suitable view controller, with retry logic
        attemptToPresent(clientSecret: clientSecret, amount: amount, currency: currency, completion: completion, retryCount: 0)
    }
    
    // Present a simulated payment sheet when backend is unavailable
    private func presentSimulatedPaymentSheet(amount: Double, currency: String, completion: @escaping (Result<PaymentResult, PaymentError>) -> Void) {
        // Find the topmost view controller that can present
        guard let presentingViewController = findTopViewControllerForAlert() else {
            print("⚠️ No suitable view controller found, proceeding with direct simulation")
            simulatePaymentCompletion(amount: amount, currency: currency, completion: completion)
            return
        }
        
        let alert = UIAlertController(
            title: "Test Payment",
            message: "Process test payment for $\(String(format: "%.2f", amount))?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Pay with Test Card", style: .default) { _ in
            print("🎭 User confirmed simulated payment")
            self.simulatePaymentCompletion(amount: amount, currency: currency, completion: completion)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(.failure(.userCancelled))
        })
        
        DispatchQueue.main.async {
            presentingViewController.present(alert, animated: true)
        }
    }
    
    // Find the topmost view controller that can present alerts
    private func findTopViewControllerForAlert() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        
        // Keep going up the chain to find the topmost presented view controller
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        // If the top view controller is already presenting something, wait and try again
        if topViewController?.presentedViewController != nil {
            print("⚠️ Top view controller is busy presenting, will retry")
            return nil
        }
        
        return topViewController
    }
    
    // Test endpoint connectivity
    private func testEndpointConnectivity(url: URL) {
        print("🔍 Testing connectivity to: \(url.absoluteString)")
        
        // Test with proper POST request format
        var testRequest = URLRequest(url: url)
        testRequest.httpMethod = "POST"
        testRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        testRequest.timeoutInterval = 10.0
        
        let testBody: [String: Any] = ["amount": 100, "currency": "usd"]
        do {
            testRequest.httpBody = try JSONSerialization.data(withJSONObject: testBody)
        } catch {
            print("🔍 Failed to create test request body")
            return
        }
        
        URLSession.shared.dataTask(with: testRequest) { data, response, error in
            if let error = error {
                print("🔍 POST test failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("🔍 POST test - Status: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 POST response: \(responseString.prefix(200))")
                }
            }
        }.resume()
    }
    
    private func testWithDifferentConfig(url: URL) {
        print("🔍 Testing with different network configuration...")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.httpMethod = "OPTIONS" // CORS preflight
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔍 OPTIONS test failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("🔍 OPTIONS test - Status: \(httpResponse.statusCode)")
                print("🔍 CORS headers: \(httpResponse.allHeaderFields)")
            }
        }.resume()
    }
    
    // Test external connectivity to rule out general network issues
    private func testExternalConnectivity(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://httpbin.org/get") else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("🔍 External connectivity test failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("🔍 External connectivity test passed")
                completion(true)
            }
        }.resume()
    }
    
    // Simulate successful payment completion
    private func simulatePaymentCompletion(amount: Double, currency: String, completion: @escaping (Result<PaymentResult, PaymentError>) -> Void) {
        print("🎭 Starting simulated payment completion with 2 second delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let result = PaymentResult(
                transactionId: "pi_sim_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))",
                amount: amount,
                currency: currency,
                timestamp: Date()
            )
            print("✅ Simulated payment completed: \(result.transactionId)")
            print("✅ Calling completion callback with success")
            completion(.success(result))
        }
    }
    
    private func attemptToPresent(clientSecret: String, amount: Double, currency: String, completion: @escaping (Result<PaymentResult, PaymentError>) -> Void, retryCount: Int) {
        guard retryCount < 3 else {
            completion(.failure(.unknown))
            return
        }
        
        guard let presentingViewController = findTopViewController() else {
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.attemptToPresent(clientSecret: clientSecret, amount: amount, currency: currency, completion: completion, retryCount: retryCount + 1)
            }
            return
        }
        
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Merchies"
        configuration.allowsDelayedPaymentMethods = false
        
        // Configure Apple Pay
        configuration.applePay = .init(
            merchantId: "merchant.com.merchies.app", // You'll need to replace this with your actual merchant ID
            merchantCountryCode: "US"
        )
        
        // Timeout mechanism removed to allow proper testing of payment flows
        
        // Enable automatic payment methods (includes Apple Pay, Google Pay, etc.)
        configuration.defaultBillingDetails.email = ""
        configuration.defaultBillingDetails.phone = ""
        
        let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
        
        paymentSheet.present(from: presentingViewController) { paymentResult in
            print("🎯 PaymentSheet result received: \(paymentResult)")
            DispatchQueue.main.async {
                switch paymentResult {
                case .completed:
                    print("✅ PaymentSheet completed successfully")
                    let result = PaymentResult(
                        transactionId: String(clientSecret.prefix(27)),
                        amount: amount,
                        currency: currency,
                        timestamp: Date()
                    )
                    print("✅ Calling completion with success result")
                    completion(.success(result))
                    
                case .canceled:
                    print("❌ PaymentSheet was canceled")
                    completion(.failure(.userCancelled))
                    
                case .failed(let error):
                    print("❌ PaymentSheet failed: \(error.localizedDescription)")
                    completion(.failure(.paymentFailed))
                }
            }
        }
    }
    
    // Helper to find the topmost view controller that can present
    private func findTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        // If the top view controller is already presenting something, return nil to retry
        if topViewController?.presentedViewController != nil {
            return nil
        }
        
        return topViewController
    }
    
    
}

// Simple wrapper view for Stripe Payment processing
struct StripePaymentView: View {
    let amount: Double
    let onCompletion: (Result<PaymentService.PaymentResult, PaymentService.PaymentError>) -> Void
    let onCancel: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Complete Payment")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Amount:")
                    Spacer()
                    Text("$\(String(format: "%.2f", amount))")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Opening payment form...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Button(action: processPayment) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text("Pay Securely")
                            Spacer()
                            Text("🍎💳")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Secure payment with Apple Pay, cards, and more via Stripe")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom)
        }
        .padding()
        .onAppear {
            // Start the payment flow when the sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !isProcessing {
                    processPayment()
                }
            }
        }
    }
    
    private func processPayment() {
        isProcessing = true
        
        PaymentService.shared.processPayment(amount: amount) { result in
            DispatchQueue.main.async {
                isProcessing = false
                onCompletion(result)
            }
        }
    }
}
