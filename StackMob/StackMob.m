// Copyright 2011 StackMob, Inc
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "StackMob.h"
#import "StackMobPushRequest.h"
#import "StackMobRequest.h"
#import "StackMobAdditions.h"
#import "StackMobClientData.h"
#import "StackMobHerokuRequest.h"
#import "StackMobDataProvider.h"

@interface StackMob (Private)
- (void)queueRequest:(StackMobRequest *)request andCallback:(StackMobCallback)callback;
- (void)run;
- (void)next;
- (NSDictionary *)loadInfo;
@end

@implementation StackMob

@synthesize requests;
@synthesize callbacks;
@synthesize session;
@synthesize dataProvider = _dataProvider;

static StackMob *_sharedManager = nil;

- (id) init
{
    self = [super init];
    if(self)
    {
    }
    return self;
}


+ (StackMob *)setApplication:(NSString *)apiKey secret:(NSString *)apiSecret 
                     appName:(NSString *)appName subDomain:(NSString *)subDomain 
              userObjectName:(NSString *)userObjectName apiVersionNumber:(NSNumber *)apiVersion
{
    return [self setApplication:apiKey secret:apiSecret appName:appName subDomain:subDomain
          userObjectName:userObjectName apiVersionNumber:apiVersion dataProvider:nil];
}

+ (StackMob *)setApplication:(NSString *)apiKey secret:(NSString *)apiSecret 
                     appName:(NSString *)appName subDomain:(NSString *)subDomain 
              userObjectName:(NSString *)userObjectName apiVersionNumber:(NSNumber *)apiVersion
                 dataProvider:(id<DataProviderProtocol> )dataProvider
{
    if (_sharedManager == nil) {
        _sharedManager = [[super allocWithZone:NULL] init];
        _sharedManager.session = [[StackMobSession sessionForApplication:apiKey
                                                                  secret:apiSecret
                                                                 appName:appName
                                                               subDomain:subDomain
                                                                  domain:SMDefaultDomain
                                                          userObjectName:userObjectName
                                                        apiVersionNumber:apiVersion] retain];
        _sharedManager.requests = [NSMutableArray array];
        _sharedManager.callbacks = [NSMutableArray array];
        _sharedManager.dataProvider = dataProvider;
        
        if(!dataProvider)
            _sharedManager.dataProvider = [[[StackMobDataProvider alloc]init] autorelease];
        
    }
    return _sharedManager;
    
}

+ (void) setSharedManager:(StackMob *)stackMob
{
    if(_sharedManager != stackMob)
    {
        [_sharedManager release];
        _sharedManager = [stackMob retain];
    }
}

+ (StackMob *)stackmob {
    if (_sharedManager == nil) {
        _sharedManager = [[super allocWithZone:NULL] init];
        NSDictionary *appInfo = [_sharedManager loadInfo];
        _sharedManager.session = [[StackMobSession sessionForApplication:[appInfo objectForKey:@"publicKey"]
                                                                  secret:[appInfo objectForKey:@"privateKey"]
                                                                 appName:[appInfo objectForKey:@"appName"]
                                                               subDomain:[appInfo objectForKey:@"appSubdomain"]
                                                                  domain:[appInfo objectForKey:@"domain"]
                                                          userObjectName:[appInfo objectForKey:@"userObjectName"]
                                                        apiVersionNumber:[appInfo objectForKey:@"apiVersion"]] retain];
        _sharedManager.requests = [NSMutableArray array];
        _sharedManager.callbacks = [NSMutableArray array];
        
        _sharedManager.dataProvider = [[[StackMobDataProvider alloc]init] autorelease];
    }
    return _sharedManager;
}

#pragma mark - Session Methods

- (StackMobRequest *)startSession{
    StackMobRequest *request = [self.dataProvider requestForMethod:@"startsession" withHttpVerb:POST];
    [self queueRequest:request andCallback:nil];
    return request;
}

- (StackMobRequest *)endSession{
    StackMobRequest *request = [self.dataProvider requestForMethod:@"endsession" withHttpVerb:POST];
    [self queueRequest:request andCallback:nil];
    return request;
}

# pragma mark - User object Methods

- (StackMobRequest *)registerWithArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [self.dataProvider requestForMethod:session.userObjectName
                                                   withObject:arguments
                                                    withHttpVerb:POST]; 
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    
    return request;
}

- (StackMobRequest *)loginWithArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [self.dataProvider requestForMethod:[NSString stringWithFormat:@"%@/login", session.userObjectName]
                                                   withObject:arguments
                                                    withHttpVerb:GET]; 
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    
    return request;
}

- (StackMobRequest *)logoutWithCallback:(StackMobCallback)callback
{
    return [self get:@"logout" withCallback:callback];
}

- (StackMobRequest *)getUserInfowithArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    return [self get:session.userObjectName
   withArguments:arguments
  andCallback:callback];
}

