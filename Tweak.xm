// language: Logos/ObjC++, file: Tweak.xm, target: com.anthropic.claude
// Fix by nono

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>
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
    if (!s || s.length == 0) return NO;
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

// ==========================================
// 1. FAKE THÔNG SỐ HỆ ĐIỀU HÀNH
// ==========================================

%hook UIDevice
- (NSString *)systemVersion { return kFakeOS; }
- (NSString *)model { return kFakeModel; }
- (NSString *)buildVersion { return kFakeBuild; }
%end

%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    return (NSOperatingSystemVersion){18, 0, 0};
}
- (NSString *)operatingSystemVersionString {
    return [NSString stringWithFormat:@"Version %@ (Build %@)", kFakeOS, kFakeBuild];
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)v {
    return v.majorVersion <= 18;
}
%end

// ==========================================
// 2. FAKE PHIÊN BẢN APP (Bypass info.plist check)
// ==========================================

%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *orig = %orig;
    if (!orig) return orig;
    
    NSString *bid = orig[@"CFBundleIdentifier"];
    if (isClaude(bid)) {
        NSMutableDictionary *info = [orig mutableCopy];
        info[@"CFBundleShortVersionString"] = @"99.0.0";
        info[@"CFBundleVersion"] = @"999999";
        info[@"MinimumOSVersion"] = @"15.0"; // Ép hệ thống tin app chạy được trên iOS 15
        info[@"DTPlatformVersion"] = @"18.0";
        return info;
    }
    return orig;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    NSString *bid = [self bundleIdentifier];
    if (isClaude(bid)) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return @"99.0.0";
        if ([key isEqualToString:@"CFBundleVersion"]) return @"999999";
        if ([key isEqualToString:@"MinimumOSVersion"]) return @"15.0";
    }
    return %orig;
}
%end

// ==========================================
// 3. CHẶN POPUP CẬP NHẬT VÀ NHẢY APP STORE
// ==========================================

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        // Nếu phát hiện popup đòi cập nhật -> Hủy (Drop) lệnh hiển thị luôn
        if (isUpdateText(alert.title) || isUpdateText(alert.message)) {
            if (completion) completion();
            return; 
        }
    }
    %orig;
}
%end

%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *u = [url absoluteString];
    if ([u containsString:@"itunes.apple.com"] || 
        [u containsString:@"apps.apple.com"] || 
        [u hasPrefix:@"itms-apps://"]) {
        return NO; // Chặn nhảy sang App Store
    }
    return %orig;
}
%end

// ==========================================
// 4. CHẶN CHECK PHIÊN BẢN TỪ SERVER
// ==========================================

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
    if (!h) { %orig(h); return; }
    NSMutableDictionary *m = [h mutableCopy];
    m[@"X-Client-OS-Version"] = kFakeOS;
    m[@"X-Client-OS-Build"] = kFakeBuild;
    m[@"User-Agent"] = [NSString stringWithFormat:@"Claude/99.0.0 iOS/%@", kFakeOS];
    %orig(m);
}
%end

// ==========================================
// 5. CẤP THẤP: FAKE MOBILE GESTALT & UNAME
// ==========================================

static int (*orig_uname)(struct utsname *);
static int my_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (r == 0) {
        strncpy(buf->release, [kFakeKern UTF8String], sizeof(buf->release) - 1);
        strncpy(buf->version, "Darwin Kernel Version 24.0.0", sizeof(buf->version) - 1);
    }
    return r;
}

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

%ctor {
    MSHookFunction((void *)uname, (void *)my_uname, (void **)&orig_uname);
    
    void *mg = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (mg) {
        MGCopyAnswer_t fn = (MGCopyAnswer_t)dlsym(mg, "MGCopyAnswer");
        if (fn) {
            orig_MGCopyAnswer = fn;
            MSHookFunction((void *)fn, (void *)my_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
        }
    }
}
