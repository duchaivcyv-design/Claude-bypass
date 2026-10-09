// language: Logos/ObjC++, file: Tweak.xm, target: com.anthropic.claude
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ==========================================
// 1. CHẶN KẾT NỐI API CHECK VERSION CỦA APPLE
// (Đánh lừa app rằng trên App Store chỉ có bản 1.0.0)
// ==========================================
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))cb {
    NSString *urlStr = [url absoluteString];
    if ([urlStr containsString:@"itunes.apple.com"] && [urlStr containsString:@"lookup"]) {
        // Fake JSON trả về từ Apple Server
        NSString *fakeJSON = @"{\"resultCount\":1,\"results\":[{\"version\":\"1.0.0\"}]}";
        NSData *data = [fakeJSON dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
        if (cb) cb(data, response, nil);
        return nil;
    }
    return %orig;
}
%end

// ==========================================
// 2. FAKE VERSION LÊN MAX (999.99.99) BÊN TRONG APP
// ==========================================
%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"CFBundleShortVersionString"] || [key isEqualToString:@"CFBundleVersion"]) {
        return @"999.99.99";
    }
    return %orig;
}

- (NSDictionary *)infoDictionary {
    // Tách riêng %orig ra một biến để Theos không bị lỗi cú pháp
    NSDictionary *origDict = %orig;
    if (!origDict) return origDict;
    
    NSMutableDictionary *info = [origDict mutableCopy];
    info[@"CFBundleShortVersionString"] = @"999.99.99";
    info[@"CFBundleVersion"] = @"999.99.99";
    
    return info;
}
%end

// ==========================================
// 3. TIÊU DIỆT MỌI ALERT POPUP ĐÒI CẬP NHẬT Ở TẦNG UI
// ==========================================
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        NSString *title = [[alert title] lowercaseString] ?: @"";
        NSString *msg = [[alert message] lowercaseString] ?: @"";
        
        // Nhận diện từ khóa cập nhật/update
        if ([title containsString:@"update"] || [msg containsString:@"update"] ||
            [title containsString:@"cập nhật"] || [msg containsString:@"cập nhật"] ||
            [title containsString:@"version"] || [msg containsString:@"version"] ||
            [title containsString:@"upgrade"] || [msg containsString:@"upgrade"]) {
            
            // Drop (hủy) ngay lệnh hiển thị popup
            if (completion) completion();
            return; 
        }
    }
    %orig;
}
%end

// ==========================================
// 4. KHÓA HÀM NHẢY SANG APP STORE
// ==========================================
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
    NSString *urlStr = [url absoluteString];
    if ([urlStr containsString:@"itunes.apple.com"] || 
        [urlStr containsString:@"apps.apple.com"] || 
        [urlStr hasPrefix:@"itms-apps://"]) {
        return NO; // Cấm hệ thống mở App Store
    }
    return %orig;
}
%end
