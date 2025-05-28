// EventProductsViewModel.swift - Standalone Class for Product-Event Management

import Foundation
import Firebase
import FirebaseFirestore
import SwiftUI

class EventProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    // MARK: - Fetch Methods
    
    // Fetch products for a specific event
    func fetchEventProducts(eventId: String) {
        isLoading = true
        error = nil
        
        firestoreService.fetchProductsForEvent(eventId: eventId) { [weak self] products, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    print("❌ Failed to fetch event products: \(error.localizedDescription)")
                    return
                }
                
                self?.products = products ?? []
                print("✅ Fetched \(products?.count ?? 0) products for event")
            }
        }
    }
    
    // Fetch available products for a merchant (excluding those already in event)
    func fetchMerchantProducts(merchantId: String, excludingEventId: String?) {
        isLoading = true
        error = nil
        
        firestoreService.fetchAvailableProductsForMerchant(merchantId: merchantId, excludingEventId: excludingEventId) { [weak self] products, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    print("❌ Failed to fetch merchant products: \(error.localizedDescription)")
                    return
                }
                
                self?.availableProducts = products ?? []
                print("✅ Fetched \(products?.count ?? 0) available products for merchant")
            }
        }
    }
    
    // MARK: - Product-Event Management
    
    // Add product to event
    func addProductToEvent(productId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        firestoreService.linkProductToEvent(productId: productId, eventId: eventId) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    print("❌ Failed to add product to event: \(error.localizedDescription)")
                    completion(false)
                } else if success {
                    print("✅ Product added to event successfully")
                    completion(true)
                } else {
                    print("❌ Failed to add product to event - unknown error")
                    completion(false)
                }
            }
        }
    }
    
    // Remove product from event
    func removeProductFromEvent(productId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        firestoreService.unlinkProductFromEvent(productId: productId, eventId: eventId) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    print("❌ Failed to remove product from event: \(error.localizedDescription)")
                    completion(false)
                } else if success {
                    print("✅ Product removed from event successfully")
                    // Refresh the products list
                    self?.fetchEventProducts(eventId: eventId)
                    completion(true)
                } else {
                    print("❌ Failed to remove product from event - unknown error")
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Check if a product is already in an event
    func isProductInEvent(productId: String, eventId: String) -> Bool {
        return products.contains { product in
            product.id == productId && product.eventIds.contains(eventId)
        }
    }
    
    // Get products not in the current event
    func getAvailableProductsForEvent(eventId: String) -> [Product] {
        return availableProducts.filter { product in
            !product.eventIds.contains(eventId)
        }
    }
    
    // Clear all data
    func clearData() {
        products.removeAll()
        availableProducts.removeAll()
        error = nil
        isLoading = false
    }
    
    // Refresh both product lists
    func refreshAllData(eventId: String, merchantId: String) {
        fetchEventProducts(eventId: eventId)
        fetchMerchantProducts(merchantId: merchantId, excludingEventId: eventId)
    }
}
