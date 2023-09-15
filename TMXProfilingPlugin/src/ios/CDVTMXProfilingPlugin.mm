//
//  TMXProfilingPlugin.mm
//  CitySavingsBank
//
//  Copyright (c) ThreatMetrix. All rights reserved.
//

#import "CDVTMXProfilingPlugin.h"
#import "LBProfilingConnections.h"
// #import "LBViewController.h"

@interface TMXProfilingPlugin()
@property(readwrite, nonatomic) NSString* sessionID;
@property(readwrite, nonatomic) TMXProfileHandle *profileHandle;
@end

NSString *const ORG_ID          = @"bkycs9pf";
NSString *const FP_SERVER       = @"fms-dev.citysavings.net.ph";
BOOL useTMXProfilingConnections = YES;
BOOL passUsernameAsMaskedField  = NO;

@implementation TMXProfilingPlugin

- (instancetype)init
{
    self = [super init];

    _sessionID      = nil;
    _profileTimeout = @20;

    id connectionInstance;
    if(useTMXProfilingConnections)
    {
        /*
         * Optionally you can configure TMXProfilingConnections, if so please pass the configured
         * instance to configure method. On the other hand, if you prefer to use TMXProfilingConnection
         * default settings, there is no need to create an instance of it.
         * */
        TMXProfilingConnections *profilingConnections = [[TMXProfilingConnections alloc] init];
        profilingConnections.connectionTimeout        = 20; // Default value is 10 seconds
        profilingConnections.connectionRetryCount     = 2;  // Default value is 0 (no retry)
        connectionInstance = profilingConnections;
    }
    else
    {
        /*
         * If you decide to implement TMXProfilingConnectionsProtocol you should create an instance of your
         * implementation and pass it to configure method.
         */
        connectionInstance = [[LBProfilingConnections alloc] init];
    }

    // The profile.configure method is effective only once and subsequent calls to it will be ignored.
    // Please note that configure may throw NSException if NSDictionary key/value(s) are invalid.
    // This only happen due to programming error, therefore we don't catch the exception to make sure there is no error in our configuration dictionary
    [[TMXProfiling sharedInstance] configure:@{
                                               // (REQUIRED) Organisation ID
                                               TMXOrgID              : ORG_ID,
                                               // (REQUIRED) Enhanced fingerprint server
                                               TMXFingerprintServer  : FP_SERVER,
                                               // (OPTIONAL) Set the profile timeout, in seconds
                                               TMXProfileTimeout     : _profileTimeout,
                                               // (OPTIONAL) If Keychain Access sharing groups are used, specify it
                                               TMXKeychainAccessGroup: @"<TEAM_ID>.<BUNDLE_ID>",
                                               // (OPTIONAL) Register for location service updates.
                                               // Requires permission to access to device location.
                                               TMXLocationServices   : @YES,
                                               // (OPTIONAL) Pass the configured instance of TMXProfilingConnections to TMX SDK.
                                               // If not passed, configure method tries to create and instance of TMXProfilingConnections
                                               // with the default settings.
                                               TMXProfilingConnectionsInstance : connectionInstance
    }];
    return self;
}

- (void)doProfile
{
    // (OPTIONAL) Assign some custom attributes to be included with the profiling information
    NSArray *customAttributes = @[@"attribute 1", @"attribute 2"];

    // (OPTIONAL) Pass a set of View Controllers to be monitored by TMXBehavioSec module.
    // If not passed all ViewControllers will be monitored.
    //NSSet *includedViews = [NSSet setWithObject:NSStringFromClass(LBViewController.class)];

    NSMutableDictionary *profilingOptions        = [NSMutableDictionary dictionaryWithCapacity:3];
    profilingOptions[TMXCustomAttributes]        = customAttributes;
    // profilingOptions[TMXBehavioSecIncludedViews] = includedViews;

    if(passUsernameAsMaskedField)
    {
        // (OPTIONAL) Define a set of "Behavio Tracking Id" of UITextFields that are marked secure in your application UI
        // but your company consider them as sensitive.
        NSSet *maskedFields = [NSSet setWithObject:@"login_username"];
        profilingOptions[TMXBehavioSecMaskedFields] = maskedFields;
    }

    // Fire off the profiling request.
    self.profileHandle = [[TMXProfiling sharedInstance] profileDeviceUsing:profilingOptions callbackBlock:^(NSDictionary * _Nullable result) {
        TMXStatusCode statusCode = [[result valueForKey:TMXProfileStatus] integerValue];
        if(statusCode == TMXStatusCodeOk)
        {
            // No errors, profiling succeeded!
        }
        NSLog(@"Profile completed with: %@ and session ID: %@", [self stringFromStatus:statusCode], [result valueForKey:TMXSessionID]);

        [self performSelectorOnMainThread:@selector(signalViewController:) withObject:@{DICTIONARY_KEY_TYPE : ACTION_TYPE_PROFILE, DICTIONARY_KEY_SDK_RESULT : result} waitUntilDone:NO];
    }];

    // Session id can be collected here (to use in API call (AKA session query))
    self.sessionID = self.profileHandle.sessionID;
    NSLog(@"Session id is %@", self.sessionID);

    /*
     * profileHandle can also be used to cancel this profile if needed
     *
     * [profileHandle cancel];
     * */
}

