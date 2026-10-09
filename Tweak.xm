// language: Logos/ObjC++, file: Tweak.xm, target: com.anthropic.claude
// Nono's forge v3 — giả iOS 18 toàn diện, chặn mọi path check iOS + StoreKit update.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <StoreKit/StoreKit.h>

// =========================================================
// 0. BỘ GIÁ TRỊ iOS 18 KHỚP MỌI FIELD
// =========================================================
static NSString *const kFakeOS    = @"18.0";
static NSString *const kFakeBuild = @"22A3354";       // iOS 18.0 GM
static NSString *const kFakeKern  = @"24.0.0";
static NSString *const kFakeModel = @"iPhone16,2";    // iPhone 15 Pro Max
static NSString *const kFakeUDID  = @"00008120-001A2D8E3C4B5E6F"; // format iOS 18

// =========================================================
// 1. UIDevice — bề mặt chính
// =========================================================
%hook UIDevice
- (NSString *)systemVersion { return kFakeOS; }
- (NSString *)systemName    { return @"iOS"; }
- (NSString *)model         { return kFakeModel; }
- (NSString *)localizedModel{ return @"iPhone"; }
- (NSString *)name          { return @"iPhone"; }
- (NSString *)buildVersion  { return kFakeBuild; }
- (NSUUID *)identifierForVendor { return [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]; }
- (NSUInteger)majorVersion  { return 18; }
- (NSUInteger)minorVersion  { return 0; }
- (NSUInteger)patchVersion  { return 0; }
- (BOOL)isMultitaskingSupported { return YES; }
%end

// =========================================================
// 2. NSProcessInfo — SDK thường đọc
// =========================================================
%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    return (NSOperatingSystemVersion){18, 0, 0};
}
- (NSString *)operatingSystemVersionString {
    return @"Version 18.0 (Build 22A3354)";
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)v {
    if (v.majorVersion <= 18) return YES;
    return NO;
}
%end

// =========================================================
// 3. NSBundle — version app + minimum OS
// =========================================================
static BOOL isClaude(NSString *bid) {
    return [bid hasPrefix:@"com.anthropic.claude"];
}

%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *info = [orig_infoDictionary() mutableCopy];
    NSString *bid = info[@"CFBundleIdentifier"] ?: @"";
    if (isClaude(bid)) {
        info[@"CFBundleShortVersionString"] = @"99.0.0";
        info[@"CFBundleVersion"]            = @"999999";
        info[@"MinimumOSVersion"]           = @"15.0";
        info[@"DTPlatformVersion"]          = @"18.0";
        info[@"DTSDKName"]                  = @"iphoneos18.0";
        info[@"DTXcodeBuild"]               = @"16A242d";
    }
    return info;
}
- (NSString *)objectForInfoDictionaryKey:(NSString *)key {
    NSString *bid = [self bundleIdentifier] ?: @"";
    if (isClaude(bid)) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return @"99.0.0";
        if ([key isEqualToString:@"CFBundleVersion"])            return @"999999";
        if ([key isEqualToString:@"DTPlatformVersion"])          return @"18.0";
        if ([key isEqualToString:@"DTSDKName"])                  return @"iphoneos18.0";
    }
    return %orig;
}
%end

// =========================================================
// 4. uname + sysctl — kernel + hardware
// =========================================================
static int (*orig_uname)(struct utsname *);
static int my_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (r == 0) {
        strncpy(buf->release, kFakeKern.UTF8String, sizeof(buf->release) - 1);
        strncpy(buf->version,
                "Darwin Kernel Version 24.0.0: Thu Aug 15 20:14:00 PDT 2024; "
                "root:xnu-11215.0.0.1.1~1/RELEASE_ARM64_T8122",
                sizeof(buf->version) - 1);
        strncpy(buf->machine, "arm64e", sizeof(buf->machine) - 1);
        strncpy(buf->nodename, "iPhone", sizeof(buf->nodename) - 1);
    }
    return r;
}

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int r = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (r == 0 && name && namelen >= 2) {
        // CTL_KERN=1, KERN_OSRELEASE=2 → "24.0.0"
        if (name[0] == 1 && name[1] == 2 && oldp && oldlenp) {
            const char *v = kFakeKern.UTF8String;
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        // CTL_KERN=1, KERN_OSVERSION=65 → build string
        if (name[0] == 1 && name[1] == 65 && oldp && oldlenp) {
            const char *v = "Darwin Kernel Version 24.0.0: root:xnu-11215.0.0.1.1~1/RELEASE_ARM64_T8122";
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        // CTL_HW=6, HW_MACHINE=1 → "iPhone16,2"
        if (name[0] == 6 && name[1] == 1 && oldp && oldlenp) {
            const char *v = kFakeModel.UTF8String;
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
    }
    return r;
}

// =========================================================
// 5. MobileGestalt — API ngách Apple dùng nội bộ
// =========================================================
typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef);
static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef my_MGCopyAnswer(CFStringRef key) {
    NSString *k = (__bridge NSString *)key;
    if ([k isEqualToString:@"ProductVersion"])   return (__bridge CFTypeRef)kFakeOS;
    if ([k isEqualToString:@"BuildVersion"])     return (__bridge CFTypeRef)kFakeBuild;
    if ([k isEqualToString:@"ProductType"])      return (__bridge CFTypeRef)kFakeModel;
    if ([k isEqualToString:@"HardwareModel"])    return (__bridge CFTypeRef)@"D84AP";
    if ([k isEqualToString:@"UniqueDeviceID"])   return (__bridge CFTypeRef)kFakeUDID;
    if ([k isEqualToString:@"kMGQBuildVersion"]) return (__bridge CFTypeRef)kFakeBuild;
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(key);
    return NULL;
}

// =========================================================
// 6. StoreKit / App Store — chặn đòi iOS 18, chặn update prompt
// =========================================================
%hook SKStoreProductViewController
- (void)loadProductWithParameters:(NSDictionary *)params
                  completionBlock:(void (^)(BOOL, NSError *))block {
    // nuốt toàn bộ — không cho mở App Store page
    if (block) block(YES, nil);
}
%end

%hook SKStoreReviewController
+ (void)requestReviewInScene:(id)scene { /* no-op */ }
+ (void)requestReview { /* no-op */ }
%end

// Chặn app gọi openURL tới App Store / itunes
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *u = url.absoluteString ?: @"";
    if ([u containsString:@"itunes.apple.com"] ||
        [u containsString:@"apps.apple.com"] ||
        [u hasPrefix:@"itms-apps://"] ||
        [u hasPrefix:@"itms://"]) {
        return YES; // giả thành công, không mở
    }
    return %orig;
}
- (void)openURL:(NSURL *)url options:(NSDictionary *)opts completionHandler:(void (^)(BOOL))cb {
    NSString *u = url.absoluteString ?: @"";
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
    UIBackgroundTaskIdentifier tid =
        [self beginBackgroundTaskWithName:@"ClaudeGuard.keepalive"
                        expirationHandler:^{
            [self endBackgroundTask:tid];
        }];
}
%end

