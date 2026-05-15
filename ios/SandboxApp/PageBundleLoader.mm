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
    [self evaluatePageBundleAtURL:sourceURL instance:instance completion:completion];
  }];
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

+ (void)evaluatePageBundleAtURL:(NSURL *)sourceURL
                       instance:(RCTInstance *)instance
                     completion:(void (^)(NSError *_Nullable))completion
{

  // 1) 로컬 파일 → NSData → std::string.
  NSError *readError = nil;
  NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:&readError];
  if (data == nil) {
    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(readError ?: [NSError errorWithDomain:@"PageBundleLoader"
                                                    code:-2
                                                userInfo:@{NSLocalizedDescriptionKey: @"failed to read bundle"}]);
      });
    }
    return;
  }

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
