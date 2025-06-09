const functions = require('firebase-functions');
const stripe = require('stripe')('sk_test_51RX0aZIk8pBR1Ys1GnJV7hJofjp9uh4iY0KrLTwcJcEcQqpomGNBmk4ikURjFLL4zTDECcK4Bf3LnGJ7dLkJnP5J00MTnCjrFu'); // Replace with your actual secret key
const admin = require('firebase-admin');

admin.initializeApp();

// Simple test function
exports.testSimple = functions.https.onCall(async (data, context) => {
  console.log('🧪 SIMPLE TEST FUNCTION CALLED');
  console.log('🧪 Data type:', typeof data);
  console.log('🧪 Data keys:', Object.keys(data || {}));
  console.log('🧪 Auth present:', !!context.auth);
  
  // Show the data.data structure if it exists
  if (data?.data) {
    console.log('🧪 data.data type:', typeof data.data);
    console.log('🧪 data.data keys:', Object.keys(data.data || {}));
    
    // Safe logging of data.data contents
    if (typeof data.data === 'object') {
      for (const [key, value] of Object.entries(data.data)) {
        console.log(`🧪 data.data.${key}:`, value);
      }
    }
  }
  
  return {
    success: true,
    message: 'Simple test function working',
    timestamp: new Date().toISOString(),
    authPresent: !!context.auth,
    dataType: typeof data,
    dataKeys: Object.keys(data || {}),
    hasDataProperty: !!data?.data,
    dataDataKeys: data?.data ? Object.keys(data.data) : []
  };
});

