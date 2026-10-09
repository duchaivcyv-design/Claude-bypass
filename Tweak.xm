// language: Logos/ObjC++, file: Tweak.xm
// Nono's forge v5 — iOS 18 Faker huỷ diệt
// Target: com.anthropic.claude + com.apple.AppStore + com.apple.storekitd

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <StoreKit/StoreKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

// =========================================================
// BỘ HẰNG SỐ GIẢ iOS 18
// =========================================================
static NSString *kFakeOS    = @"18.0";
static NSString *kFakeBuild = @"22A3354";
static NSString *kFakeKern  = @"24.0.0";
static NSString *kFakeModel = @"iPhone16,2";
static NSString *kFakeHW    = @"D84AP";
static NSString *kFakeUDID  = @"00008120-001A2D8E3C4B5E6F";
static NSString *kFakeXNU   = @"Darwin Kernel Version 24.0.0: Thu Aug 15 20:14:00 PDT 2024; root:xnu-11215.0.0.1.1~1/RELEASE_ARM64_T8122";
static NSString *kFakeSerial = @"F2LX1234ABCD";

// =========================================================
// HELPERS
// =========================================================
static BOOL isClaude(NSString *bid) {
    if (!bid) return NO;
    return [bid hasPrefix:@"com.anthropic.claude"];
}

static BOOL isAppStoreProcess(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (!bid) return NO;
    if ([bid isEqualToString:@"com.apple.AppStore"]) return YES;
    if ([bid isEqualToString:@"com.apple.storekitd"]) return YES;
    if ([bid isEqualToString:@"com.apple.ios.StoreKitUIService"]) return YES;
    return NO;
}

static BOOL isAppleAPI(NSString *url) {
    if (!url) return NO;
    if ([url containsString:@"amp-api.apps.apple.com"]) return YES;
    if ([url containsString:@"amp-api-edge.apps.apple.com"]) return YES;
    if ([url containsString:@"itunes.apple.com"]) return YES;
    if ([url containsString:@"xp.apple.com"]) return YES;
    if ([url containsString:@"mzstatic.com"]) return YES;
    return NO;
}

static BOOL isUpdateText(NSString *s) {
    if (!s.length) return NO;
    NSString *l = [s lowercaseString];
    NSArray *keys = @[
        @"update", @"cập nhật", @"required", @"latest version",
        @"out of date", @"no longer supported", @"upgrade",
        @"please update", @"new version", @"bản mới",
        @"ios 18", @"requires ios", @"yêu cầu ios",
        @"minimum", @"unsupported version", @"older version",
        @"not supported", @"app requires"
    ];
    for (NSString *k in keys) {
        if ([l containsString:k]) return YES;
    }
    return NO;
}

static NSData *patchJSON(NSData *data) {
    if (!data || data.length < 2) return data;
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data
                                             options:NSJSONReadingMutableContainers
                                               error:&err];
    if (!obj || err) return data;

    NSMutableArray *stack = [NSMutableArray arrayWithObject:obj];
    while (stack.count) {
        id cur = [stack lastObject];
        [stack removeLastObject];

        if ([cur isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *dict = (NSMutableDictionary *)cur;
            [dict removeObjectForKey:@"minimumOsVersion"];
            [dict removeObjectForKey:@"minimumOSVersion"];
            [dict removeObjectForKey:@"requiredCapabilities"];
            [dict removeObjectForKey:@"supportedOSVersion"];
            [dict removeObjectForKey:@"isRestricted"];
            [dict removeObjectForKey:@"restrictions"];
            for (id v in [dict allValues]) {
                if ([v isKindOfClass:[NSDictionary class]] ||
                    [v isKindOfClass:[NSArray class]]) {
                    [stack addObject:v];
                }
            }
        } else if ([cur isKindOfClass:[NSArray class]]) {
            for (id v in (NSArray *)cur) {
                if ([v isKindOfClass:[NSDictionary class]] ||
                    [v isKindOfClass:[NSArray class]]) {
                    [stack addObject:v];
                }
            }
        }
    }

    NSData *patched = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    return patched ?: data;
}

