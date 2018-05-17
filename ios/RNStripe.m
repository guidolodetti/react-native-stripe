#import "RNStripe.h"
#import <React/RCTUtils.h>

@implementation RNStripe {
    RCTPromiseResolveBlock initPaymentContextPromiseResolver;

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

RCT_EXPORT_METHOD(initWithOptions:(NSDictionary*)options
                         resolver:(RCTPromiseResolveBlock)resolve
                         rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"RNStripe: initWithOptions");
    NSString* publishableKey = options[@"publishableKey"];
    if (publishableKey == nil) {
        reject(@"RNStripePublishableKeyRequired", @"A valid Stripe PublishableKey is required", nil);
        return;
    }

    [Stripe setDefaultPublishableKey:publishableKey];
    [[STPPaymentConfiguration sharedConfiguration] setPublishableKey:publishableKey];
    
    // Set 'Apple MerchantId' if supplied
    NSString* appleMerchantId = options[@"appleMerchantId"];
    [[STPPaymentConfiguration sharedConfiguration] setAppleMerchantIdentifier:appleMerchantId];

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
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    if (initPaymentContextPromiseResolver != nil) {
        reject(@"RNStripeInitPaymentInProgress", @"initPaymentContext already called, but initialization is not yet completed.", nil);
    }

    customerContext = [[STPCustomerContext alloc] initWithKeyProvider:self];

    STPPaymentConfiguration* config = [[STPPaymentConfiguration sharedConfiguration] copy];

    // Forces card requirements to full address. Check `STPBillingAddress` for other options
    [config setRequiredBillingAddressFields: STPBillingAddressFieldsFull];
    
    paymentContext = [[STPPaymentContext alloc]
                      initWithCustomerContext:customerContext
                      configuration:config
                      theme:[STPTheme defaultTheme]];

    paymentContext.delegate = self;
    paymentContext.hostViewController = RCTPresentedViewController();

    if (options[@"amount"] != nil) {
        NSNumber * amount = options[@"amount"];
        paymentContext.paymentCountry = @"IT";
        paymentContext.paymentAmount = [amount intValue];
        paymentContext.paymentCurrency = @"eur";
    }

    initPaymentContextPromiseResolver = resolver;
}

RCT_EXPORT_METHOD(presentPaymentMethodsViewController:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [paymentContext presentPaymentMethodsViewController];

    resolve(@YES);
}

- (void)paymentContextDidChange:(STPPaymentContext *)paymentContext
{
    NSDictionary* selectedCard = nil;

    // Checks if a selected method is available
    if (paymentContext.selectedPaymentMethod != nil) {
        // Converts the template image to a base64 string
        UIImage* templateImage = paymentContext.selectedPaymentMethod.templateImage;
        NSString* cardTemplateImage = [UIImagePNGRepresentation(templateImage) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        NSString* cardLabel = paymentContext.selectedPaymentMethod.label;

        selectedCard = @{
                         @"label": cardLabel,
                         @"templateImage": cardTemplateImage
                        };
        
        // Send updated info to JS
        [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange"
                           body:selectedCard];
    }

    if (initPaymentContextPromiseResolver != nil) {
        initPaymentContextPromiseResolver(selectedCard);
        initPaymentContextPromiseResolver = nil;
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
