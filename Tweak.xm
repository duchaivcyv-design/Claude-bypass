// language: Logos/ObjC++, file: Tweak.xm, target: com.anthropic.claude
// Nono's forge v3.3

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <StoreKit/StoreKit.h>

static NSString *kFakeOS = @"18.0";
static NSString *kFakeBuild = @"22A3354";
static NSString *kFakeKern = @"24.0.0";
static NSString *kFakeModel = @"iPhone16,2";

static BOOL isClaude(NSString *bid) {
    if (!bid) return NO;
    return [bid hasPrefix:@"com.anthropic.claude"];
}

static BOOL isUpdateText(NSString *s) {
    if (!s.length) return NO;
    NSString *l = [s lowercaseString];
    NSArray *keys = @[@"update", @"cập nhật", @"required", @"latest version",
                      @"out of date", @"no longer supported", @"upgrade",
                      @"please update", @"new version", @"bản mới",
                      @"ios 18", @"requires ios", @"yêu cầu ios"];
    for (NSString *k in keys) {
        if ([l containsString:k]) return YES;
    }
    return NO;
}

// UIDevice
%hook UIDevice
- (NSString *)systemVersion { return kFakeOS; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)model { return kFakeModel; }
- (NSString *)buildVersion { return kFakeBuild; }
- (NSUInteger)majorVersion { return 18; }
- (NSUInteger)minorVersion { return 0; }
- (NSUInteger)patchVersion { return 0; }
%end

// NSProcessInfo
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
%end

// NSBundle
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
    }
    return %orig;
}
%end

// uname hook
static int (*orig_uname)(struct utsname *);
static int my_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (r == 0) {
        strncpy(buf->release, [kFakeKern UTF8String], sizeof(buf->release) - 1);
        strncpy(buf->version, "Darwin Kernel Version 24.0.0", sizeof(buf->version) - 1);
        strncpy(buf->machine, "arm64e", sizeof(buf->machine) - 1);
        strncpy(buf->nodename, "iPhone", sizeof(buf->nodename) - 1);
    }
    return r;
}

// sysctl hook
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int r = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (r == 0 && name && namelen >= 2 && oldp && oldlenp) {
        if (name[0] == 1 && name[1] == 2) {
            const char *v = [kFakeKern UTF8String];
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) {
                memcpy(oldp, v, len);
                *oldlenp = len;
            }
        }
        if (name[0] == 6 && name[1] == 1) {
            const char *v = [kFakeModel UTF8String];
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) {
                memcpy(oldp, v, len);
                *oldlenp = len;
            }
        }
    }
    return r;
}

// MobileGestalt
typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef);
static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef my_MGCopyAnswer(CFStringRef key) {
    NSString *k = (__bridge NSString *)key;
    if ([k isEqualToString:@"ProductVersion"]) return (__bridge CFTypeRef)kFakeOS;
    if ([k isEqualToString:@"BuildVersion"]) return (__bridge CFTypeRef)kFakeBuild;
    if ([k isEqualToString:@"ProductType"]) return (__bridge CFTypeRef)kFakeModel;
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(key);
    return NULL;
}

// StoreKit
%hook SKStoreProductViewController
- (void)loadProductWithParameters:(NSDictionary *)params completionBlock:(void (^)(BOOL, NSError *))block {
    if (block) block(YES, nil);
}
%end

%hook SKStoreReviewController
+ (void)requestReviewInScene:(id)scene { }
+ (void)requestReview { }
%end

// UIApplication
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *u = [url absoluteString];
    if ([u containsString:@"itunes.apple.com"]) return YES;
    if ([u containsString:@"apps.apple.com"]) return YES;
    if ([u hasPrefix:@"itms-apps://"]) return YES;
    return %orig;
}
%end

// UIAlertController
%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)t message:(NSString *)m preferredStyle:(UIAlertControllerStyle)s {
    if (isUpdateText(t) || isUpdateText(m)) {
        return %orig;
    }
    return %orig;
}
%end

// NSURLSession
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))cb {
    NSString *u = [url absoluteString];
    if ([u containsString:@"itunes.apple.com"] && [u containsString:@"lookup"]) {
        NSString *fake = @"{\"resultCount\":1,\"results\":[{\"version\":\"99.0.0\"}]}";
        NSData *d = [fake dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
        if (cb) cb(d, resp, nil);
        return nil;
    }
    return %orig;
}
%end

%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)h {
    NSMutableDictionary *m = [h mutableCopy];
    if (!m) m = [NSMutableDictionary new];
    m[@"X-Client-OS-Version"] = kFakeOS;
    m[@"X-Client-OS-Build"] = kFakeBuild;
    m[@"User-Agent"] = [NSString stringWithFormat:@"Claude/99.0.0 iOS/%@", kFakeOS];
    %orig(m);
}
%end

// NSException
static void (*orig_NSExceptionRaise)(id, SEL, NSException *);
static void my_NSExceptionRaise(id self, SEL sel, NSException *e) {
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"Claude"]) return;
    if ([cls containsString:@"Anthropic"]) return;
    orig_NSExceptionRaise(self, sel, e);
}

// Constructor
%ctor {
    MSHookFunction((void *)uname, (void *)my_uname, (void **)&orig_uname);
    MSHookFunction((void *)sysctl, (void *)my_sysctl, (void **)&orig_sysctl);

    void *mg = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (mg) {
        MGCopyAnswer_t fn = (MGCopyAnswer_t)dlsym(mg, "MGCopyAnswer");
        if (fn) {
            orig_MGCopyAnswer = fn;
            MSHookFunction((void *)fn, (void *)my_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
        }
    }

    MSHookMessageEx(objc_getClass("NSException"), @selector(raise), (IMP)my_NSExceptionRaise, (IMP *)&orig_NSExceptionRaise);
}
