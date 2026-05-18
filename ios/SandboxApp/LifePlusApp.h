//
//  LifePlusApp.h
//  SandboxApp
//
//  native-bridge `@lifeplus/native-bridge/native` SDK 가 호출하는
//  NativeModules.LifePlusApp 의 iOS 구현. RN 0.83 Bridgeless 호환.
//
//  지원 커맨드 (sandbox 측 first cut):
//    - back()                : RNContainerViewController pop. params 없음.
//    - share({ url, text? }) : UIActivityViewController. params 있음.
//
//  스키마는 native-bridge 의 schema/commands/{back,share}.schema.json 참조.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface LifePlusApp : NSObject <RCTBridgeModule>
@end

NS_ASSUME_NONNULL_END