# pragma mark - Facebook methods
- (StackMobRequest *)loginWithFacebookToken:(NSString *)facebookToken andCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:facebookToken, @"fb_at", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"facebookLogin" withObject:args withHttpVerb:GET];
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)registerWithFacebookToken:(NSString *)facebookToken username:(NSString *)username andCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:facebookToken, @"fb_at", username, @"username", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"createUserWithFacebook" withObject:args withHttpVerb:GET];
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)linkUserWithFacebookToken:(NSString *)facebookToken withCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:facebookToken, @"fb_at", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"linkUserWithFacebook" withObject:args withHttpVerb:GET];
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    return request;    
}

- (StackMobRequest *)postFacebookMessage:(NSString *)message withCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"message", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"postFacebookMessage" withObject:args withHttpVerb:GET];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)getFacebookUserInfoWithCallback:(StackMobCallback)callback
{
    return [self get:@"getFacebookUserInfo" withCallback:callback];
}

# pragma mark - Twitter methods

- (StackMobRequest *)registerWithTwitterToken:(NSString *)token secret:(NSString *)secret username:(NSString *)username andCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:token, @"tw_tk", secret, @"tw_ts", username, @"username", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"createUserWithTwitter" withObject:args withHttpVerb:GET];
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)loginWithTwitterToken:(NSString *)token secret:(NSString *)secret andCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:token, @"tw_tk", secret, @"tw_ts", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"twitterLogin" withObject:args withHttpVerb:GET];
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    return request;    
}

- (StackMobRequest *)linkUserWithTwitterToken:(NSString *)token secret:(NSString *)secret andCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:token, @"tw_tk", secret, @"tw_ts", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"linkUserWithTwitter" withObject:args withHttpVerb:GET];
    request.isSecure = YES;
    [self queueRequest:request andCallback:callback];
    return request;    
}

- (StackMobRequest *)twitterStatusUpdate:(NSString *)message withCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"tw_st", nil];
    StackMobRequest *request = [self.dataProvider userRequestForMethod:@"twitterStatusUpdate" withObject:args withHttpVerb:GET];
    [self queueRequest:request andCallback:callback];
    return request;    
}

# pragma mark - PUSH Notifications

- (StackMobRequest *)registerForPushWithUser:(NSString *)userId andToken:(NSString *)token andCallback:(StackMobCallback)callback
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:userId, @"user_id", token, @"token", nil];
    StackMobPushRequest *request = [self.dataProvider pushRequest];
    [request setArguments:args];
    [self queueRequest:request andCallback:callback];
    return request;
}

# pragma mark - Heroku methods

- (StackMobRequest *)herokuGet:(NSString *)path withCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [StackMobHerokuRequest requestForMethod:path
                                                               withArguments:NULL
                                                                withHttpVerb:GET];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)herokuGet:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    StackMobHerokuRequest *request = [StackMobHerokuRequest requestForMethod:path
                                                               withArguments:arguments
                                                                withHttpVerb:GET];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)herokuPost:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    StackMobHerokuRequest *request = [StackMobHerokuRequest requestForMethod:path
                                                               withArguments:arguments
                                                                withHttpVerb:POST];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)herokuPut:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    StackMobHerokuRequest *request = [StackMobHerokuRequest requestForMethod:path
                                                               withArguments:arguments
                                                                withHttpVerb:PUT];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)herokuDelete:(NSString *)path andCallback:(StackMobCallback)callback
{
    StackMobHerokuRequest *request = [StackMobHerokuRequest requestForMethod:path
                                                               withArguments:nil
                                                                withHttpVerb:DELETE];
    [self queueRequest:request andCallback:callback];
    return request;
}

# pragma mark - CRUD methods

- (StackMobRequest *)get:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback{
    return [self get:path withObject:arguments andCallback:callback];
}

- (StackMobRequest *)get:(NSString *)path withCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [self.dataProvider requestForMethod:path
                                                        withObject:NULL
                                                      withHttpVerb:GET];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)get:(NSString *)path withObject:(id)object andCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [self.dataProvider requestForMethod:path
                                                        withObject:object
                                                      withHttpVerb:GET]; 
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)post:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    return [self post:path withObject:arguments andCallback:callback];
}

- (StackMobRequest *)post:(NSString *)path forUser:(NSString *)user withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback
{
    return [self post:path forUser:user withObject:arguments andCallback:callback];
}

- (StackMobRequest *)post:(NSString *)path withObject:(id)object andCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [self.dataProvider requestForMethod:path
                                                     withObject:object
                                                      withHttpVerb:POST];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)post:(NSString *)path forUser:(NSString *)user withObject:(id)object
              andCallback:(StackMobCallback)callback
{
    id modifiedObject = object;
    if([object isKindOfClass:[NSDictionary class]])
    {
        modifiedObject = [NSMutableDictionary dictionaryWithDictionary:object];
        [modifiedObject setValue:user forKey:session.userObjectName];
    }

    StackMobRequest *request = [self.dataProvider requestForMethod:[NSString stringWithFormat:@"%@/%@", session.userObjectName, path]
                                                     withObject:modifiedObject
                                                      withHttpVerb:POST];
    [self queueRequest:request andCallback:callback];
    return request;
}