// =========================================================
// TẦNG 1 — UIDevice
// =========================================================
%hook UIDevice
- (NSString *)systemVersion { return kFakeOS; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)model { return kFakeModel; }
- (NSString *)localizedModel { return @"iPhone"; }
- (NSString *)name { return @"iPhone"; }
- (NSString *)buildVersion { return kFakeBuild; }
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
}
- (NSUInteger)majorVersion { return 18; }
- (NSUInteger)minorVersion { return 0; }
- (NSUInteger)patchVersion { return 0; }
- (BOOL)isMultitaskingSupported { return YES; }
- (NSString *)uniqueIdentifier {
    return kFakeUDID;
}
- (NSString *)_deviceInfoForKey:(NSString *)k {
    if ([k isEqualToString:@"BuildVersion"]) return kFakeBuild;
    if ([k isEqualToString:@"ProductVersion"]) return kFakeOS;
    if ([k isEqualToString:@"ProductType"]) return kFakeModel;
    if ([k isEqualToString:@"HardwareModel"]) return kFakeHW;
    if ([k isEqualToString:@"UniqueDeviceID"]) return kFakeUDID;
    if ([k isEqualToString:@"SerialNumber"]) return kFakeSerial;
    return %orig;
}
- (id)_deviceInfoForKey:(NSString *)k defaultValue:(id)d {
    if ([k isEqualToString:@"BuildVersion"]) return kFakeBuild;
    if ([k isEqualToString:@"ProductVersion"]) return kFakeOS;
    if ([k isEqualToString:@"ProductType"]) return kFakeModel;
    return %orig;
}
%end

// =========================================================
// TẦNG 2 — NSProcessInfo
// =========================================================
%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    return (NSOperatingSystemVersion){18, 0, 0};
}
- (NSString *)operatingSystemVersionString {
    return @"Version 18.0 (Build 22A3354)";
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)v {
    return v.majorVersion <= 18;
}
- (NSDictionary *)environment {
    NSMutableDictionary *env = [%orig mutableCopy];
    if (!env) env = [NSMutableDictionary new];
    [env removeObjectForKey:@"SIMULATOR_MODEL_IDENTIFIER"];
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_FORCE_FLAT_NAMESPACE"];
    [env removeObjectForKey:@"_SafeAreaInsetsCache"];
    [env removeObjectForKey:@"JAILBREAK"];
    return env;
}
- (NSString *)hostName {
    return @"iPhone";
}
- (NSString *)globallyUniqueString {
    return [[NSUUID UUID] UUIDString];
}
%end

// =========================================================
// TẦNG 3 — NSBundle
// =========================================================
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *orig = %orig;
    if (!orig) return orig;
    NSMutableDictionary *info = [orig mutableCopy];
    NSString *bid = info[@"CFBundleIdentifier"];
    if (isClaude(bid)) {
        info[@"CFBundleShortVersionString"] = @"99.0.0";
        info[@"CFBundleVersion"] = @"999999";
        info[@"MinimumOSVersion"] = @"15.0";
        info[@"DTPlatformVersion"] = @"18.0";
        info[@"DTSDKName"] = @"iphoneos18.0";
        info[@"DTXcodeBuild"] = @"16A242d";
        info[@"DTPlatformName"] = @"iphoneos";
        info[@"LSMinimumSystemVersion"] = @"14.0";
        info[@"UIDeviceFamily"] = @[@1, @2];
    }
    return info;
}
- (NSString *)objectForInfoDictionaryKey:(NSString *)key {
    NSString *bid = [self bundleIdentifier];
    if (isClaude(bid)) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return @"99.0.0";
        if ([key isEqualToString:@"CFBundleVersion"]) return @"999999";
        if ([key isEqualToString:@"DTPlatformVersion"]) return @"18.0";
        if ([key isEqualToString:@"DTSDKName"]) return @"iphoneos18.0";
        if ([key isEqualToString:@"DTXcodeBuild"]) return @"16A242d";
        if ([key isEqualToString:@"DTPlatformName"]) return @"iphoneos";
        if ([key isEqualToString:@"LSMinimumSystemVersion"]) return @"14.0";
    }
    return %orig;
}
- (NSString *)bundleIdentifier {
    return %orig;
}
%end

