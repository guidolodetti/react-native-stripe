import { NativeEventEmitter, NativeModules } from "react-native";
import processColor from "react-native/Libraries/StyleSheet/processColor";

const { RNStripe } = NativeModules;

class RNStripeManager {
  _ephemeralKeyProviderFn = undefined;
  _customerKeySubscription = undefined;
  _stripeEventEmitter = new NativeEventEmitter(RNStripe);

  init({ publishableKey, ephemeralKeyProviderFn, appleMerchantId, theme }) {
    if (!ephemeralKeyProviderFn) {
      throw "ephemeralKeyProviderFn option is required!";
    }

    this._ephemeralKeyProviderFn = ephemeralKeyProviderFn;

    if (!this._customerKeySubscription) {
      // Subscribe to RNStripe events
      this._customerKeySubscription = this._stripeEventEmitter.addListener(
        "RNStripeRequestedCustomerKey",
        async params => {
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
        }
      );
    }

    return RNStripe.initWithOptions({
      publishableKey,
      appleMerchantId,
      theme: processTheme(theme)
    });
  }

  getCurrentPaymentMethod(paymentContenxtOptions) {
    return RNStripe.initPaymentContext(paymentContenxtOptions);
  }

  showPaymentMethodChooser(paymentChoosenCallback) {
    this._unsubscribePaymentMethodChanges();

    this._paymentMethodSubscription = this._stripeEventEmitter.addListener(
      "RNStripeSelectedPaymentMethodDidChange",
      cardData => {
        this._unsubscribePaymentMethodChanges();
        paymentChoosenCallback(cardData);
      }
    );

    return RNStripe.presentPaymentMethodsViewController();
  }

  getCardImageSourceFromBrand(imageBrand) {
    switch (imageBrand) {
      case 'Visa':
        return require('./card-icons/stp_card_visa.png');
      case 'MasterCard':
        return require('./card-icons/stp_card_mastercard.png');
      case 'American Express':
        return require('./card-icons/stp_card_amex.png');
      case 'Discover':
        return require('./card-icons/stp_card_discover.png');
      case 'Diners':
        return require('./card-icons/stp_card_diners.png');
      default:
        return require('./card-icons/stp_card_unknown.png');
    }
  }

  _unsubscribePaymentMethodChanges() {
    // Remove paymentMethodSubscription if any
    if (this._paymentMethodSubscription) {
      this._paymentMethodSubscription.remove();
      this._paymentMethodSubscription = null;
    }
  }

  _unsubscribeCustomerKeyUpdates() {
    // Remove customerKeySubscription if any
    if (this._customerKeySubscription) {
      this._customerKeySubscription.remove();
      this._customerKeySubscription = null;
    }
  }

  destroy() {
    this._unsubscribePaymentMethodChanges();
    this._unsubscribeCustomerKeyUpdates();
  }
}

function processTheme(theme = {}) {
  return Object.keys(theme).reduce((result, key) => {
    let value = theme[key];
    if (key.toLowerCase().endsWith("color")) {
      value = processColor(value);
    }
    return { ...result, [key]: value };
  }, {});
}

const rnStripeMananger = new RNStripeManager();

export default rnStripeMananger;
