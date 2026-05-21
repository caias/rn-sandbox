# Decisions — sandbox-poc

> 결정 카드. 각 항목은 본작업 시작 전 한 번 통과시켜 두는 게 목적이고, 후속 단계에서 재확인하며 갱신한다.
>
> 시간순으로 추가, 회고는 보존.

---

## 결정 (MVP 시작 시점, 2026-05-11)

| # | 항목 | 결정 | 근거 / 비고 |
|---|---|---|---|
| D-1 | RN 버전 | **0.83.2** (2026-05-11 업그레이드) | life 모노레포(admin/web)의 React 19 통일에 맞춰 React 19.2.1 사용. 0.83 시리즈가 19.2.x peer (`^19.2.0`)를 정확히 충족. Toss Granite 카탈로그(RN 0.84 + React 19.2.3)와도 1 minor 차이로 정렬 |
| D-1a | React 버전 | **19.2.1** | life 모노레포 통일 버전. RN 0.83 peer `^19.2.0` 만족. 향후 모노레포가 19.2.x 어디로 가도 함께 움직임 |
| D-1b | Architecture | **New Architecture (Bridgeless) only** | RN 0.82+는 Old Architecture 제거. `ReactHost` + `ReactSurface` 단일 모델 |
| D-2 | Hermes | **ON** | RN 0.71+ 기본값. RN 0.83 + Android compileSdk 36 / minSdk 24 환경에서 검증됨 |
| D-3 | URI 스킴 | **`lifeplus-tribes`** (2026-05-13 갱신) | life 모노레포 공식 `AppScheme`(`packages/utils/common.ts`, `packages/core/src/utils/landingUrl.ts`)과 통일. 본앱과 같은 디바이스에서는 Android disambiguator 가 뜰 수 있음 (sandbox-poc 는 본앱의 host shell 로 흡수되는 경로). 이전 MVP 단계 결정은 `lifeplus-sandbox` 였음 |
| D-4 | iOS Deployment Target | **iOS 15.0** | RN 0.74 안전선. 본 레포(`LifePlusTribesApp`) Tuist 추출값과 비교 필요 |
| D-5 | Android minSdk | **24** | RN 0.74 권장. 본 레포 28과 다르지만 sandbox-poc는 보수적 최소값 |
| D-6 | iOS UI 프레임워크 | **UIKit + Storyboard** | 본 레포는 SwiftUI + UIKit lifecycle. MVP는 UIKit 단독이 가장 빠름 |
| D-7 | Android UI 프레임워크 | **View System** | 본 레포는 Compose. MVP는 View System으로 단순화. `AndroidView` 래핑 부담 회피 |
| D-8 | iOS 의존성 관리 | **CocoaPods** | 본 레포는 Tuist + SPM. MVP는 RN 공식 가이드 그대로 따라가는 CocoaPods가 가장 짧은 경로 |
| D-9 | Android 모듈 구조 | **단일 모듈** | 본 레포는 `:app / :presentation / :domain / :data` 4모듈. MVP는 분리할 가치 없음 |
| D-10 | Bundle ID / Package | iOS `com.lifeplus.sandbox`, Android `com.lifeplus.sandbox` | sandbox 전용. 본 레포와 분리 |
| D-11 | RN Module Name | **`HelloRN`** (MVP 진입점). multi-bundle 진입 후로는 미니앱 별 moduleName | MVP 시점엔 RN CLI init 기본값 그대로. 이후 [apps/native/scripts/build-page.ts](https://github.com/lp-mktplatform/life/blob/main/apps/native/scripts/build-page.ts) 의 `pageToModuleName()` 이 `src/pages/index.tsx → HelloRN` 매핑 예외만 유지하고 나머지는 파일 경로 그대로 사용. 정식 미니앱 작명 컨벤션 정착 시 `HelloRN` 예외도 제거 가능 |
| D-12 | 동작 모드 | **정적 multi-bundle (정식) / Mono 회귀 (선택) / Metro (개발)** 3모드 | 2026-05-13 갱신. MVP 시점엔 정적 단일 번들만 (`assets://main.jsbundle`). 이후 Metro fetch (Phase 1-2) + multi-bundle (Phase 1-3) 으로 진화. `SandboxApplication.useMetro` 가 `metroIp` SharedPreferences 의 비어있지 않음 여부로 분기 |
| D-13 | InitialProps | **시스템 키 (`initialPath` / `platform` / `appVersion`) + URI query 평탄화** | 2026-05-13 갱신. MVP 시점엔 임시 검증용 `a` (`"data-from-sandbox"`) / `b` (`42`, putInt). 이후 모든 query 키 putString 평탄화로 진화. RESERVED_KEYS 가드로 시스템 키 충돌 보호 |

---

## Multi-bundle 진입 단계 결정 (2026-05-13)

| # | 항목 | 결정 | 근거 / 비고 |
|---|---|---|---|
| D-14 | Multi-bundle 진입점 | `ReactHostImpl.loadBundle$ReactAndroid_debug` (reflection) | RN 0.83 Bridgeless 가 multi-bundle 평가를 위한 public API 를 안 노출. `ReactHost` interface 는 단일 번들 reload (`setBundleSource`) 만 가짐. 실제 진입점인 `ReactHostImpl.loadBundle(JSBundleLoader): Task<Boolean>` 가 `internal` 가시성. JVM mangled name `loadBundle$ReactAndroid_debug` 를 `declaredMethods.firstOrNull { startsWith("loadBundle") }` prefix match 로 빌드 variant 무관하게 호출. RN 0.84+ 에서 표준 API 가 나오면 reflection 제거 |
| D-15 | ReactInstance ready 대기 | `addReactInstanceEventListener` + `currentReactContext` 가드 | `loadBundle` 은 ReactInstance 가 살아있을 때만 동작. instance 미준비 시 `raiseSoftException(callWithExistingReactInstance(loadBundle())): reactInstance is null. Dropping work.` 로 silent drop. 첫 진입 (cold) 은 listener 로 대기, 두번째부터 (warm) 는 `currentReactContext != null` 가드로 즉시 호출 |
| D-16 | Task 완료 감지 | Bolts `Task` 의 polling (16ms 단위) | RN 의 `Task` 클래스는 `internal.bolts.Task` 패키지에 있고 `continueWith(Continuation)` 호출 시그니처가 까다로움. listener API 도 없음. `isCompleted` / `isFaulted` / `getResult` / `getError` 가 public 이라 16ms (1 frame) 단위 polling 으로 단순화. page bundle 은 ~5KB 라 수십 ms 안에 끝남 |
| D-17 | Shared 번들 metro-wrap, Page 번들 raw | shared 만 `wrapAsMetroModule` 로 lazy 평가, page 는 esbuild IIFE 그대로 | Hermes top-level parser 가 esbuild 의 평탄화된 IIFE 의 `class extends X` 같은 패턴을 거부 (`Invalid expression encountered`). metro `__d` factory 로 감싸면 평가 시점이 함수 body 안으로 미뤄져 우회. shared 는 큰 vendor 묶음이라 wrap 필수. page 는 ~5KB 단순 IIFE 라 top-level parse 이슈 안 트리거 — 동시에 shared 가 이미 metro require polyfill 을 박았기 때문에 page 까지 wrap 하면 modId 0 중복 등록 충돌. 깨지면 page 도 wrap 으로 확장 |
| D-18 | 페이지 번들 파일명 = moduleName | `apps/native` 가 `dist/pages/android/{moduleName}.bundle.js` 로 출력 | sandbox 가 URI host (=moduleName) 로 `assets/pages/{moduleName}.bundle.js` 를 그대로 lookup. 만약 파일명이 파일 경로 (`index`) 면 sandbox 에서 매핑 테이블 필요 — `apps/native` 측에서 한 줄로 통일하는 게 정답. `src/pages/index.tsx → HelloRN.bundle.js`, `src/pages/detail.tsx → detail.bundle.js` |

---

## 부채 정리 (2026-05-14)

| # | 항목 | 결정 | 근거 / 비고 |
|---|---|---|---|
| D-19 | npm 프로젝트 위치 | `package.json` + `node_modules` 를 **sandbox 루트에 직접 둔다** (HelloRN/ 폐기) | MVP 시점 `HelloRN/` 은 RN CLI init 으로 생긴 디렉토리였고, 루트의 `package.json` / `node_modules` 는 HelloRN/ 으로의 symlink 였음. multi-bundle 도입 후 HelloRN 의 RN 소스(App.tsx 등)는 모두 미사용이 됐지만, **gradle 은 여전히 node_modules 가 필요**함: `settings.gradle` 의 `includeBuild("../node_modules/@react-native/gradle-plugin")` + `app/build.gradle` 의 `apply plugin: "com.facebook.react"` 가 `node_modules/react-native/android` 의 maven repo 에서 `com.facebook.react:react-android` / `hermes-android` AAR 을 가져옴. 2026-05-14 에 HelloRN/ 디렉토리 자체를 삭제하고 package.json + node_modules 를 sandbox 루트로 승격, symlink 제거. `Gemfile` 만 iOS 작업용으로 보존하고 같이 루트로 올림. 빌드 회귀 검증 OK (assembleDebug PASS) |
| D-20 | iOS 라인 재구성 방식 | **RN 0.83.2 fresh init 후 sandbox 코드 입히기** (decisions.md MVP 회고 1번 패턴, Android 라인과 동일) | ios-wip/ 의 ObjC 잔재 (`AppDelegate.h/.mm`, `main.m`) 가 pbxproj 에 남아있는 동시에 디스크엔 사라진 상태로 빌드 불가. 0.83 iOS 템플릿이 Swift 전용(RN 0.77+, `RCTReactNativeFactory` + `@main AppDelegate`) 이라 incremental 수정보다 fresh init 한 베이스 위에 ios-wip 의 `DevToolViewController.swift` 흡수 + `RNContainerViewController` 를 0.83 API (`factory.rootViewFactory.view(withModuleName:initialProperties:)`) 로 재작성하는 게 더 짧음. pbxproj 의 Swift 파일 등록은 `xcodeproj` Ruby gem 으로 멱등 스크립트화 (`ios/add_swift_sources.rb`) |
| D-21 | iOS Bundle ID / URL scheme | `com.lifeplus.sandbox` / `lifeplus-tribes` (Info.plist `CFBundleURLTypes`) | Android `<data android:scheme="lifeplus-tribes" />` 와 통일 (D-3). disambiguator 같은 본앱 공존 이슈는 Android 와 동일 |
| D-22 | iOS multi-bundle 진입점 | **`RCTInstance.callFunctionOnBufferedRuntimeExecutor:` + `jsi::Runtime.evaluateJavaScript`** (PageBundleLoader.mm) — Android `loadBundle$ReactAndroid_debug` reflection (D-14) 의 iOS 짝 | 2026-05-15 구현 완료. 사전 조사 시점 추측 (`RCTHostDelegate.loadBundleAtURL:` override + `RCTJavaScriptLoader.loadBundleAtURL:`) 은 **틀린 경로**였음 — 그 두 진입점은 RN 이 *자기 안에서* additional bundle 을 요청할 때 dispatch 되는 inbound hook 이라 sandbox 가 *외부에서* page bundle 을 강제 평가하기엔 부적합. 실제 정답은 RN 0.74+ Bridgeless 의 표준 진입점 `RCTInstance.callFunctionOnBufferedRuntimeExecutor:^(jsi::Runtime &){ runtime.evaluateJavaScript(...); }`. callstack/react-native-sandbox 의 `SandboxReactNativeDelegate.mm` 패턴 그대로. RCTInstance 획득은 `RCTHost._instance` private ivar 를 ObjC runtime reflection (`class_getInstanceVariable(_, "_instance")`) — Android D-14 의 JVM mangled name reflection 의 iOS 짝 |

---

## iOS multi-bundle 구현 결정 (2026-05-15)

| # | 항목 | 결정 | 근거 / 비고 |
|---|---|---|---|
| D-23 | iOS RCTInstance prewarm 패턴 | `AppDelegate` 가 부팅 시 **dummy moduleName 으로 `factory.rootViewFactory.view(...)` 한 번 호출** 해서 RCTHost.start 트리거 | RN 0.83 의 `RCTReactNativeFactory.rootViewFactory.view(withModuleName:initialProperties:launchOptions:)` 가 RCTHost lifecycle 진입점. 첫 호출이 `RCTHost.start` 를 invoke 하고 그 안에서 shared.bundle 평가 + RCTInstance 생성. window 에 mount 안 해도 RN runtime 은 살아있음. 결과: URI 진입 시점에 `RCTInstance` 가 이미 준비돼 있어 `callFunctionOnBufferedRuntimeExecutor:` 즉시 호출 가능. Android `SandboxApplication.reactHost` 의 `getDefaultReactHost(...)` lazy 평가 + `MainActivity.handleIntent` 의 `addReactInstanceEventListener` 패턴의 iOS 단순화 |
| D-24 | RCTInstance reflection 의 정당성 | `RCTHost._instance` 가 internal ivar 라 reflection 필수. RN 0.84+ 공식 노출 시 제거 | `RCTHost.h` (public) 가 `_instance` 를 노출하지 않음 — public 메서드는 `start`, `callFunctionOnJSModule:method:args:`, `createSurfaceWithModuleName:initialProperties:` 만. `createSurfaceWithModuleName:` 은 *새 surface 만* 만들고 *기존 runtime 에 추가 bundle 평가* 는 못 함. 실제로 jsi::Runtime& 까지 가려면 `RCTInstance.callFunctionOnBufferedRuntimeExecutor:` 가 유일한 public-ish 경로이고, 그 RCTInstance 자체가 RCTHost ivar. callstack/react-native-sandbox 도 같은 reflection 사용. Android D-14 와 같이 RN 0.84+ public API 가 나오면 제거 |
| D-25 | ObjC++ 레이어 분리 + bridging header | **`PageBundleLoader.h/.mm` 를 ObjC++ 로 격리**, Swift 측은 `SandboxApp-Bridging-Header.h` 로 import. RCTHost.h 를 Swift bridging header 에 직접 import 금지 | `RCTHost.h` 가 C++ STL (`<string>`, `<functional>`, `<iosfwd>`, `react/runtime/JSRuntimeFactory.h`) 을 끌어와 Objective-C 모드인 Swift bridging header 가 받지 못함 (build error). PageBundleLoader.mm 는 `.mm` 이라 자기 안에서 `<ReactCommon/RCTHost.h>` + `<jsi/jsi.h>` 자유롭게 import 가능. Swift 측 `ReactNativeDelegate` 는 `SandboxReactNativeDelegate` (ObjC++) 를 base 로 상속만 받음 — `hostDidStart:` override 는 .mm 안에서 처리되고 Swift 는 RCTHost 타입을 안 만짐. 결과적으로 Swift ↔ jsi::Runtime ↔ RCTInstance 의 깊은 C++ 상호작용을 Swift 코드에서 격리 |
| D-26 | Page bundle 캐싱 | `RNContainerViewController.loadedPages: Set<String>` 으로 두번째 진입부터 evaluate skip. `AppRegistry.registerComponent` idempotent 라 evaluate 자체는 무해하지만 비용 절약 | Android 2026-05-13 회고의 TODO ("같은 appName 두 번 진입") 의 iOS 선반영. cold path 는 `pageURL` lookup + `PageBundleLoader.evaluatePageBundle` 호출, warm path 는 `loadedPages.contains(appName)` 가드로 즉시 `mountSurface` |
| D-27 | iOS page bundle 디렉토리 구조 | `ios/SandboxApp/{shared.bundle.js, pages/{moduleName}.bundle.js}` — Xcode **folder reference** 로 `.app` 안에 디렉토리째 들어감 | Android `app/src/main/assets/{shared.bundle.js, pages/{moduleName}.bundle.js}` 의 iOS 짝. `Bundle.main.url(forResource:"\(moduleName).bundle", withExtension:"js", subdirectory:"pages")` 로 lookup. group reference (Xcode 가 디렉토리 구조 무시하고 flat 하게 처리) 가 아닌 **folder reference** (파란색 아이콘) 필수 — 그래야 `.app/pages/` 디렉토리가 유지됨. `apps/native deploy:ios` 의 출력 위치도 같은 구조 |
| D-28 | Podfile post_install 워크어라운드 | (a) `SWIFT_ENABLE_EXPLICIT_MODULES = NO` (b) `fmt/include/fmt/base.h` 의 `FMT_USE_CONSTEVAL` 매크로 체인을 sed-style 패치로 강제 0 | Xcode 26 + RN 0.83 호환 이슈 2건. (a) Swift Explicit Modules 가 RN 0.83 의 일부 ObjC++ 헤더와 충돌 (참조: react-native-community/discussions-and-proposals#978). (b) Apple clang 21 (Xcode 26) 의 strict consteval 이 fmt 11.0.2 의 `FMT_STRING` 매크로의 lambda evaluation 거부 — `consteval` 호출 지점이 자체로 constant expression 이어야 함을 요구. 5개의 컴파일 에러 발생 (facebook/react-native#55601, fmtlib/fmt#4740). fmt 의 매크로 체인 (`#if !defined(...) #elif ... #else #define`) 이 외부 `-DFMT_USE_CONSTEVAL=0` 으로 못 덮어쓰는 구조라 헤더 자체 패치가 정답. CocoaPods 가 source 를 readonly 로 설치하므로 `File.chmod(0o644)` 후 write. RN 0.84+ 의 fmt 업그레이드까지 임시방편 |

---

## NavBridge (NativeModule) 도입 (2026-05-18)

| # | 항목 | 결정 | 근거 / 비고 |
|---|---|---|---|
| D-29 | NativeModule contract | **`@lifeplus/native-bridge`** (git+`lp-mktplatform/lp-mktplatform-native-bridge#feature/native-bridge`) — JSON Schema 단일 소스에서 TypeScript SDK + Swift / Kotlin 타입을 quicktype 으로 자동 생성 | sandbox 가 NativeModule 인터페이스를 손으로 정의하면 본 앱 통합 시 drift 발생. native-bridge 의 `sdk-native.ts` 가 `NativeModules.LifePlusApp[command](params)` Promise wrap 표준. `platforms: ["native"]` 인 `back` + `platforms: ["web", "native"]` 인 `share` 를 first cut. sandbox 는 ObjC++ (`LifePlusApp.h/.mm`) + Kotlin (`LifePlusAppModule.kt` + `LifePlusAppPackage.kt`) 로 구현하고 `SandboxApplication.reactHost` 의 packageList 에 `LifePlusAppPackage()` 수동 합치기. 본 앱 host shell 통합 시 같은 native-bridge 패키지로 한 줄에 alignment |
| D-30 | NativeModule arg-수 mismatch 함정 | **void 커맨드도 `params: ReadableMap?` 자리를 시그니처에 둔다.** Android: `@ReactMethod fun back(params: ReadableMap?, promise: Promise)`. iOS: `RCT_REMAP_METHOD(back, backWithParams:(NSDictionary*)params resolver:... rejecter:...)` | `native-bridge/generated/typescript/sdk-native.ts` 의 `call(command, params?)` helper 가 params 가 없어도 항상 `fn(undefined)` 1-arg 로 호출. Android TurboModule 가드가 사용자 arg 수 vs 시그니처 arg 수를 strict 비교 → `TurboModule method "back" called with 1 arguments (expected argument count: 0)` FATAL 발생 (Hermes 가 JS Error 로 던지고 ExceptionsManagerModule 가 native 예외로 승격). 시그니처에 자리만 잡아 두면 한 줄 비용으로 양쪽 다 동작. iOS 도 mismatch 시 silent 가 아니라 RN bridge layer 에서 reject 되므로 같이 맞춤 |
| D-31 | sandbox Android `back()` 마지막 pop = DevTool 노출 | `MainActivity.showRN` 이 URI 진입 시 항상 `showDevTool()` 을 root commit 으로 깔고 그 위에 RN ReactFragment 를 `addToBackStack(appName)`. native back 은 `backStackEntryCount > 0` 면 popBackStack, 비어있으면 `activity.finish()` | sandbox 단독 검증 환경 기준. 초기 구현은 마지막 fragment pop 시 `finish()` 로 launcher 복귀였으나 iOS 의 `viewControllers.count<=1` no-op (DevTool 노출) 과 비대칭이라 통일. 본 앱 host shell 통합 시점엔 DevTool 이 사라지고 본앱 navigator 가 root 가 되므로 이 분기 자체가 폐기됨 (D-33 참조) |
| D-32 | sandbox iOS `back()` root no-op | `UINavigationController.viewControllers.count <= 1` 이면 `resolve([NSNull null])` 으로 silent 종결. reject 안 함 | iOS sandbox 는 DevTool 이 nav root 이므로 root 에서 native back 호출은 사용자 실수일 뿐 에러 아님. JS 측에서 `back()` 이 어디서 호출됐는지 알 수 없으니 reject 하면 false positive 에러 다이얼로그가 뜸. 본 앱 host shell 통합 시 root 의미가 바뀜 (D-33) |
| D-33 | NavBridge 구현체는 **호스트 책임** (A안) | `@lifeplus/native-bridge` 가 스키마 + JS SDK 까지만 single source of truth, **NativeModule `LifePlusApp` 의 native 구현은 호스트마다 자기 navigator 에 맞춰 새로 작성**. sandbox 의 `LifePlusApp.mm` + `LifePlusAppModule.kt` 는 **sandbox 단독 시나리오용 reference 구현**일 뿐, 본 앱 host shell 통합 시점에 본앱이 자체 navigator 와 묶인 새 구현체로 대체 | 본 앱 navigator 가 sandbox 와 본질적으로 다름. **iOS 본앱** = UIKit `AppDelegate` + `SceneDelegate` + SwiftUI `AppRouterView` (`StatusBarStyleHostingController`). `back()` 의 의미 = SwiftUI `NavigationPath` pop 또는 `dismiss(animated:)`. **Android 본앱** = Compose 단독 + Navigation3 (`NavDisplay` + `backStack`). `back()` = `backStack.removeLast()` 또는 `_deepLinkChannel` 로 navigator 에 신호. delegate 패턴 (B안) 도 검토했지만 NativeModule 자체가 호스트당 1개라 인터페이스 한 겹 더 두는 추상화 비용이 이득 대비 큼. 결론: **JS SDK 통일 + 구현체 호스트별** 이 최소 결합. sandbox 의 D-31/D-32 비대칭 분기는 호스트별 root 가 다르다는 본질적 차이의 표면이고, 본앱 통합 시점에 자연 해소 |

---

## 추후 재확인 필요

- [x] ~~iOS Tuist `Project.swift`에서 Deployment Target 실제값 추출 → D-4 갱신~~ → **iOS 17.0** (`lp-mktplatform-ios/LifePlus/Tuist/ProjectDescriptionHelpers/Target+extensions.swift:34` 의 `.iOS("17.0")`). 2026-05-15 GitHub MCP 직접 조회
- [ ] Swift 6 strict concurrency 환경에서 RN ObjC bridge 통과 여부 → D-1, D-8 갱신
- [ ] AppsFlyer DeepLinkIngressQueue 동작과 RN 진입 순서 충돌 여부 (iOS 분석 6.1 참조)
- [ ] `singleTop` 유지 vs `singleTask` 변경 (Android 분석 6.1 참조)
- [ ] RN 0.84+ 에서 `loadBundle` public API 가 노출되면 D-14 reflection 제거
- [ ] RN 0.84+ 에서 `RCTHost._instance` 가 public 으로 노출되거나 second-bundle 평가 표준 API 가 나오면 D-22/D-24 reflection 제거
- [x] ~~본 iOS 레포 (lp-mktplatform-ios) 의 Xcode 버전 핀 (`mise.toml` / Fastlane / GitHub Actions) 확인 → sandbox 의 Xcode 26.5 표준과 align~~ → 2026-05-15 조회 결과. `mise.toml` 에 Xcode 핀 없음 (tuist 4.178 + swiftlint 0.57.1 만). `develop-ci.yml` 은 `macos-latest` 의 default Xcode + `xcodebuild -version` 메이저 ≥16 소프트 가드. **`develop-cd.yml:43`** 가 **`XC_VERSION='14.2'` + `runs-on: macos-12`** (deprecated runner) 강제 → RN 0.83 호환 불가, App Store 제출 (2026-04+ Xcode 26 의무) 불가. **본 레포 통합 P0**: CD workflow 를 `Xcode 26.5 + macos-26 runner` 로 점프 + CI workflow Xcode 핀 명시화
- [x] ~~iOS 17 simulator runtime 을 Xcode 26.5 에 추가해서 multi-version verify 매트릭스 완성~~ — 2026-05-15 완료. iOS 17.5 runtime 이 시스템 catalog 에 이미 Ready 상태 (Xcode 16.4 가 들고있던 게 본체 삭제 후에도 남음). 동일 `.app` (Xcode 26.5 + iOS 26.5 SDK, deployment target 15.1) 이 iPhone 15 Pro / iOS 17.5 에서도 동일 동작 확인
- [ ] fmt 11.0.2 → 11.1+ 또는 RN 0.84 의 fmt 업그레이드 시 D-28 (Podfile fmt 패치) 제거
- [ ] 본 iOS 레포의 RN podspec 통합 전략 — Tuist 4 가 podspec 직접 import 안 함. 후보: (a) Tuist + CocoaPods 하이브리드, (b) RN SPM wrap, (c) Tuist External Targets. 본 레포 통합의 가장 큰 unblocker
- [ ] sandbox PageBundleLoader.mm 에 Swift 6 strict concurrency 가드 추가 — `gRctInstance` static cross-thread 접근. 본 레포 통합 시 `nonisolated(unsafe)` 또는 dispatch_queue 가드 필요. sandbox 단독에선 미발현
- [ ] sandbox iOS deployment target 을 15.1 → 17.0 으로 align — 본 레포 (`.iOS("17.0")`) 와 통일. sandbox `ios/SandboxApp.xcodeproj` 의 `IPHONEOS_DEPLOYMENT_TARGET` 갱신 + Podfile platform 갱신
- [ ] RN 0.83 podspec 들이 dynamic framework (`use_frameworks! :linkage => :dynamic`) 환경에서 동작하는지 — 본 레포가 SPM dynamic 가능성. sandbox 의 fmt 패치 + Swift Explicit Modules 워크어라운드가 dynamic 모드에서도 같은 결과인지 검증 필요

---

## 본 파일의 범위

본 파일에는 **결정 카드 (D-1 ~ D-33)** 와 **"추후 재확인 필요" 체크리스트**만 유지한다. 본앱 개발자가 sandbox-poc 를 받았을 때 *결정 결과*는 위 표가 단일 출처. 결정 과정 / 막힌 지점 / 학습 등 회고 본문은 본 레포 외부 (개인 노트) 로 이전됨.
