//
//  PageBundleLoader.mm
//  SandboxApp
//
//  RCTInstance.callFunctionOnBufferedRuntimeExecutor 기반 second-bundle evaluate.
//  callstack/react-native-sandbox SandboxReactNativeDelegate.mm 패턴.
//

#import "PageBundleLoader.h"

#import <ReactCommon/RCTHost.h>
#import <ReactCommon/RCTInstance.h>
#import <jsi/jsi.h>

#import <objc/runtime.h>
#import <memory>
#import <string>

using namespace facebook;

// static RCTInstance ref. hostDidStart 에서 set, evaluatePageBundle 에서 사용.
// reload 시 새 host 가 들어오면 갱신.
static RCTInstance *gRctInstance = nil;

#pragma mark - SandboxReactNativeDelegate

@implementation SandboxReactNativeDelegate

- (void)hostDidStart:(RCTHost *)host
{
  [PageBundleLoader captureRCTInstanceFromHost:host];
}

@end

#pragma mark - PageBundleLoader

@implementation PageBundleLoader

+ (void)captureRCTInstanceFromHost:(RCTHost *)host
{
  if (host == nil) {
    gRctInstance = nil;
    NSLog(@"[PageBundleLoader] host is nil, cleared instance");
    return;
  }

  // RCTHost._instance 는 private ivar. reflection 으로 추출.
  // RN 0.83 의 RCTHostImpl 이 `_instance: RCTInstance *` 를 들고 있음.
  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  if (ivar == NULL) {
    NSLog(@"[PageBundleLoader] ❌ RCTHost has no _instance ivar (RN API changed?)");
    gRctInstance = nil;
    return;
  }
  gRctInstance = object_getIvar(host, ivar);
  NSLog(@"[PageBundleLoader] captured RCTInstance: %p", gRctInstance);
}

+ (void)evaluatePageBundleAtURL:(NSURL *)sourceURL
                     completion:(void (^)(NSError *_Nullable))completion
{
  // RCTInstance 가 아직 캐치 안 됐으면 shared.bundle 부팅 대기. 16ms 단위 polling 최대 5초.
  // prewarm 이 정상이면 보통 첫 polling 안에 잡힘.
  [self waitForRCTInstanceWithTimeout:5.0 completion:^(RCTInstance *_Nullable instance) {
    if (instance == nil) {
      if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion([NSError errorWithDomain:@"PageBundleLoader"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"RCTInstance not captured within timeout (shared.bundle boot failed?)"}]);
        });
      }
      return;
    }
    // file:// 은 동기 read, http(s):// 는 URLSession 비동기 fetch.
    // 둘 다 NSData 로 정규화한 뒤 동일 evaluate 경로로 합류.
    [self fetchBundleAtURL:sourceURL completion:^(NSData *_Nullable data, NSError *_Nullable fetchError) {
      if (data == nil) {
        if (completion) {
          dispatch_async(dispatch_get_main_queue(), ^{
            completion(fetchError ?: [NSError errorWithDomain:@"PageBundleLoader"
                                                         code:-2
                                                     userInfo:@{NSLocalizedDescriptionKey: @"failed to fetch bundle"}]);
          });
        }
        return;
      }
      [self evaluateBundleData:data sourceURL:sourceURL instance:instance completion:completion];
    }];
  }];
}

+ (void)fetchBundleAtURL:(NSURL *)sourceURL
              completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion
{
  NSString *scheme = sourceURL.scheme.lowercaseString;
  if ([scheme isEqualToString:@"file"] || scheme.length == 0) {
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:&readError];
    NSLog(@"[PageBundleLoader] loaded local bundle: %@ (%lu bytes)", sourceURL.absoluteString, (unsigned long)data.length);
    completion(data, readError);
    return;
  }

  // http(s) — URLSession 비동기 fetch. 검증 단계라 캐시/sha256/재시도 없음.
  NSLog(@"[PageBundleLoader] fetching from CDN: %@", sourceURL.absoluteString);
  // shared 세션을 쓰면 ARC 가 fetch 중인 NSURLSession 을 해제할 일이 없어 안전.
  // ephemeralSessionConfiguration 로 cache 무시 + 매 진입 fresh fetch.
  static NSURLSession *sCDNSession = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 10.0;
    config.requestCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    sCDNSession = [NSURLSession sessionWithConfiguration:config];
  });
  NSURLSessionDataTask *task = [sCDNSession dataTaskWithURL:sourceURL
                                          completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
    if (error != nil) {
      NSLog(@"[PageBundleLoader] ❌ CDN fetch failed: %@", error.localizedDescription);
      completion(nil, error);
      return;
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
      if (status < 200 || status >= 300) {
        NSLog(@"[PageBundleLoader] ❌ CDN fetch non-2xx: %ld %@", (long)status, sourceURL.absoluteString);
        completion(nil, [NSError errorWithDomain:@"PageBundleLoader.HTTP"
                                            code:status
                                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld for %@", (long)status, sourceURL.absoluteString]}]);
        return;
      }
    }
    NSLog(@"[PageBundleLoader] ✅ fetched from CDN: %@ (%lu bytes)", sourceURL.absoluteString, (unsigned long)data.length);
    completion(data, nil);
  }];
  [task resume];
}

+ (void)waitForRCTInstanceWithTimeout:(NSTimeInterval)timeout
                           completion:(void (^)(RCTInstance *_Nullable))completion
{
  if (gRctInstance != nil) {
    completion(gRctInstance);
    return;
  }
  NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + timeout;
  dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
  dispatch_async(queue, ^{
    while (gRctInstance == nil && [NSDate timeIntervalSinceReferenceDate] < deadline) {
      [NSThread sleepForTimeInterval:0.016];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(gRctInstance);
    });
  });
}

+ (void)evaluateBundleData:(NSData *)data
                 sourceURL:(NSURL *)sourceURL
                  instance:(RCTInstance *)instance
                completion:(void (^)(NSError *_Nullable))completion
{
  // fetchBundleAtURL: 가 file:// / http(s):// 둘 다 정규화한 결과를 받음.
  std::string source(static_cast<const char *>(data.bytes), data.length);
  std::string sourceUrl = [[sourceURL absoluteString] UTF8String];

  // 2) RCTInstance 의 BufferedRuntimeExecutor 로 JS thread hop.
  //    이게 RN 0.74+ Bridgeless 에서 jsi::Runtime& 받는 표준 경로.
  //    callstack/react-native-sandbox 패턴 그대로.
  [instance callFunctionOnBufferedRuntimeExecutor:[source = std::move(source),
                                                    sourceUrl = std::move(sourceUrl),
                                                    completion](jsi::Runtime &runtime) mutable {
    NSError *evalError = nil;
    try {
      // runtime 유효성 가벼운 확인.
      runtime.global();

      runtime.evaluateJavaScript(
          std::make_unique<jsi::StringBuffer>(std::move(source)),
          sourceUrl);
    } catch (const jsi::JSError &e) {
      evalError = [NSError errorWithDomain:@"PageBundleLoader.JSError"
                                      code:-4
                                  userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
    } catch (const std::exception &e) {
      evalError = [NSError errorWithDomain:@"PageBundleLoader.std"
                                      code:-5
                                  userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
    } catch (...) {
      evalError = [NSError errorWithDomain:@"PageBundleLoader"
                                      code:-6
                                  userInfo:@{NSLocalizedDescriptionKey: @"unknown C++ exception during evaluateJavaScript"}];
    }

    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(evalError);
      });
    }
  }];
}

@end