- (void)registerUser:(NSString *)username
{
    NSString *registerSessionID = [[TMXProfiling sharedInstance] registerUserContext:username prompt:@"Please authenticate for registration" completionCallback:^(NSDictionary * _Nullable result) {
        TMXStatusCode statusCode = [[result valueForKey:TMXProfileStatus] integerValue];
        NSLog(@"Registration completed with: %@ and session ID: %@", [self stringFromStatus:statusCode], [result valueForKey:TMXSessionID]);
        [self performSelectorOnMainThread:@selector(signalViewController:) withObject:@{DICTIONARY_KEY_TYPE : ACTION_TYPE_REGISTER, DICTIONARY_KEY_SDK_RESULT : result} waitUntilDone:NO];
    }];

    self.sessionID = registerSessionID;
}

/*!
 * Create a notification which holds the result of profiling / registration and posts it to the notification center.
 * LBViewController is registered to receive this notification and update UI accordingly.
 * Please note that updating UI should be done on the main thread, therefore this method should be called on the main
 * thread.
 *
 * @param result Profiling or registration result.
 */
-(void)signalViewController:(NSDictionary *)result
{
    NSString *type = result[DICTIONARY_KEY_TYPE];
    if([type isEqualToString:ACTION_TYPE_PROFILE] || [type isEqualToString:ACTION_TYPE_REGISTER])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_SHOW_DATA object:self userInfo:result];
        return;
    }

    NSLog(@"Notification is not known %@, returning without any action", result);
}

/*!
 * Passes notifications (received in LBAppDelegate) to ThreatMetrix SDK for processing and authenticating user.
 *
 * @param userInfo notification payload
 */
- (void)handleNotification:(NSDictionary *)notification
{
    NSString *sessionID = [[TMXProfiling sharedInstance] processStrongAuthPrompt:notification completionCallback:^(NSDictionary * _Nullable result) {
        TMXStatusCode statusCode = [[result valueForKey:TMXProfileStatus] integerValue];
        NSLog(@"Registration completed with: %@ and session ID: %@", [self stringFromStatus:statusCode], [result valueForKey:TMXSessionID]);
    }];

    NSLog(@"Processing notification for session id is %@", sessionID);
}

- (void)sendDeviceTokenToTmxSdk:(NSData *)deviceToken
{
    // Got the device token (used for receiving notifications) pass it to ThreatMetrix SDK
    [[TMXProfiling sharedInstance] setStepupToken:deviceToken];
}

-(NSString *)stringFromStatus:(TMXStatusCode)status
{
    switch(status)
    {
        case TMXStatusCodeOk:
        case TMXStatusCodeStrongAuthOK:
            return @"OK";
        case TMXStatusCodeNetworkTimeoutError:
            return @"Network Time out";
        case TMXStatusCodeConnectionError:
            return @"Connection Error";
        case TMXStatusCodeHostNotFoundError:
            return @"Host not found error";
        case TMXStatusCodeInternalError:
            return @"Internal Error";
        case TMXStatusCodeInterruptedError:
            return @"Interrupted";
        case TMXStatusCodeNotConfigured:
            return @"Not Configured";
        case TMXStatusCodeCertificateMismatch:
            return @"Certificate Mismatch";
        case TMXStatusCodeInvalidParameter:
            return @"Internal Error";
        case TMXStatusCodeStrongAuthFailed:
            return @"Strong Authentication failed";
        case TMXStatusCodeStrongAuthUserNotFound:
            return @"User is not registered on the device";
        case TMXStatusCodeStrongAuthAlreadyRegistered:
            return @"User is already registered";
        case TMXStatusCodeStrongAuthCancelled:
            return @"User cancelled authentication";
        case TMXStatusCodeStrongAuthUnsupported:
            return @"Strong Authentication is not supported";
        default:
            return @"Other";
    }
}

@end

