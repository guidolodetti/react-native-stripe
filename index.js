import { NativeEventEmitter, NativeModules } from "react-native";

const { RNStripe } = NativeModules;

class RNStripeManager {
  _ephemeralKeyProviderFn = undefined;
  _customerKeySubscription = undefined;

  init({ publishableKey, ephemeralKeyProviderFn }) {
    if (!ephemeralKeyProviderFn) {
      throw "ephemeralKeyProviderFn option is required!";
    }

    this._ephemeralKeyProviderFn = ephemeralKeyProviderFn;

    if (!this._customerKeySubscription) {
      // Subscribe to RNStripe events
      const stripeEventEmitter = new NativeEventEmitter(RNStripe);
      this._customerKeySubscription = stripeEventEmitter.addListener("RNStripeRequestedCustomerKey", async params => {
        try {
          // Here you should request the ephemeral key
          // from your server (check Stripe documentation)
          const customerKeyObject = await this._ephemeralKeyProviderFn({ apiVersion: params.apiVersion });

          // Then return back the key
          RNStripe.retrievedCustomerKey(customerKeyObject);
        } catch (err) {
          // There was an error retrieving the CustomerKey
          RNStripe.failedRetrievingCustomerKey();
        }
      });
    }

    return RNStripe.initWithPublishableKey(publishableKey);
  }

  requestPayment(paymentContenxtOptions) {
    return RNStripe.initPaymentContext(paymentContenxtOptions).then(() =>
      RNStripe.presentPaymentMethodsViewController()
    );
  }

  destroy() {
    // Remove customerKeySubscription if any
    if (this._customerKeySubscription) {
      this._customerKeySubscription.remove();
    }
  }
}

const rnStripeMananger = new RNStripeManager();

export default rnStripeMananger;
