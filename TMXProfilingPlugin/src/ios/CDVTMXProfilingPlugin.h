//
//  LBProfileController.h
//  LemonBank
//
//  Copyright (c) ThreatMetrix. All rights reserved.
//
#if defined(__has_feature) && __has_feature(modules)
@import Foundation;
@import UserNotifications;
@import TMXProfiling;
@import TMXProfilingConnections;
#else
#import <UserNotifications/UserNotifications.h>
#import <Foundation/Foundation.h>
#import <TMXProfiling/TMXProfiling.h>
#import <TMXProfilingConnections/TMXProfilingConnections.h>
#endif

/// Constants used when passing result of profile / register to UI
#define DICTIONARY_KEY_TYPE         @"type"
#define DICTIONARY_KEY_SDK_RESULT   @"sdk_result"
#define NOTIFICATION_NAME_SHOW_DATA @"notification_name_show_data"
#define ACTION_TYPE_PROFILE         @"1"
#define ACTION_TYPE_REGISTER        @"3"

/// This object handles setting up and calling the profiling function
@interface TMXProfilingPlugin : NSObject

/// Session id used in profiling and registration. Profiling session id can be created by ThreatMetrix SDK
/// or passed to profiling request. NOTE: session id must be unique otherwise the result of API call will
/// be unexpected.
@property (readonly, nonatomic) NSString *sessionID;

//// TMXProfileHandle can be used for cancelling profiling, getting session id and also force sending TMXBehavioSec information to backend.
@property (readonly, nonatomic) TMXProfileHandle* profileHandle;

/// This timeout is used to set the maximum time for the entire profiling from start to the time the callback block method returns a result
@property(readonly) NSNumber *profileTimeout;

/// Configures ThreatMetrix SDK to make sure profiling can start when application starts.
- (instancetype)init;

/// Starts profiling process and sets a flag when profiling is finished.
- (void)doProfile;

/// Starts active registration process
- (void)registerUser:(NSString *)username;

/// Pass device token to ThreatMetrix SDK to be used when receiving a notification
- (void) sendDeviceTokenToTmxSdk:(NSData *)deviceToken;

/// handle StrongAuth notifications
-(void) handleNotification:(NSDictionary *)notification;

@end
