# 💳 react-native-stripe

## Installation

### iOS

Import `RNStripe.xcodeproject` from the `ios` directory and link its library to your project.

### Android

Not available yet.

## Usage

```javascript
// react-native-dotenv is highly recommended
import { STRIPE_PUBLISHABLE_KEY } from "react-native-dotenv";

import RNStripe from "react-native-stripe";

// Init RNStripe
RNStripe.init({
  publishableKey: STRIPE_PUBLISHABLE_KEY,
  ephemeralKeyProviderFn: params => {
    console.log(params.apiVersion);
    //
    // Here you should request the ephemeral key
    // from your server (check Stripe documentation)
    // customerKeyResponse = ....

    // Then return back the key
    return customerKeyResponse;
  }
}).then(() => {
  console.log("RNStripe: Initilization completed!");
});

// To request a Payment
// The amount to charge the user is required and
//  is in cents, (1$ == 100, 10$ == 1000)
RNStripe.requestPayment({
  amount: 100
}).then(() => {
  console.log("RNStripe: Payment requested!");
});
```
