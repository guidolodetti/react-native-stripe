
# 💳 react-native-stripe

## Installation

### iOS
Import `RNStripe.xcodeproject` from the `ios` directory and link its library to your project.

### Android
Not available yet.

## Usage

```javascript
import {
    NativeModules,
    NativeEventEmitter
} from 'react-native';

const { RNStripe } = NativeModules;

// react-native-dotenv is highly recommended
import { STRIPE_PUBLISHABLE_KEY } from 'react-native-dotenv';

// Subscribe to RNStripe events
const stripeEventEmitter = new NativeEventEmitter(RNStripe);

// This event is received when the customer key is requested from Stripe
const customerKeySubscription = stripeEventEmitter.addListener(
    'RNStripeRequestedCustomerKey',
    function(params) => {
        console.log(params.apiVersion)
    
        //
        // Here you should request the ephemeral key
        // from your server (check Stripe documentation)
        // customerKeyObject = ....
        
        // Then return back the key
        stripe.retrievedCustomerKey(customerKeyObject);
    }
);

// This event is received when the payment method changes
const paymentMethodSubscription = stripeEventEmitter.addListener(
    'RNStripeSelectedPaymentMethodDidChange',
    function(selectedPaymentMethod){
        // undefined if no payment method is selected
        // otherwise contains:
        // [string] `label`: card type and last 4 digits (es. `Visa 4444`)
        // [string] `templateImage`: base64 32x32pt card template image
    }
);

// Init the Stripe payment context. The amount to charge the user is required
// and is in cents, (1$ == 100, 10$ == 1000)
stripe.initPaymentContext({
    publishableKey: STRIPE_PUBLISHABLE_KEY,
    amount: 1000
});

// Present the payment methods view controller
// You should call this function when the user taps a payment method button *you* provide
stripe.presentPaymentMethodsViewController();
```
