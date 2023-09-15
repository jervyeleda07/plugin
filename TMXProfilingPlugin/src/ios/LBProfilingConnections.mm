//
//  LBProfilingConnections.m
//  LemonBank
//
//  Copyright © 2020 ThreatMetrix. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "LBProfilingConnections.h"

#define DEFAULT_CONNECTION_TIMEOUT_SEC 10

@interface LBProfilingConnections()
@property(nonatomic, readwrite) NSURLSession *urlSession;
@property(nonatomic, readwrite) NSTimeInterval timeoutSec;
@property(nonatomic, readwrite, strong) NSInputStream* inputStream;
@property(nonatomic, readwrite, strong) NSOutputStream* outputStream;
@property(nonatomic, readwrite, strong) NSObject* lockObject;

-(BOOL) sendData:(NSData*)data;
@end

@implementation LBProfilingConnections

- (instancetype)init
{
    self = [super init];
    _timeoutSec   = 20;
    _inputStream  = nil;
    _outputStream = nil;
    _lockObject   = [[NSObject alloc] init];
    
    // In this implementation we use NSURLSession to manage connections
    // set session timeouts
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest  = _timeoutSec;
    config.timeoutIntervalForResource = _timeoutSec;

    // creating a dedicated queue for connection to avoid using main queue (and slowing down the UI actions)
    NSOperationQueue *delegateQueue = [[NSOperationQueue alloc] init];
    delegateQueue.maxConcurrentOperationCount = 1;
    [delegateQueue setName:@"com.threatmetrix.lemonbank.connectionqueue"];

    // creating one NSURLSession object for all connections
    _urlSession  = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:delegateQueue];
    return self;
}

- (void)dealloc
{
    [self.urlSession finishTasksAndInvalidate];
}

-(BOOL) sendData:(NSData*)data
{
    BOOL sendSuccess = YES;
    NSDate *start    = [NSDate date];
    BOOL timedOut    = NO;
    @try
    {
        if(![self.outputStream streamError] &&
           ([self.outputStream streamStatus] == NSStreamStatusOpen || [self.outputStream streamStatus] == NSStreamStatusOpening))
        {
            while (![self.outputStream hasSpaceAvailable])
            {
                if([[NSDate date] timeIntervalSinceDate:start] > (DEFAULT_CONNECTION_TIMEOUT_SEC))
                {
                    sendSuccess = NO;
                    timedOut    = YES;
                    break;
                }
                [NSThread sleepForTimeInterval:0.1];
            }
            
            if(![self.outputStream streamError] && !timedOut)
            {
                [self.outputStream write:(const uint8_t *)[data bytes] maxLength:[data length]];
            }
        }
        else
        {
            sendSuccess = NO;
        }
    }
    @catch(NSException *e)
    {
        sendSuccess = NO;
    }
    return sendSuccess;
}

#pragma mark TMXProfilingConnections methods

- (void)httpProfilingRequestWithUrl:(NSURL * _Nonnull)url method:(TMXProfilingConnectionMethod)method headers:(NSDictionary * _Nullable)headers postBody:(NSData * _Nullable)postData completionHandler:(void (^ _Nullable)(NSData * _Nullable, NSError * _Nullable))completionHandler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:self.timeoutSec];
    [request setHTTPMethod:(method == TMXProfilingConnectionMethodPost) ? @"POST" : @"GET"];
    [request setHTTPBody:postData];
    [request setHTTPShouldHandleCookies:NO];
    if([headers count] > 0)
    {
        //add headers
        [request setAllHTTPHeaderFields:headers];
    }

    NSURLSessionTask *task = [self.urlSession dataTaskWithRequest:request  completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable __unused response, NSError * _Nullable error) {
        completionHandler(data, error);
    }];
    [task resume];
}

- (void)cancelProfiling
{
    [self.urlSession getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * __unused _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * __unused _Nonnull downloadTasks) {
        if(dataTasks.count > 0)
        {
            for(NSURLSessionDataTask *task in dataTasks)
            {
                if(task.state == NSURLSessionTaskStateRunning)
                {
                    [task cancel];
                }
            }
        }
    }];
}

- (void)resolveProfilingHostName:(NSString * _Nonnull)host
{
    @try
    {
        CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)host);
        if (hostRef)
        {
            CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL);
            /* ignore return, we don't care about the actual address returned */
            CFRelease(hostRef);
        }
    }
    @catch(NSException *runtimeEx)
    {
        NSLog(@"Host resolution failure: %@", runtimeEx.reason);
    }
}

/*
 Note: socketProfilingRequestWithHost is deprecated and will be removed in future releases
 */
- (void)socketProfilingRequestWithHost:(NSString *)host port:(int)port data:(NSData *)data
{
    __block NSURLSessionStreamTask *task = [self.urlSession streamTaskWithHostName:host port:port];
    [task resume];

    [task writeData:data timeout:self.timeoutSec completionHandler:^(NSError * _Nullable error) {
        if(error)
        {
            NSLog(@"Stream write failure: %ld", (long)error.code);
        }

        [task closeWrite];
        [task closeRead];
    }];
}

- (void)sendSocketRequest:(NSString*)host port:(unsigned short)port data:(NSData*)data close:(BOOL)closeSocket completionHandler:(void (^)(NSInputStream* result, NSError* error))completionHandler
{
    @synchronized(self.lockObject)
    {
        if(self.outputStream == nil)
        {
            if(self.inputStream != nil)
            {
                [self.inputStream close];
                self.inputStream = nil;
            }
            
            CFReadStreamRef readStream;
            CFWriteStreamRef writeStream;
            CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &readStream, &writeStream);

            self.outputStream = (__bridge NSOutputStream *)writeStream;
            self.inputStream  = (__bridge NSInputStream *)readStream;
            [self.outputStream open];
            [self.inputStream open];
        }
        
        NSError *connectionError = nil;
        @try
        {
            if(data == nil         ||
               [data length] == 0  ||
               port < 1            ||
               host == nil         ||
               [host length] == 0)
            {
                connectionError = [NSError errorWithDomain:@"Incorrect arguments" code:kCFSOCKS4ErrorRequestFailed userInfo:nil];
                return;
            }

            if(![self sendData:data])
            {
                connectionError = [NSError errorWithDomain:@"Send Socket Request failed" code:kCFSOCKS4ErrorRequestFailed userInfo:nil];
            }
            
            if(closeSocket)
            {
                [self closeSocket:host port:port];
            }
        }
        @catch (NSException *exception)
        {
            connectionError = [NSError errorWithDomain:@"Send Socket Request failed with Exception" code:kCFSOCKS4ErrorRequestFailed userInfo:nil];
        }
        @finally
        {
            if(completionHandler != nil)
            {
                completionHandler(self.inputStream, connectionError);
            }
        }
    }
}

- (void)closeSocket:(NSString*)host port:(unsigned short)port NS_SWIFT_NAME(closeSocket(host:port:))
{
    @synchronized(self.lockObject)
    {
        if(self.outputStream != nil)
        {
            [self.outputStream close];
            self.outputStream = nil;
        }
        
        if(self.inputStream != nil)
        {
            [self.inputStream close];
            self.inputStream = nil;
        }
    }
}

@end