// =========================================================
// TẦNG 4 — uname
// =========================================================
static int (*orig_uname)(struct utsname *);
static int my_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (r == 0) {
        strncpy(buf->release, [kFakeKern UTF8String], sizeof(buf->release) - 1);
        strncpy(buf->version, [kFakeXNU UTF8String], sizeof(buf->version) - 1);
        strncpy(buf->machine, "arm64e", sizeof(buf->machine) - 1);
        strncpy(buf->nodename, "iPhone", sizeof(buf->nodename) - 1);
        strncpy(buf->sysname, "Darwin", sizeof(buf->sysname) - 1);
    }
    return r;
}

// =========================================================
// TẦNG 5 — sysctl
// =========================================================
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int r = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (r == 0 && name && namelen >= 2 && oldp && oldlenp) {
        if (name[0] == 1 && name[1] == 2) {
            const char *v = [kFakeKern UTF8String];
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 1 && name[1] == 65) {
            const char *v = [kFakeXNU UTF8String];
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 1 && name[1] == 3) {
            const char *v = "Darwin";
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 6 && name[1] == 1) {
            const char *v = [kFakeModel UTF8String];
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 6 && name[1] == 2) {
            const char *v = [kFakeHW UTF8String];
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 6 && name[1] == 5) {
            const char *v = "arm64e";
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
    }
    return r;
}

// =========================================================
// TẦNG 6 — MobileGestalt
// =========================================================
typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef);
static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef my_MGCopyAnswer(CFStringRef key) {
    NSString *k = (__bridge NSString *)key;
    if ([k isEqualToString:@"ProductVersion"]) return (__bridge CFTypeRef)kFakeOS;
    if ([k isEqualToString:@"BuildVersion"]) return (__bridge CFTypeRef)kFakeBuild;
    if ([k isEqualToString:@"ProductType"]) return (__bridge CFTypeRef)kFakeModel;
    if ([k isEqualToString:@"HardwareModel"]) return (__bridge CFTypeRef)kFakeHW;
    if ([k isEqualToString:@"UniqueDeviceID"]) return (__bridge CFTypeRef)kFakeUDID;
    if ([k isEqualToString:@"kMGQBuildVersion"]) return (__bridge CFTypeRef)kFakeBuild;
    if ([k isEqualToString:@"kMGQProductVersion"]) return (__bridge CFTypeRef)kFakeOS;
    if ([k isEqualToString:@"kMGQDeviceClassNumber"]) return (__bridge CFTypeRef)@(1);
    if ([k isEqualToString:@"DeviceSupportsIOS18"]) return (__bridge CFTypeRef)@(YES);
    if ([k isEqualToString:@"DeviceSupportsIOS17"]) return (__bridge CFTypeRef)@(YES);
    if ([k isEqualToString:@"DeviceSupportsIOS16"]) return (__bridge CFTypeRef)@(YES);
    if ([k isEqualToString:@"DeviceSupportsIOS15"]) return (__bridge CFTypeRef)@(YES);
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(key);
    return NULL;
}

// =========================================================
// TẦNG 7 — StoreKit
// =========================================================
%hook SKStoreProductViewController
- (void)loadProductWithParameters:(NSDictionary *)params completionBlock:(void (^)(BOOL, NSError *))block {
    if (block) block(YES, nil);
}
%end

%hook SKStoreReviewController
+ (void)requestReviewInScene:(id)scene { }
+ (void)requestReview { }
%end

%hook SKPaymentQueue
- (void)addPayment:(SKPayment *)payment { %orig; }
%end

%hook SKProduct
- (NSString *)localizedTitle {
    return %orig;
}
%end

%hook SKProductsRequest
- (void)start { %orig; }
%end

// =========================================================
// TẦNG 8 — UIApplication
// =========================================================
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *u = [url absoluteString];
    if ([u containsString:@"itunes.apple.com"]) return YES;
    if ([u containsString:@"apps.apple.com"]) return YES;
    if ([u hasPrefix:@"itms-apps://"]) return YES;
    if ([u hasPrefix:@"itms://"]) return YES;
    return %orig;
}
- (void)openURL:(NSURL *)url options:(NSDictionary *)opts completionHandler:(void (^)(BOOL))cb {
    NSString *u = [url absoluteString];
    if ([u containsString:@"itunes.apple.com"] ||
        [u containsString:@"apps.apple.com"] ||
        [u hasPrefix:@"itms-apps://"]) {
        if (cb) cb(YES);
        return;
    }
    %orig;
}
- (void)applicationDidEnterBackground:(UIApplication *)app {
    %orig;
    __block UIBackgroundTaskIdentifier tid = UIBackgroundTaskInvalid;
    tid = [self beginBackgroundTaskWithName:@"iOS18Faker.keepalive"
                          expirationHandler:^{
        [self endBackgroundTask:tid];
    }];
}
%end