- (StackMobRequest *)put:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback{
    return [self put:path withObject:arguments andCallback:callback];
}

- (StackMobRequest *)put:(NSString *)path withObject:(id)object andCallback:(StackMobCallback)callback;
{
    StackMobRequest *request = [self.dataProvider requestForMethod:path
                                                     withObject:object
                                                      withHttpVerb:PUT];
     [self queueRequest:request andCallback:callback];
     return request;

}

- (StackMobRequest *)destroy:(NSString *)path withArguments:(NSDictionary *)arguments andCallback:(StackMobCallback)callback{
    return [self destroy:path withObject:arguments andCallback:callback];
}

- (StackMobRequest *)destroy:(NSString *)path withObject:(id)object andCallback:(StackMobCallback)callback
{
    StackMobRequest *request = [self.dataProvider requestForMethod:path
                                                     withObject:object
                                                      withHttpVerb:DELETE];
    [self queueRequest:request andCallback:callback];
    return request;
}


# pragma mark - Private methods
- (void)queueRequest:(StackMobRequest *)request andCallback:(StackMobCallback)callback
{
    request.delegate = self;
    
    [self.requests addObject:request];
    if(callback)
        [self.callbacks addObject:Block_copy(callback)];
    else
        [self.callbacks addObject:[NSNull null]];
    
    [callback release];
    
    [self run];
}

- (void)run
{
    if(!_running){
        if([self.requests isEmpty]) return;
        currentRequest = [self.requests objectAtIndex:0];
        [currentRequest sendRequest];
        _running = YES;
    }
}

- (void)next
{
    _running = NO;
    currentRequest = nil;
    [self run];
}

- (NSDictionary *)loadInfo
{
    NSString *filename = [[NSBundle mainBundle] pathForResource:@"StackMob" ofType:@"plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:filename];
    NSMutableDictionary *appInfo = [NSMutableDictionary dictionaryWithDictionary:[info objectForKey:@"production"]];
    SMLog(@"public key: %@", [appInfo objectForKey:@"publicKey"]);
    SMLog(@"private key: %@", [appInfo objectForKey:@"privateKey"]);
    if(!filename || !appInfo){
        [NSException raise:@"StackMob.plist format error" format:@"Please ensure proper formatting.  Toplevel should have 'production' or 'development' key."];
    }
    else if(![appInfo objectForKey:@"publicKey"] || [[appInfo objectForKey:@"publicKey"] length] < 1 || ![appInfo objectForKey:@"privateKey"] || [[appInfo objectForKey:@"privateKey"] length] < 1 ){
        [NSException raise:@"Initialization Error" format:@"Make sure you enter your publicKey and privateKey in StackMob.plist"];
    }
    else if(![appInfo objectForKey:@"appName"] || [[appInfo objectForKey:@"appName"] length] < 1 ){
        [NSException raise:@"Initialization Error" format:@"Make sure you enter your appName in StackMob.plist"];
    }
    else if(![appInfo objectForKey:@"appSubdomain"] || [[appInfo objectForKey:@"appSubdomain"] length] < 1 ){
        [NSException raise:@"Initialization Error" format:@"Make sure you enter your appSubdomain in StackMob.plist"];
    }
    else if(![appInfo objectForKey:@"domain"] || [[appInfo objectForKey:@"domain"] length] < 1 ){
        [NSException raise:@"Initialization Error" format:@"Make sure you enter your domain in StackMob.plist"];
    }
    else if(![appInfo objectForKey:@"apiVersion"]){
        [appInfo setValue:[NSNumber numberWithInt:1] forKey:@"apiVersion"];
    }
    return appInfo;
}

#pragma mark - StackMobRequestDelegate

- (void)requestCompleted:(StackMobRequest*)request {
    if([self.requests containsObject:request]){
        NSInteger idx = [self.requests indexOfObject:request];
        id callback = [self.callbacks objectAtIndex:idx];
        SMLog(@"status %d", request.httpResponse.statusCode);
        if(callback != [NSNull null]){
            StackMobCallback mCallback = (StackMobCallback)callback;
            BOOL wasSuccessful = request.httpResponse.statusCode < 300 && request.httpResponse.statusCode > 199;
            mCallback(wasSuccessful, [request result]);
            Block_release(mCallback);
        }else{
            SMLog(@"no callback found");
        }
        [self.callbacks removeObjectAtIndex:idx];
        [self.requests removeObject:request];
        [self next];
    }
}

# pragma mark - Singleton Conformity

static StackMob *sharedSession = nil;

+ (StackMob *)sharedManager
{
    if (sharedSession == nil) {
        sharedSession = [[super allocWithZone:NULL] init];
    }
    return sharedSession;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedManager] retain];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (oneway void)release
{
    // do nothing
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (id)autorelease
{
    return self;
}
- (void) dealloc
{
    [_dataProvider release];
}

@end
