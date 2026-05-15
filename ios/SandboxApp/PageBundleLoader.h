//
//  PageBundleLoader.h
//  SandboxApp
//
//  iOS Bridgeless multi-bundle 동적 평가 — Android `MainActivity.loadPageBundle` 의 iOS 짝.
//
//  RN 0.83 New Architecture (Bridgeless) 에서 `RCTBridge` 가 deprecated 되고
//  `bridge.runtime` / `bridge.jsCallInvoker` 가 동작하지 않음. 대신 `RCTInstance` 의
//  `callFunctionOnBufferedRuntimeExecutor:` 가 표준 진입점 (RN 0.74+).
//
//  RCTInstance 는 `RCTHost._instance` private ivar 라서 reflection 으로 추출.
//  callstack/react-native-sandbox 의 SandboxReactNativeDelegate.mm 패턴 동일.
//
//  사용 흐름:
//    AppDelegate.ReactNativeDelegate.hostDidStart:  →  [PageBundleLoader captureRCTInstanceFromHost:host]
//    URI 진입 (RNContainerViewController)            →  [PageBundleLoader evaluatePageBundleAtURL:url completion:^...]
//

#import <Foundation/Foundation.h>
#import <RCTDefaultReactNativeFactoryDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@class RCTHost;

/// `RCTDefaultReactNativeFactoryDelegate` subclass — `hostDidStart:` 를 가로채
/// `PageBundleLoader` 의 RCTInstance 캐치 routine 으로 전달한다.
///
/// Swift 측에서 RCTHost 타입을 직접 만지면 RCTHost.h 가 C++ STL 을 끌어와
/// bridging header 가 못 받기 때문에, override 를 Obj-C++ 레이어에 둔다.
/// Swift 는 이 클래스의 인스턴스를 만들고 dependencyProvider 만 set 하면 됨.
@interface SandboxReactNativeDelegate : RCTDefaultReactNativeFactoryDelegate
@end

@interface PageBundleLoader : NSObject

/// `SandboxReactNativeDelegate.hostDidStart:` 가 내부에서 호출.
/// 외부에서는 보통 직접 부를 일 없음.
+ (void)captureRCTInstanceFromHost:(RCTHost *)host
    NS_SWIFT_NAME(captureRCTInstance(from:));

/// 로컬 .app 번들 안의 page bundle 을 살아있는 RN runtime 에 평가.
///
/// - parameter sourceURL: file:// URL.
///   예) Bundle.main.url(forResource:"HelloRN.bundle", withExtension:"js", subdirectory:"pages")
/// - parameter completion: 평가 완료(또는 실패) 시 main thread 로 호출.
+ (void)evaluatePageBundleAtURL:(NSURL *)sourceURL
                     completion:(void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(evaluatePageBundle(at:completion:));

@end

NS_ASSUME_NONNULL_END