// =========================================================
// TẦNG 9 — UIAlertController
// =========================================================
%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)t
                                 message:(NSString *)m
                          preferredStyle:(UIAlertControllerStyle)s {
    if (isUpdateText(t) || isUpdateText(m)) {
        return %orig;
    }
    return %orig;
}
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)a
                   completion:(void (^)(void))c {
    %orig;
}
%end

// =========================================================
// TẦNG 10 — UIAlertView (legacy)
// =========================================================
%hook UIAlertView
- (instancetype)initWithTitle:(NSString *)t
                      message:(NSString *)m
                     delegate:(id)d
            cancelButtonTitle:(NSString *)c
            otherButtonTitles:(NSString *)o {
    if (isUpdateText(t) || isUpdateText(m)) {
        return [self initWithTitle:@"" message:@"" delegate:nil
                 cancelButtonTitle:nil otherButtonTitles:nil];
    }
    return %orig;
}
%end

// =========================================================
// TẦNG 11 — NSURLSession
// =========================================================
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))cb {
    NSString *u = [url absoluteString];

    if (isAppleAPI(u) && cb) {
        void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *d, NSURLResponse *r, NSError *e) {
            NSData *patched = patchJSON(d);
            cb(patched, r, e);
        };
        return %orig(url, wrapped);
    }

    if ([u containsString:@"itunes.apple.com"] && [u containsString:@"lookup"]) {
        NSString *fake = @"{\"resultCount\":1,\"results\":[{\"version\":\"99.0.0\"}]}";
        NSData *d = [fake dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:url
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{@"Content-Type":@"application/json"}];
        if (cb) cb(d, resp, nil);
        return nil;
    }

    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))cb {
    NSString *u = [req.URL absoluteString];

    if (isAppleAPI(u) && cb) {
        void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *d, NSURLResponse *r, NSError *e) {
            NSData *patched = patchJSON(d);
            cb(patched, r, e);
        };
        return %orig(req, wrapped);
    }

    return %orig;
}
%end

// =========================================================
// TẦNG 12 — NSURLSessionConfiguration
// =========================================================
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)h {
    NSMutableDictionary *m = [h mutableCopy];
    if (!m) m = [NSMutableDictionary new];
    m[@"X-Client-OS-Version"]   = kFakeOS;
    m[@"X-Client-OS-Build"]     = kFakeBuild;
    m[@"X-Client-OS-Kernel"]    = kFakeKern;
    m[@"X-Client-Device"]       = kFakeModel;
    m[@"X-Apple-I-OS-Version"]  = kFakeOS;
    m[@"X-Apple-I-OS-Build"]    = kFakeBuild;
    m[@"X-Apple-Store-Front"]   = @"143465-19,32";
    m[@"User-Agent"] = [NSString stringWithFormat:@"Claude/99.0.0 iOS/%@ (%@)", kFakeOS, kFakeBuild];
    %orig(m);
}
- (NSDictionary *)HTTPAdditionalHeaders {
    NSDictionary *orig = %orig;
    NSMutableDictionary *m = [orig mutableCopy] ?: [NSMutableDictionary new];
    m[@"X-Apple-I-OS-Version"] = kFakeOS;
    return m;
}
%end

// =========================================================
// TẦNG 13 — NSHTTPURLResponse
// =========================================================
%hook NSHTTPURLResponse
- (NSDictionary *)allHeaderFields {
    NSDictionary *orig = %orig;
    NSMutableDictionary *h = [orig mutableCopy];
    if (!h) h = [NSMutableDictionary new];
    h[@"X-Client-OS-Version"] = kFakeOS;
    h[@"X-Apple-I-OS-Version"] = kFakeOS;
    return h;
}
%end

// =========================================================
// TẦNG 14 — NSJSONSerialization
// =========================================================
%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data
                 options:(NSJSONReadingOptions)opt
                   error:(NSError **)err {
    id r = %orig;
    if (!r && err && *err) {
        if (err) *err = nil;
        return @{};
    }
    return r;
}
%end