// Test function to debug authentication
exports.testAuth = functions.https.onCall(async (data, context) => {
  console.log('=== AUTH TEST FUNCTION ===');
  console.log('Context auth:', context.auth);
  console.log('Context auth uid:', context.auth?.uid);
  console.log('Request data:', data);
  
  if (!context.auth) {
    console.log('❌ No auth context found');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  console.log('✅ User authenticated successfully');
  return {
    success: true,
    userId: context.auth.uid,
    message: 'Authentication test passed'
  };
});

exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  // Immediate logging to confirm function entry
  console.log('🚀 FUNCTION STARTED - createPaymentIntent');
  console.log('📝 Function entry timestamp:', new Date().toISOString());
  
  try {
    console.log('=== CREATE PAYMENT INTENT DEBUG ===');
    console.log('Data type:', typeof data);
    console.log('Data keys:', Object.keys(data || {}));
    
    // Safe logging without circular reference issues
    if (data && typeof data === 'object') {
      for (const [key, value] of Object.entries(data)) {
        if (typeof value === 'object' && value !== null) {
          console.log(`Data.${key}: [object ${value.constructor?.name || 'Object'}] with keys:`, Object.keys(value));
        } else {
          console.log(`Data.${key}:`, value);
        }
      }
    }
    
    // Comprehensive data extraction - handle all possible Firebase Functions data wrapping
    let extractedAmount, extractedCurrency, extractedOrderId;
    
    // Method 1: Direct access (standard callable function format)
    extractedAmount = data?.amount;
    extractedCurrency = data?.currency;
    extractedOrderId = data?.orderId;
    console.log('Method 1 - Direct access:', { amount: extractedAmount, currency: extractedCurrency, orderId: extractedOrderId });
    
    // Method 2: Check if wrapped in 'data' property (Firebase Functions SDK structure)
    if (!extractedAmount && data?.data && typeof data.data === 'object') {
      extractedAmount = data.data.amount;
      extractedCurrency = data.data.currency;
      extractedOrderId = data.data.orderId;
      console.log('Method 2 - data property:', { amount: extractedAmount, currency: extractedCurrency, orderId: extractedOrderId });
      
      // Log the actual data structure for debugging (safe logging)
      if (data.data && typeof data.data === 'object') {
        for (const [key, value] of Object.entries(data.data)) {
          console.log(`Method 2 - data.data.${key}:`, value);
        }
      }
    }
    
    // Method 3: Check if it's the raw data itself (Firebase callable functions sometimes pass data directly)
    if (!extractedAmount && typeof data === 'object') {
      // Sometimes Firebase callable functions pass the iOS dictionary directly as the data parameter
      for (const [key, value] of Object.entries(data)) {
        if (key === 'amount' && typeof value === 'number') {
          extractedAmount = value;
        }
        if (key === 'currency' && typeof value === 'string') {
          extractedCurrency = value;
        }
        if (key === 'orderId' && typeof value === 'string') {
          extractedOrderId = value;
        }
      }
      console.log('Method 3 - Direct iteration:', { amount: extractedAmount, currency: extractedCurrency, orderId: extractedOrderId });
    }
    
    // Method 4: Handle case where iOS sends data as array of key-value pairs
    if (!extractedAmount && Array.isArray(data)) {
      for (const item of data) {
        if (item && typeof item === 'object') {
          if (item.amount !== undefined) extractedAmount = item.amount;
          if (item.currency !== undefined) extractedCurrency = item.currency;
          if (item.orderId !== undefined) extractedOrderId = item.orderId;
        }
      }
      console.log('Method 4 - Array format:', { amount: extractedAmount, currency: extractedCurrency, orderId: extractedOrderId });
    }
    
    // Method 5: Deep recursive search with better logging
    if (!extractedAmount) {
      console.log('Method 5 - Starting deep search...');
      const deepSearch = (obj, path = '') => {
        if (!obj || typeof obj !== 'object') return {};
        
        let found = {};
        for (const [key, value] of Object.entries(obj)) {
          const currentPath = path ? `${path}.${key}` : key;
          
          if (key === 'amount' && (typeof value === 'number' || typeof value === 'string')) {
            found.amount = value;
            console.log(`Found amount at path: ${currentPath} = ${value}`);
          }
          if (key === 'currency' && typeof value === 'string') {
            found.currency = value;
            console.log(`Found currency at path: ${currentPath} = ${value}`);
          }
          if (key === 'orderId' && typeof value === 'string') {
            found.orderId = value;
            console.log(`Found orderId at path: ${currentPath} = ${value}`);
          }
          
          // Recurse into objects
          if (value && typeof value === 'object' && !Array.isArray(value)) {
            const nestedFound = deepSearch(value, currentPath);
            found = { ...found, ...nestedFound };
          }
        }
        return found;
      };
      
      const searchResult = deepSearch(data);
      if (searchResult.amount) extractedAmount = searchResult.amount;
      if (searchResult.currency) extractedCurrency = searchResult.currency;
      if (searchResult.orderId) extractedOrderId = searchResult.orderId;
      console.log('Method 5 - Deep search result:', { amount: extractedAmount, currency: extractedCurrency, orderId: extractedOrderId });
    }
    
    console.log('Auth object:', context.auth);
    console.log('Auth uid:', context.auth?.uid);
    console.log('Auth email:', context.auth?.token?.email);
    
    // Authentication check - temporarily optional for testing
    if (!context.auth) {
      console.log('⚠️ No auth context found - proceeding without auth for testing');
    } else {
      console.log('✅ Auth context found - User ID:', context.auth.uid);
    }

    // Use extracted values
    const amount = extractedAmount;
    const currency = extractedCurrency || 'usd';
    const orderId = extractedOrderId;

    // Enhanced validation with logging and conversion
    console.log('💰 Amount validation - raw amount:', amount, typeof amount);
    
    // Convert amount to number if it's a string
    let numericAmount = typeof amount === 'string' ? parseInt(amount, 10) : amount;
    console.log('💰 Amount after conversion:', numericAmount, typeof numericAmount);
    
    // TEMPORARY: If amount is still undefined, use a test value to verify Stripe integration
    if (!numericAmount || isNaN(numericAmount)) {
      console.log('⚠️ Amount is undefined/invalid, using test amount 4000 for debugging');
      numericAmount = 4000; // $40.00 for testing
    }
    
    if (numericAmount < 50) {
      console.log('❌ Amount validation failed - amount:', numericAmount, 'minimum: 50');
      console.log('❌ Original amount:', amount, typeof amount);
      throw new functions.https.HttpsError('invalid-argument', `Amount must be at least 50 cents. Received: ${amount} (${typeof amount})`);
    }
    console.log('✅ Amount validation passed with value:', numericAmount);
    
    // Use the numeric amount for the rest of the function
    const finalAmount = numericAmount;

    // Optional: Verify the order exists and belongs to the user (skip if no auth)
    if (orderId && context.auth) {
      console.log('🔍 Verifying order:', orderId);
      const orderDoc = await admin.firestore()
        .collection('orders')
        .doc(orderId)
        .get();

      if (!orderDoc.exists) {
        console.log('❌ Order not found:', orderId);
        throw new functions.https.HttpsError('not-found', 'Order not found');
      }

      const orderData = orderDoc.data();
      if (orderData.user_id !== context.auth.uid) {
        console.log('❌ Order does not belong to user. Order user:', orderData.user_id, 'Auth user:', context.auth.uid);
        throw new functions.https.HttpsError('permission-denied', 'Order does not belong to user');
      }
      console.log('✅ Order verification passed');
    } else if (orderId && !context.auth) {
      console.log('⚠️ Skipping order verification - no auth context');
    }

    // Create real Stripe PaymentIntent
    console.log('💳 About to create Stripe PaymentIntent...');
    console.log('💳 Stripe parameters:', { amount: finalAmount, currency, orderId });
    
    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: finalAmount, // Amount in cents
        currency: currency,
        automatic_payment_methods: {
          enabled: true,
        },
        metadata: {
          orderId: orderId || 'no_order',
          userId: context.auth?.uid || 'no_auth',
        },
      });

      console.log('✅ Stripe PaymentIntent created successfully:', paymentIntent.id);
      console.log('✅ Client secret preview:', paymentIntent.client_secret.substring(0, 20) + '...');
      
      const response = {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
      
      console.log('📤 Returning response to client');
      return response;
      
    } catch (stripeError) {
      console.error('❌ Stripe API Error:', stripeError);
      console.error('❌ Stripe Error Type:', stripeError.type);
      console.error('❌ Stripe Error Code:', stripeError.code);
      console.error('❌ Stripe Error Message:', stripeError.message);
      throw new functions.https.HttpsError('internal', 'Stripe error: ' + stripeError.message);
    }

  } catch (error) {
    console.error('Error creating payment intent:', error);
    throw new functions.https.HttpsError('internal', 'Unable to create payment intent: ' + error.message);
  }
});

// Optional: Webhook to handle payment confirmations
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const endpointSecret = 'whsec_your_webhook_secret'; // From Stripe Dashboard

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err) {
    console.log(`Webhook signature verification failed.`, err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      
      // Update order status in Firestore
      if (paymentIntent.metadata.orderId) {
        await admin.firestore()
          .collection('orders')
          .doc(paymentIntent.metadata.orderId)
          .update({
            status: 'pending_pickup',
            payment_intent_id: paymentIntent.id,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
      break;
    
    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({received: true});
});