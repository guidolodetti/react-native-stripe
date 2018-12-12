#import "RNStripe.h"
#import <React/RCTUtils.h>
#import <React/RCTConvert.h>

@implementation RNStripe {
    RCTPromiseResolveBlock initPaymentContextPromiseResolver;

    STPPaymentContext * paymentContext;
    STPCustomerContext * customerContext;
    STPJSONResponseCompletionBlock customerKeyCompletionBlock;
    
    STPRedirectContext * redirectContext;
    STPPaymentIntent * activePaymentIntent;
    
    NSTimer * stripeTimer;
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"RNStripeRequestedCustomerKey", @"RNStripeSelectedPaymentMethodDidChange", @"RNStripePaymentIntentStatusChanged"];
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

    // Setup default theme if supplied
    if (options[@"theme"] != nil) {
        [self setupDefaultThemeWithOptions:options[@"theme"]];
    }

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
    // [config setRequiredBillingAddressFields: STPBillingAddressFieldsFull];
    
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

RCT_EXPORT_METHOD(processPaymentIntent:(NSDictionary*)options) {
    NSLog(@"RNStripe: Process payment intents -> %@ %@", options[@"client_secret"], options[@"return_url"]);
    
    STPSource* card = (STPSource*)paymentContext.selectedPaymentMethod;
    
    STPPaymentIntentParams *paymentIntentParams = [[STPPaymentIntentParams alloc] initWithClientSecret:options[@"client_secret"]];
    paymentIntentParams.sourceId = [card stripeID];
    paymentIntentParams.returnURL = options[@"return_url"];
    
    NSLog(@"RNStripe: Creato oggetto paymentIntentParams");
    
    [[STPAPIClient sharedClient] confirmPaymentIntentWithParams:paymentIntentParams
                                                     completion:^(STPPaymentIntent * _Nullable paymentIntent, NSError * _Nullable error) {
                                                         activePaymentIntent = paymentIntent;
                                                         if (error != nil) {
                                                             NSLog(@"RNStripe: Errore %@", [error localizedDescription]);
                                                             
                                                             [self paymentIntentStatusChange:@"error"];
                                                         } else {
                                                             
                                                             if (paymentIntent.status == STPPaymentIntentStatusRequiresSourceAction) {
                                                                 [self paymentIntentStatusChange:@"shouldRedirect"];
                                                                 
                                                             } else {
                                                                 [self checkIfIntentIsReady:paymentIntent withError:error];
                                                             }
                                                         }
                                                     }];
}

RCT_EXPORT_METHOD(performPaymentIntentRedirect) {
    redirectContext = [[STPRedirectContext alloc]
                       initWithPaymentIntent:activePaymentIntent
                       completion:^(NSString * clientSecret, NSError * _Nullable error) {
                           [self waitUntilIntentIsReady:clientSecret];
                       }];
    
    if (redirectContext) {
        [redirectContext startRedirectFlowFromViewController:paymentContext.hostViewController];
    }
}

- (void)waitUntilIntentIsReady:(NSString *)clientSecret
{
    [[STPAPIClient sharedClient] retrievePaymentIntentWithClientSecret:clientSecret
                                                            completion:^(STPPaymentIntent * _Nullable paymentIntent, NSError * _Nullable error) {
                                                                [self checkIfIntentIsReady:paymentIntent withError:error];
                                                            }];
}

-(void)checkIfIntentIsReady:(STPPaymentIntent * _Nullable)paymentIntent withError:(NSError * _Nullable)error
{
    activePaymentIntent = paymentIntent;
    if (error != nil) {
        [self paymentIntentStatusChange:@"error"];
    } else if (paymentIntent.status == STPPaymentIntentStatusSucceeded || paymentIntent.status == STPPaymentIntentStatusRequiresCapture) {
        [self paymentIntentStatusChange:@"success"];
    } else if (paymentIntent.status == STPPaymentIntentStatusRequiresConfirmation || paymentIntent.status == STPPaymentIntentStatusProcessing) {
        // Wait and check again after 1 sec
        stripeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                        repeats:NO
                                        block:^(NSTimer * _Nonnull timer) {
                                            [self waitUntilIntentIsReady:paymentIntent.clientSecret];
                                        }];
    } else {
        [self paymentIntentStatusChange:@"error"]; // Should never happen
    }
}

- (void)paymentIntentStatusChange:(NSString *)status
{
    [self sendEventWithName:@"RNStripePaymentIntentStatusChanged"
                       body:@{
                              @"status": status
                              }];
}

- (void)paymentContextDidChange:(STPPaymentContext *)paymentContext
{
    NSDictionary* selectedCard = nil;

    // Checks if a selected method is available
    if (paymentContext.selectedPaymentMethod != nil) {
        if ([paymentContext.selectedPaymentMethod isMemberOfClass:[STPCard class]]) {
            STPCard * card = (STPCard*)paymentContext.selectedPaymentMethod;
            NSString * brand = [STPCard stringFromBrand:card.brand];
            NSString * last4 = card.last4;
            selectedCard = @{
                             @"brand": brand,
                             @"last4": last4
                             };
            // Send updated info to JS
            [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange"
                               body:selectedCard];
        } else if ([paymentContext.selectedPaymentMethod isMemberOfClass:[STPSource class]]) {
            STPSourceCardDetails * card = ((STPSource*)paymentContext.selectedPaymentMethod).cardDetails;
            NSString * brand = [STPCard stringFromBrand:card.brand];
            NSString * last4 = card.last4;
            selectedCard = @{
                             @"brand": brand,
                             @"last4": last4
                             };
            // Send updated info to JS
            [self sendEventWithName:@"RNStripeSelectedPaymentMethodDidChange"
                               body:selectedCard];
        }
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

- (void)setupDefaultThemeWithOptions:(NSDictionary*)options {
    [[STPTheme defaultTheme] setPrimaryBackgroundColor:[RCTConvert UIColor:options[@"primaryBackgroundColor"]]];
    [[STPTheme defaultTheme] setSecondaryBackgroundColor:[RCTConvert UIColor:options[@"secondaryBackgroundColor"]]];
    [[STPTheme defaultTheme] setPrimaryForegroundColor:[RCTConvert UIColor:options[@"primaryForegroundColor"]]];
    [[STPTheme defaultTheme] setSecondaryForegroundColor:[RCTConvert UIColor:options[@"secondaryForegroundColor"]]];
    [[STPTheme defaultTheme] setAccentColor:[RCTConvert UIColor:options[@"accentColor"]]];
    [[STPTheme defaultTheme] setErrorColor:[RCTConvert UIColor:options[@"errorColor"]]];
}

@end