// =========================================================
// TẦNG 15 — NSFileManager che jailbreak
// =========================================================
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    if (!path) return %orig;
    if ([path containsString:@"/var/jb/"]) return NO;
    if ([path containsString:@"/Library/MobileSubstrate/"]) return NO;
    if ([path containsString:@"/var/containers/Bundle/tweaksupport"]) return NO;
    if ([path containsString:@"Cydia.app"]) return NO;
    if ([path containsString:@"Sileo.app"]) return NO;
    if ([path containsString:@"/etc/apt"]) return NO;
    if ([path containsString:@"/bin/bash"]) return NO;
    if ([path containsString:@"ssh"]) return NO;
    if ([path containsString:@"frida"]) return NO;
    return %orig;
}
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDir {
    if (!path) return %orig;
    if ([path containsString:@"/var/jb/"]) return NO;
    if ([path containsString:@"/Library/MobileSubstrate/"]) return NO;
    if ([path containsString:@"/var/containers/Bundle/tweaksupport"]) return NO;
    return %orig;
}
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)err {
    if (!path) return %orig;
    if ([path containsString:@"/var/jb"]) return @[];
    if ([path containsString:@"MobileSubstrate"]) return @[];
    return %orig;
}
%end

// =========================================================
// TẦNG 16 — NSException
// =========================================================
static void (*orig_NSExceptionRaise)(id, SEL, NSException *);
static void my_NSExceptionRaise(id self, SEL sel, NSException *e) {
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"Claude"]) return;
    if ([cls containsString:@"Anthropic"]) return;
    if ([cls containsString:@"Store"]) return;
    if ([cls containsString:@"SK"]) return;
    orig_NSExceptionRaise(self, sel, e);
}

// =========================================================
// TẦNG 17 — CFNetwork header
// =========================================================
%hook NSMutableURLRequest
- (void)setValue:(NSString *)v forHTTPHeaderField:(NSString *)f {
    if ([f isEqualToString:@"User-Agent"]) {
        %orig([NSString stringWithFormat:@"Claude/99.0.0 iOS/%@ (%@)", kFakeOS, kFakeBuild]);
        return;
    }
    %orig;
}
- (void)addValue:(NSString *)v forHTTPHeaderField:(NSString *)f {
    if ([f isEqualToString:@"X-Apple-I-OS-Version"]) {
        %orig(kFakeOS);
        return;
    }
    %orig;
}
%end

// =========================================================
// TẦNG 18 — CFPreferencesBundle
// =========================================================
%hook NSUserDefaults
- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"JBDetected"]) return @(NO);
    if ([defaultName isEqualToString:@"isJailbroken"]) return @(NO);
    return %orig;
}
%end

// =========================================================
// TẦNG 19 — CFURLResponse
// =========================================================
%hook NSURLResponse
- (long long)expectedContentLength {
    return %orig;
}
%end

// =========================================================
// TẦNG 20 — Constructor
// =========================================================
%ctor {
    MSHookFunction((void *)uname, (void *)my_uname, (void **)&orig_uname);
    MSHookFunction((void *)sysctl, (void *)my_sysctl, (void **)&orig_sysctl);

    const char *paths[] = {
        "/usr/lib/libMobileGestalt.dylib",
        "/var/jb/usr/lib/libMobileGestalt.dylib",
        "/var/containers/Bundle/tweaksupport/usr/lib/libMobileGestalt.dylib",
        NULL
    };
    void *mg = NULL;
    for (int i = 0; paths[i]; i++) {
        mg = dlopen(paths[i], RTLD_LAZY);
        if (mg) break;
    }
    MGCopyAnswer_t fn = NULL;
    if (mg) fn = (MGCopyAnswer_t)dlsym(mg, "MGCopyAnswer");
    if (!fn) fn = (MGCopyAnswer_t)dlsym(RTLD_DEFAULT, "MGCopyAnswer");
    if (fn) {
        orig_MGCopyAnswer = fn;
        MSHookFunction((void *)fn, (void *)my_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    }

    MSHookMessageEx(objc_getClass("NSException"),
                    @selector(raise),
                    (IMP)my_NSExceptionRaise,
                    (IMP *)&orig_NSExceptionRaise);
}
