# 🍎 Apple Pay Integration Setup Guide

## ✅ Already Completed
- [x] Updated PaymentService.swift to enable Apple Pay in Stripe PaymentSheet
- [x] Configured Apple Pay settings in PaymentSheet.Configuration

## 🔧 Required Steps to Complete Apple Pay Integration

### 1. Apple Developer Console Configuration

#### A. Create Apple Merchant ID
1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **Merchant IDs**
4. Click the **+** button to create a new Merchant ID
5. Enter:
   - **Description**: "Merchies App Payments"
   - **Identifier**: `merchant.com.merchies.app` (or your preferred format)
6. Click **Continue** and **Register**

#### B. Create Apple Pay Payment Processing Certificate
1. In the Merchant ID you just created, click **Create Certificate**
2. Follow the prompts to upload a Certificate Signing Request (CSR)
3. Download the certificate and install it in Keychain Access

### 2. Xcode Project Configuration

#### A. Add Apple Pay Capability
1. Open your Xcode project
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Apple Pay**
6. Select your Merchant ID from the dropdown

#### B. Update Info.plist (if needed)
```xml
<key>NSApplePayMerchantID</key>
<string>merchant.com.merchies.app</string>
```

### 3. Stripe Dashboard Configuration

#### A. Connect Apple Pay to Stripe
1. Log into your [Stripe Dashboard](https://dashboard.stripe.com/)
2. Go to **Settings** → **Payment methods**
3. Find **Apple Pay** and click **Enable**
4. Upload your Apple Pay certificate (.p12 file)
5. Enter your Merchant ID: `merchant.com.merchies.app`

#### B. Test Mode Configuration
- Ensure Apple Pay is enabled in test mode
- Add test cards to your device's Wallet app for testing

### 4. Update PaymentService Configuration

Update the merchant ID in PaymentService.swift:
```swift
configuration.applePay = .init(
    merchantId: "merchant.com.merchies.app", // Replace with your actual merchant ID
    merchantCountryCode: "US"
)
```

### 5. Testing Apple Pay

#### A. Device Requirements
- Physical iOS device (Apple Pay doesn't work in simulator)
- Device with Touch ID, Face ID, or passcode enabled
- At least one card added to Apple Wallet

#### B. Test Scenarios
1. **Happy Path**: Complete purchase with Apple Pay
2. **Cancellation**: User cancels Apple Pay sheet
3. **Authentication Failure**: Touch ID/Face ID fails
4. **Network Issues**: Test with poor connectivity

### 6. Production Deployment

#### A. Stripe Live Mode
1. Enable Apple Pay in Stripe live mode
2. Upload production Apple Pay certificate
3. Update publishable key to live key

#### B. App Store Requirements
- Apple Pay usage must be disclosed in App Store listing
- Follow Apple Pay branding guidelines
- Include Apple Pay logo where payment methods are shown

## 🔒 Security Considerations

### Payment Data
- Apple Pay tokenizes card data - actual card numbers never touch your servers
- Stripe handles all PCI compliance
- No changes needed to your existing payment flow

### Authentication
- Apple Pay requires biometric or passcode authentication
- This adds an extra security layer beyond your app's authentication

## 🎨 UI/UX Considerations

### Apple Pay Button
The Stripe PaymentSheet automatically shows Apple Pay when:
- Device supports Apple Pay
- User has cards in Wallet
- Merchant ID is properly configured

### Fallback Options
Your existing credit card input will remain available as a fallback when:
- Apple Pay is not available
- User chooses not to use Apple Pay
- Apple Pay authentication fails

## 📱 User Experience

### What Users Will See
1. **Payment Sheet**: Apple Pay button appears at the top
2. **Apple Pay Sheet**: Native iOS payment interface
3. **Authentication**: Touch ID/Face ID prompt
4. **Confirmation**: Order confirmation with Apple Pay transaction

### Benefits for Users
- ✅ Faster checkout (no manual card entry)
- ✅ Enhanced security (tokenized payments)
- ✅ Familiar Apple interface
- ✅ Automatic billing/shipping address

## 🧪 Testing Checklist

- [ ] Apple Pay button appears in PaymentSheet
- [ ] Successful payment with Touch ID/Face ID
- [ ] Successful payment with passcode fallback
- [ ] User cancellation handling
- [ ] Authentication failure handling
- [ ] Order creation and QR code generation
- [ ] Merchant QR code scanning works
- [ ] Firebase order status updates correctly

## 🚀 Launch Preparation

### Before Going Live
1. Test with multiple cards in Wallet
2. Test on different device models
3. Verify Stripe webhook handling
4. Test order fulfillment flow
5. Confirm Apple Pay branding compliance

### Launch Day
1. Monitor Stripe dashboard for Apple Pay transactions
2. Watch for any payment failures
3. Check order completion rates
4. Monitor customer support for payment issues

## 💡 Additional Features (Future)

### Enhanced Apple Pay Integration
- Pre-fill shipping addresses from Apple Pay
- Support for Apple Pay Later (Buy Now, Pay Later)
- Apple Pay recurring payments for subscriptions
- Express checkout for repeat customers

### Analytics
- Track Apple Pay usage vs. card payments
- Monitor conversion rates by payment method
- A/B test payment method ordering