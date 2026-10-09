// language: Logos/ObjC++, file: Tweak.xm, target: com.anthropic.claude
// Bản V28 Advanced - Fix Build Error & Chống Văng App (Crash)

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Hàm kiểm tra Bundle ID
static BOOL isClaude(NSString *bid) {
    if (!bid) return NO;
    return [bid hasPrefix:@"com.anthropic.claude"];
}

// Hàm nhận diện chữ trong Popup ép cập nhật
static BOOL isUpdateText(NSString *s) {
    if (!s || s.length == 0) return NO;
    NSString *l = [s lowercaseString];
    NSArray *keys = @[@"update", @"cập nhật", @"required", @"latest version",
                      @"out of date", @"no longer supported", @"upgrade",
                      @"please update", @"new version", @"bản mới"];
    for (NSString *k in keys) {
        if ([l containsString:k]) return YES;
    }
    return NO;
}

// =======================================================
// 1. FAKE VERSION APP LÊN CAO NHẤT (Vượt qua check Local)
// =======================================================
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *orig = %orig;
    if (!orig) return orig;
    
    NSString *bid = orig[@"CFBundleIdentifier"];
    if (isClaude(bid)) {
        NSMutableDictionary *info = [orig mutableCopy];
        info[@"CFBundleShortVersionString"] = @"99.0.0";
        info[@"CFBundleVersion"] = @"999999";
        return info;
    }
    return orig;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    NSString *bid = [self bundleIdentifier];
    if (isClaude(bid)) {
        if ([key isEqualToString:@"CFBundleShortVersionString"]) return @"99.0.0";
        if ([key isEqualToString:@"CFBundleVersion"]) return @"999999";
    }
    return %orig;
}
%end

// =======================================================
// 2. TÀNG HÌNH POPUP ÉP CẬP NHẬT TRƯỚC KHI NÓ HIỆN LÊN
// =======================================================
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        
        // Nếu phát hiện nội dung là đòi Update -> Hủy lệnh hiện Popup
        if (isUpdateText(alert.title) || isUpdateText(alert.message)) {
            if (completion) completion(); // Trả về callback để app không bị kẹt luồng
            return; 
        }
    }
    %orig;
}
%end

// =======================================================
// 3. CHẶN ỨNG DỤNG TỰ ĐỘNG BẬT APP STORE
// =======================================================
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *u = [url absoluteString];
    if ([u containsString:@"itunes.apple.com"] || 
        [u containsString:@"apps.apple.com"] || 
        [u hasPrefix:@"itms-apps://"]) {
        return NO; // Khóa chết lệnh mở App Store
    }
    return %orig;
}
%end

// =======================================================
// 4. FAKE KẾT QUẢ CHECK TỪ SERVER APPLE
// =======================================================
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

// =======================================================
// 5. FAKE THÔNG TIN GỬI CHO SERVER ANTHROPIC CLAUDE
// =======================================================
%hook NSURLSessionConfiguration
- (void)setHTTPAdditionalHeaders:(NSDictionary *)h {
    // Sửa chuẩn cú pháp để Theos không báo lỗi "Invalid argument structure"
    NSMutableDictionary *m = h ? [h mutableCopy] : [NSMutableDictionary new];
    
    // Đánh lừa server rằng máy đang chạy iOS 18 và app bản mới nhất
    m[@"X-Client-OS-Version"] = @"18.0";
    m[@"X-Client-OS-Build"] = @"22A3354";
    m[@"User-Agent"] = @"Claude/99.0.0 iOS/18.0";
    
    %orig(m);
}
%end