// =========================================================
// 7. Alert — nuốt mọi dialog đòi update / đòi iOS 18
// =========================================================
static BOOL isUpdateText(NSString *s) {
    if (!s.length) return NO;
    NSString *l = s.lowercaseString;
    NSArray *keys = @[@"update", @"cập nhật", @"required", @"latest version",
                      @"out of date", @"no longer supported", @"upgrade",
                      @"please update", @"new version", @"bản mới",
                      @"ios 18", @"requires ios", @"yêu cầu ios",
                      @"minimum", @"unsupported version"];
    for (NSString *k in keys) if ([l containsString:k]) return YES;
    return NO;
}

%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)t
                                 message:(NSString *)m
                          preferredStyle:(UIAlertControllerStyle)s {
    if (isUpdateText(t) || isUpdateText(m)) {
        return [orig_alertControllerWithTitle:@"" message:@"" preferredStyle:s];
    }
    return %orig;
}
%end

%hook UIAlertView
- (instancetype)initWithTitle:(NSString *)t
                      message:(NSString *)m
                     delegate:(id)d
            cancelButtonTitle:(NSString *)c
            otherButtonTitles:(NSString *)o, ... {
    if (isUpdateText(t) || isUpdateText(m)) {
        return [orig_initWithTitle:@"" message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    }
    va_list args; va_start(args, o);
    id r = %orig;
    va_end(args);
    return r;
}
%end

// =========================================================
// 8. Network — fake itunes lookup + ép header version
// =========================================================
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))cb {
    NSString *u = url.absoluteString ?: @"";
    if ([u containsString:@"itunes.apple.com"] && [u containsString:@"lookup"]) {
        NSString *fake = @"{\"resultCount\":1,\"results\":[{\"version\":\"99.0.0\",\"trackId\":0,\"minimumOsVersion\":\"15.0\"}]}";
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
%end

%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)h {
    NSMutableDictionary *m = [h mutableCopy] ?: [NSMutableDictionary new];
    m[@"X-Client-OS-Version"]  = kFakeOS;
    m[@"X-Client-OS-Build"]    = kFakeBuild;
    m[@"X-Client-Device"]      = kFakeModel;
    m[@"X-Client-Kernel"]      = kFakeKern;
    m[@"User-Agent"]           = [NSString stringWithFormat:@"Claude/99.0.0 iOS/%@ (%@)", kFakeOS, kFakeBuild];
    %orig(m);
}
%end

// =========================================================
// 9. ỔN ĐỊNH CHAT — không văng khi stream lỗi
// =========================================================
%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)err {
    id r = %orig;
    if (!r && err && *err) {
        if (err) *err = nil;
        return @{};
    }
    return r;
}
%end

%hook NSObject
- (id)valueForKey:(NSString *)key {
    @try { return %orig; }
    @catch (NSException *e) {
        return nil;
    }
}
%end

static void (*orig_NSExceptionRaise)(id, SEL, NSException *);
static void my_NSExceptionRaise(id self, SEL _cmd, NSException *e) {
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"Claude"] || [cls containsString:@"Anthropic"] ||
        [cls containsString:@"SK"] || [cls containsString:@"Store"]) return;
    orig_NSExceptionRaise(self, _cmd, e);
}

// =========================================================
// 10. Ctor — gắn tất cả hook cứng
// =========================================================
%ctor {
    MSHookFunction((void *)uname, (void *)my_uname, (void **)&orig_uname);
    MSHookFunction((void *)sysctl, (void *)my_sysctl, (void **)&orig_sysctl);

    void *mg = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (mg) {
        orig_MGCopyAnswer = (MGCopyAnswer_t)dlsym(mg, "MGCopyAnswer");
        if (orig_MGCopyAnswer)
            MSHookFunction((void *)orig_MGCopyAnswer, (void *)my_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    }

    MSHookMessageEx(objc_getClass("NSException"),
                    @selector(raise),
                    (IMP)my_NSExceptionRaise,
                    (IMP *)&orig_NSExceptionRaise);

#if 0
    NSLog(@"[ClaudeGuard v3] loaded. fake iOS %@ build %@", kFakeOS, kFakeBuild);
#endif
}
