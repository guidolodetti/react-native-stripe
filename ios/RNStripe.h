
#if __has_include("RCTEventEmitter.h")
#import "RCTEventEmitter.h"
#else
#import <React/RCTEventEmitter.h>
#endif

#if __has_include("Stripe.h")
#import "Stripe.h"
#else
#import <Stripe/Stripe.h>
#endif

@interface RNStripe : RCTEventEmitter <RCTBridgeModule, STPEphemeralKeyProvider, STPPaymentContextDelegate>

@end
  
