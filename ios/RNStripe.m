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

RCT_EXPORT_METHOD(initWithPublishableKey:(NSString *)publishableKey
                                resolver:(RCTPromiseResolveBlock)resolve
                                rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"RNStripe: initWithPublishableKey");
    if (publishableKey == nil) {
        [NSException raise:@"Publishable Key Required"
                    format:@"A valid Stripe publishable key is required"];
    }

    [Stripe setDefaultPublishableKey:publishableKey];
    [[STPPaymentConfiguration sharedConfiguration] setPublishableKey:publishableKey];

    resolve(@YES);
};

- (void)createCustomerKeyWithAPIVersion:(NSString *)apiVersion
                             completion:(STPJSONResponseCompletionBlock)completion
{
    NSLog(@"RNStripe: createCustomerKeyWithAPIVersion");

    customerKeyCompletionBlock = completion;

    [self sendEventWithName:@"RNStripeRequestedCustomerKey"
                       body:@{
                              @"apiVersion": apiVersion
                            }];
}

RCT_EXPORT_METHOD(retrievedCustomerKey:(NSDictionary*)customerKey)
{
    NSLog(@"RNStripe: retrievedCustomerKey");

    if (customerKeyCompletionBlock != nil) {
        customerKeyCompletionBlock(customerKey, nil);
    }
}

RCT_EXPORT_METHOD(failedRetrievingCustomerKey)
{
    NSLog(@"RNStripe: failedRetrievingCustomerKey");

    NSError * error;
    if (customerKeyCompletionBlock != nil) {
        customerKeyCompletionBlock(nil, error);
    }
}

RCT_EXPORT_METHOD(initPaymentContext:(NSDictionary*)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSNumber * amount = options[@"amount"];
    if (amount == nil) {
        [NSException raise:@"Amount Required"
                    format:@"A valid integer amount is required"];
    }

    customerContext = [[STPCustomerContext alloc] initWithKeyProvider:self];

    STPPaymentConfiguration* config = [[STPPaymentConfiguration sharedConfiguration] copy];

    // Forces card requirements to full address. Check `STPBillingAddress` for other options
    [config setRequiredBillingAddressFields: STPBillingAddressFieldsFull];
    
    paymentContext = [[STPPaymentContext alloc]
                      initWithCustomerContext:customerContext
                      configuration:config
                      theme:[STPTheme defaultTheme]];
    paymentContext.paymentCountry = @"IT";
    paymentContext.delegate = self;
    paymentContext.paymentAmount = [amount intValue];
    paymentContext.paymentCurrency = @"eur";
    
    resolve(@YES);
}

RCT_EXPORT_METHOD(presentPaymentMethodsViewController:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    paymentContext.hostViewController = RCTPresentedViewController();
    [paymentContext presentPaymentMethodsViewController];
    
    resolve(@YES);
}

- (void)paymentContextDidChange:(STPPaymentContext *)paymentContext
{
    // Checks if a selected method is available and sends an event (only if different from previous)
    if (paymentContext.selectedPaymentMethod != nil
        && ![paymentContext.selectedPaymentMethod isEqual: lastSelectedPaymentMethod]) {

        // Converts the template image to a base64 string
        UIImage * templateImage = paymentContext.selectedPaymentMethod.templateImage;
        NSString * cardTemplateImage = [UIImageJPEGRepresentation(templateImage, 1.0) base64EncodedStringWithOptions:nil];
        NSString * cardLabel = paymentContext.selectedPaymentMethod.label;

        // Send updated info to JS
        [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange"
                           body:@{
                                  @"label": cardLabel,
                                  @"templateImage": cardTemplateImage
                                }];
        
        lastSelectedPaymentMethod = paymentContext.selectedPaymentMethod;
    }
}

- (void)paymentContext:(nonnull STPPaymentContext *)paymentContext
didCreatePaymentResult:(nonnull STPPaymentResult *)paymentResult
            completion:(nonnull STPErrorBlock)completion {
    NSLog(@"RNStripe: PaymentContextDidCreatePaymentResult");
}


- (void)paymentContext:(nonnull STPPaymentContext *)paymentContext
   didFinishWithStatus:(STPPaymentStatus)status
                 error:(nullable NSError *)error {
    NSLog(@"RNStripe: PaymentContextDidFinishWithStatusError");
}

- (void)paymentContext:(STPPaymentContext *)paymentContext
didFailToLoadWithError:(NSError *)error
{
    NSLog(@"RNStripe: PaymentContextDidFailToLoadWithError");
    [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange" body:nil];
}


@end
