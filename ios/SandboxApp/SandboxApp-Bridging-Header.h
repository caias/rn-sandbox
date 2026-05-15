//
//  SandboxApp-Bridging-Header.h
//  Obj-C / Obj-C++ 헤더를 Swift 측에서 import 하기 위한 bridging header.
//

#import "PageBundleLoader.h"

// RCTHost.h 직접 import 금지 — 그 헤더가 C++ STL (<string>, <functional>, <iosfwd>) 을 끌어와
// Objective-C 모드인 Swift bridging header 가 받지 못함. PageBundleLoader 측은 .mm 라
// 자기 안에서 RCTHost.h 를 import 하고, Swift 측은 RCTHost 타입을 AnyObject 로 받는다.
