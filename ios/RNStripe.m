#import "RNStripe.h"
#import <React/RCTUtils.h>

@implementation RNStripe {
    RCTPromiseResolveBlock promiseResolver;
    RCTPromiseRejectBlock promiseRejector;

    STPPaymentContext * paymentContext;
    STPCustomerContext * customerContext;
    STPJSONResponseCompletionBlock customerKeyCompletionBlock;
    
    id lastSelectedPaymentMethod;
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"RNStripeRequestedCustomerKey", @"RNStripeSelectedPaymentMethodDidChange"];
}

- (void)createCustomerKeyWithAPIVersion:(NSString *)apiVersion completion:(STPJSONResponseCompletionBlock)completion
{
    customerKeyCompletionBlock = completion;
    [self sendEventWithName:@"RNStripeRequestedCustomerKey" body:@{@"apiVersion": apiVersion}];
}

- (void)paymentContextDidChange:(STPPaymentContext *)paymentContext
{
    // Checks if a selected method is available and sends an event (only if different from previous)
    if (paymentContext.selectedPaymentMethod != nil
        && [paymentContext.selectedPaymentMethod isEqual: lastSelectedPaymentMethod]) {
        // Converts the template image to a base64 string
        UIImage * templateImage = paymentContext.selectedPaymentMethod.templateImage;
        NSString * cardTemplateImage = [UIImageJPEGRepresentation(templateImage, 1.0)
                                        base64EncodedStringWithOptions:nil];
        NSString * cardLabel = paymentContext.selectedPaymentMethod.label;
        [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange"
                           body:@{@"label": cardLabel, @"templateImage": cardTemplateImage}];
        
        lastSelectedPaymentMethod = paymentContext.selectedPaymentMethod;
    } else {
        [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange" body:nil];
    }
}

- (void)paymentContext:(STPPaymentContext *)paymentContext
    didFailToLoadWithError:(NSError *)error
{
    [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange" body:nil];
}

RCT_EXPORT_METHOD(initPaymentContext:(NSDictionary*)options
                  presentPaymentMethodsViewController:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString * publishableKey = options[@"publishableKey"];
    if (publishableKey == nil) {
        [NSException raise:@"Publishable Key Required" format:@"A valid Stripe publishable key is required"];
    }
    NSNumber * amount = options[@"amount"];
    if (publishableKey == nil) {
        [NSException raise:@"Amount Required" format:@"A valid integer amount is required"];
    }

    [Stripe setDefaultPublishableKey:publishableKey];

    STPPaymentConfiguration * config = [[STPPaymentConfiguration alloc] init];
    
    // Forces card requirements to full address. Check `STPBillingAddress` for other options
    [config setRequiredBillingAddressFields: STPBillingAddressFieldsFull];
    customerContext = [[STPCustomerContext alloc] initWithKeyProvider:self];
    paymentContext = [[STPPaymentContext alloc]
                      initWithCustomerContext:customerContext
                      configuration:config theme:[STPTheme defaultTheme]];
    paymentContext.paymentCountry = @"IT";
    paymentContext.delegate = self;
    paymentContext.paymentAmount = [amount intValue];
    paymentContext.paymentCurrency = @"eur";
}

RCT_EXPORT_METHOD(retrievedCustomerKey:(NSDictionary*)customerKey)
{
    NSError * error;
    if (customerKeyCompletionBlock != nil) {
        customerKeyCompletionBlock(customerKey, error);
    }
}

RCT_EXPORT_METHOD(failedRetrievingCustomerKey)
{
    if (customerKeyCompletionBlock != nil) {
        customerKeyCompletionBlock(nil, nil);
    }
}

RCT_EXPORT_METHOD(presentPaymentMethodsViewController:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    paymentContext.hostViewController = RCTPresentedViewController();
    [paymentContext presentPaymentMethodsViewController];
}

@end
