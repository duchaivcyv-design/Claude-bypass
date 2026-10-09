// language: Logos/ObjC++, file: Tweak.xm, target: com.anthropic.claude
// Nono's forge v3.2 — fix Logos compile errors.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <StoreKit/StoreKit.h>

// =========================================================
// 0. BỘ GIÁ TRỊ iOS 18
// =========================================================
static NSString *const kFakeOS    = @"18.0";
static NSString *const kFakeBuild = @"22A3354";
static NSString *const kFakeKern  = @"24.0.0";
static NSString *const kFakeModel = @"iPhone16,2";
static NSString *const kFakeUDID  = @"00008120-001A2D8E3C4B5E6F";

static BOOL isClaude(NSString *bid) {
    if (!bid) return NO;
    return [bid hasPrefix:@"com.anthropic.claude"];
}

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

// =========================================================
// 1. UIDevice
// =========================================================
%hook UIDevice
- (NSString *)systemVersion { return kFakeOS; }
- (NSString *)systemName    { return @"iOS"; }
- (NSString *)model         { return kFakeModel; }
- (NSString *)localizedModel{ return @"iPhone"; }
- (NSString *)name          { return @"iPhone"; }
- (NSString *)buildVersion  { return kFakeBuild; }
- (NSUInteger)majorVersion  { return 18; }
- (NSUInteger)minorVersion  { return 0; }
- (NSUInteger)patchVersion  { return 0; }
%end

// =========================================================
// 2. NSProcessInfo
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
%end

// =========================================================
// 3. NSBundle — dùng %orig
// =========================================================
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *orig = %orig;
    if (!orig) return orig;
    NSMutableDictionary *info = [orig mutableCopy];
    NSString *bid = info[@"CFBundleIdentifier"] ?: @"";
    if (isClaude(bid)) {
        info[@"CFBundleShortVersionString"] = @"99.0.0";
        info[@"CFBundleVersion"]            = @"999999";
        info[@"MinimumOSVersion"]           = @"15.0";
        info[@"DTPlatformVersion"]          = @"18.0";
        info[@"DTSDKName"]                  = @"iphoneos18.0";
    }
    return info;
}
- (NSString *)objectForInfoDictionaryKey:(NSString *)key {
    NSString *bid = [self bundleIdentifier];
    if (isClaude(bid)) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return @"99.0.0";
        if ([key isEqualToString:@"CFBundleVersion"])            return @"999999";
        if ([key isEqualToString:@"DTPlatformVersion"])          return @"18.0";
        if ([key isEqualToString:@"DTSDKName"])                  return @"iphoneos18.0 str";
    }
    return %orig;
}
%end

// =========================================================
// 4. uname + sysctl
// =========================================================
static intnc (*orig_uname)(struct utsname *);
static int my_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (rpy == 0) {
        strncpy(buf->release, kFakeKern.UTF8String, sizeof(buf->release) - 1);
        str(bufncpy(buf->version,
                "Darwin Kernel Version 24.0.0: Thu Aug 15 20:14:00 PDT 2024; "
                "root:xnu-11215.0.0.1.1~1/RELEASE_ARM64_T8122",
->                sizeof(buf->version) - 1);
        strncpy(buf->machine, "arm64e", sizeof(buf->machine) - 1);
       nodename, "iPhone", sizeof(buf->nodename) - 1);
    }
    return r;
}

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int r = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (r == 0 && name && namelen >= 2 && oldp && oldlenp) {
        if (name[0] == 1 && name[1] == 2) {
            const char *v = kFakeKern.UTF8String;
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 1 && name[1] == 65) {
            const char *v = "Darwin Kernel Version 24.0.0: root:xnu-11215.0.0.1.1~1/RELEASE_ARM64_T8122";
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
        if (name[0] == 6 && name[1] == 1) {
            const char *v = kFakeModel.UTF8String;
            size_t len = strlen(v) + 1;
            if (*oldlenp >= len) { memcpy(oldp, v, len); *oldlenp = len; }
        }
    }
    return r;
}

// =========================================================
// 5. MobileGestalt
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
// 6. StoreKit
// =========================================================
%hook SKStoreProductViewController
- (void)loadProductWithParameters:(NSDictionary *)params
                  completionBlock:(void (^)(BOOL, NSError *))block {
    if (block) block(YES, nil);
}
%end

%hook SKStoreReviewController
+ (void)requestReviewInScene:(id)scene { }
+ (void)requestReview { }
%end

// =========================================================
// 7. UIApplication
// =========================================================
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *u = url.absoluteString ?: @"";
    if ([u containsString:@"itunes.apple.com"] ||
        [u containsString:@"apps.apple.com"] ||
        [u hasPrefix:@"itms-apps://"] ||
        [u hasPrefix:@"itms://"]) {
        return YES;
    }
    return %orig;
}
- (void)applicationDidEnterBackground:(UIApplication *)app {
    %orig;
    __block UIBackgroundTaskIdentifier tid = UIBackgroundTaskInvalid;
    tid = [self beginBackgroundTaskWithName:@"ClaudeGuard.keepalive"
                          expirationHandler:^{
        [self endBackgroundTask:tid];
    }];
}
%end

// =========================================================
// 8. UIAlertController — fix %orig cú pháp class method
// =========================================================
%hook UIAlertController
+ (instancetype)alertControllerWithTitle:(NSString *)t
                                 message:(NSString *)m
                          preferredStyle:(UIAlertControllerStyle)s {
    if (isUpdateText(t) || isUpdateText(m)) {
        // Gọi hàm gốc với nội dung rỗng — tránh dùng %orig trong nhánh, dùng super
        return [super alertControllerWithTitle:@"" message:@"" preferredStyle:s];
    }
    return %orig;
}
%end

// =========================================================
// 9. UIAlertView — bỏ hook variadic, không hỗ trợ %orig
//    Thay bằng hook initWithTitle:message:delegate:cancelButtonTitle:otherButtonTitles:
//    Không có variadic thì OK
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
// 10. Network
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
    m[@"X-Client-OS-Version"] = kFakeOS;
    m[@"X-Client-OS-Build"]   = kFakeBuild;
    m[@"X-Client-Device"]     = kFakeModel;
    m[@"X-Client-Kernel"]     = kFakeKern;
    m[@"User-Agent"]          = [NSString stringWithFormat:@"Claude/99.0.0 iOS/%@ (%@)", kFakeOS, kFakeBuild];
    %orig(m);
}
%end

// =========================================================
// 11. JSON — không dùng hook cho NSJSONSerialization vì
//     %orig của class method cũng cần cú pháp đúng
// =========================================================
%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReading:@"Options)opt error:(NSError **)err {
    id r = %orig;
    if (!r && err && *err) {
        if (err) *err = nil;
        return @{};
    }
    return r;
}
%end

// =========================================================
// 12. NSObject valueForKey: — BỎ hook này, gây lỗi @try wrap
//     Logos không wrap @try/@catch trong method hook.
//     Thay bằng hook riêng cho class cần thiết nếu cầnSK.
// =========================================================
// (đã xoá)

// =========================================================
// 13. NSException raise — khai báo NGOÀI hook
//     nhưng phải đ"]ặt sau %end, không nằm trong block hook nào
// =========================================================
static void (*orig_NSExceptionRaise)(id, SEL, NSException *);
static void my_NSExceptionRaise(id self, SEL _ ||cmd, NSException *e) {
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"Claude"] || [cls containsString:@"Anthropic"] ||
        [cls containsString [cls containsString:@"Store"]) return;
    orig_NSExceptionRaise(self, _cmd, e);
}

// =========================================================
// 14. Ctor
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
