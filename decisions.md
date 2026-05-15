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

## 추후 재확인 필요

- [ ] iOS Tuist `Project.swift`에서 Deployment Target 실제값 추출 → D-4 갱신
- [ ] Swift 6 strict concurrency 환경에서 RN ObjC bridge 통과 여부 → D-1, D-8 갱신
- [ ] AppsFlyer DeepLinkIngressQueue 동작과 RN 진입 순서 충돌 여부 (iOS 분석 6.1 참조)
- [ ] `singleTop` 유지 vs `singleTask` 변경 (Android 분석 6.1 참조)
- [ ] RN 0.84+ 에서 `loadBundle` public API 가 노출되면 D-14 reflection 제거
- [ ] RN 0.84+ 에서 `RCTHost._instance` 가 public 으로 노출되거나 second-bundle 평가 표준 API 가 나오면 D-22/D-24 reflection 제거
- [ ] 본 iOS 레포 (lp-mktplatform-ios) 의 Xcode 버전 핀 (`mise.toml` / Fastlane / GitHub Actions) 확인 → sandbox 표준 (Xcode 26.5) 과 align
- [x] ~~iOS 17 simulator runtime 을 Xcode 26.5 에 추가해서 multi-version verify 매트릭스 완성~~ — 2026-05-15 완료. iOS 17.5 runtime 이 시스템 catalog 에 이미 Ready 상태 (Xcode 16.4 가 들고있던 게 본체 삭제 후에도 남음). 동일 `.app` (Xcode 26.5 + iOS 26.5 SDK, deployment target 15.1) 이 iPhone 15 Pro / iOS 17.5 에서도 동일 동작 확인
- [ ] fmt 11.0.2 → 11.1+ 또는 RN 0.84 의 fmt 업그레이드 시 D-28 (Podfile fmt 패치) 제거

---

## 회고 (2026-05-11) — MVP

### 막힌 지점

1. **iOS pbxproj 수정의 brittleness**
   - HelloRN의 ObjC `AppDelegate.h/.mm/main.m`를 디스크에서 제거했지만 `project.pbxproj`는 여전히 그 참조를 유지 → 빌드 불가
   - 새로 작성한 Swift 3개 파일은 pbxproj에 미등록 → Xcode가 빌드 대상으로 인식 못함
   - Claude가 손으로 `project.pbxproj`(UUID/group/buildPhase 모두 정합성 필요)를 수정하는 건 매우 위험해 `ios-wip/`로 격리하고 본작업 보류 결정
   - **교훈**: 다음 시도 시 (a) Xcode GUI에서 새 Swift 프로젝트 생성 후 RN integration, 또는 (b) `xcodeproj` Ruby gem 스크립트 사전 작성

2. **node_modules 경로**
   - `app/build.gradle`의 `../../node_modules/...` 참조가 sandbox 루트의 node_modules를 기대
   - HelloRN/node_modules → sandbox/node_modules로 심볼릭 링크해서 해결
   - **교훈**: HelloRN/을 어디 둘지 처음부터 정해야 함. `.gitignore`에는 HelloRN/ 째로 제외했지만 symlink는 트래킹됨

3. **`androidx.appcompat` / `fragment-ktx` 누락**
   - RN 0.74 템플릿의 app/build.gradle에는 React 의존성만 있고 AppCompat이 없음
   - `AppCompatActivity` + `commit { }` 확장 함수 쓰려면 명시적 추가 필요

### 결정 갱신

- **D-1 (RN 버전)**: MVP 시점 0.74.5 → 0.83.2 업그레이드 (자세한 건 아래 RN 0.83 회고)
- **D-2 (Hermes)**: ON 확정. gradle.properties `hermesEnabled=true` 기본값으로 빌드 통과
- **D-7 (Android UI)**: View System + `FrameLayout` 컨테이너 + AppCompatActivity → 의도대로 동작
- **D-12 (Metro 미사용)**: MVP 시점 `getJSBundleFile() = "assets://main.jsbundle"` + `getUseDeveloperSupport = false`로 확정. APK에 정적 번들 포함 확인. 이후 Phase 1-2 에서 Metro 모드 추가

### RN 0.83 업그레이드 회고

1. **incremental upgrade(0.74→0.78→0.80→...)를 시도하지 않고 fresh init이 정답이었다**
   - 0.74 → 0.83 점프는 ReactNativeHost 제거 / autolinking 변경 / SoLoader 변경 / Hermes 통합 변경 등 깨지는 곳이 너무 많음
   - HelloRN을 RN CLI로 새로 init한 후 sandbox 코드를 그 위에 다시 입히는 패턴이 가장 안전

2. **자체 Fragment + ReactSurfaceView 구현은 함정**
   - 처음 RN 0.83에서 `host.createSurface().start()` → `surface.view`를 Fragment에 add했을 때 화면이 흰 채로 안 그려졌음. ReactHost lifecycle (`onHostResume/Pause/Destroy`) 연결 누락으로 Fabric renderer가 surface 측정/렌더링을 시작 안 함
   - **정답은 RN 공식 `com.facebook.react.ReactFragment` 사용.** `ReactFragment.Builder().setComponentName(...).setLaunchOptions(...).setFabricEnabled(true).build()` 한 줄로 ReactSurface 생성/attach/lifecycle 모두 RN이 처리
   - 단 호스트 Activity가 **`DefaultHardwareBackBtnHandler`를 구현해야 함** — onResume에서 ClassCastException 발생
   - 이 결정의 부산물로 자체 `RNContainerFragment.kt` 가 deprecated. 2026-05-14 부채정리에서 디스크에서도 제거

3. **Toss Granite로부터 흡수한 것 (Granite 자체는 도입하지 않음)**
   - RN 0.84 + React 19.2.3 catalog (우리의 RN 0.83.2 + React 19.2.1 결정의 reality-check)
   - brownfield 시나리오는 RN 공식 `ReactFragment`만 잘 쓰면 충분 — 별도 helper 불필요
   - micro-frontend 사상(`globalThis.__SHARED__` + virtual alias) 은 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) 에서 자체 esbuild plugin 으로 구현
   - 참고: [callstack/react-native-brownfield](https://github.com/callstack/react-native-brownfield)도 RN 0.76+ Fast Refresh 호환 helper. 필요해지면 도입 검토

### InitialProps 임시 세 키

apps/native 측이 InitialProps 라인을 살아있게 받는지만 검증하기 위해
`appVersion` / `a` / `b` 만 우선 박았다. **(2026-05-13 종결)** D-13 갱신으로
임시 키 제거 + URI query 평탄화 정식 도입.

---

## 회고 (2026-05-13) — Multi-bundle host shell

### 발견한 문제 4건과 해결

1. **`reactInstance is null. Dropping work.`**
   - 첫 진입 시 `loadBundle` 을 즉시 호출하면 ReactInstance 가 아직 생성 안 됨 → silent drop
   - RN 의 `ReactHostImpl.callWithExistingReactInstance` 가 이름 그대로 *existing* instance 가 있을 때만 실행
   - 해결: `addReactInstanceEventListener` 로 init 콜백 받기 + `currentReactContext != null` 가드로 warm path 분기 (D-15)

2. **`NoSuchMethodException: ReactHostImpl.loadBundle [class JSBundleLoader]`**
   - `getDeclaredMethod("loadBundle", JSBundleLoader.class)` 가 실패
   - 원인: Kotlin `internal fun loadBundle` 의 JVM bytecode 노출 이름이 `loadBundle$ReactAndroid_debug` (debug build) 로 mangling
   - 해결: `declaredMethods.firstOrNull { it.name.startsWith("loadBundle") }` prefix match (D-14)

3. **`Unable to load script: pages/HelloRN.bundle.js`**
   - `apps/native` 의 page bundle 출력 파일명이 파일 경로(`index.bundle.js`) 였는데 sandbox 는 moduleName(`HelloRN`) 으로 lookup
   - moduleName ↔ 파일명 매핑 테이블을 sandbox 에 두는 vs 출력 파일명을 통일하는 vs 양쪽 다 — 후자가 정답
   - 해결: `apps/native/scripts/build-page.ts` 의 `pageToOutPath` 가 `moduleName` 기반 (D-18)

4. **Process attach timeout (zygote cold start)**
   - 첫 진입 시 ANR 비슷한 증상. logcat 에 `Killing 16549:com.lifeplus.sandbox (adj 0): start timeout`
   - 실제로는 zygote 가 RN 앱 dex 로딩 + GC init 에 ~8s 걸린 게 process attach 10s timeout 직전까지 잡아먹은 것
   - 한 번 부팅된 후로는 warm dex 캐시로 빨라짐. 우리 코드 이슈 아님 — 두번째 진입부터 정상

### Reflection 우회의 정당성

D-14 의 reflection 은 임시방편이지만 현재 정답:

- RN 0.83 Bridgeless 공식 API 가 multi-bundle 을 노출 안 함
- Toss Granite 도 같은 시점에 비공개 helper 로 우회
- Facebook 측에서 [`@FrameworkAPI`](https://github.com/facebook/react-native/blob/main/packages/react-native/ReactAndroid/src/main/java/com/facebook/react/runtime/ReactInstance.kt) annotation 으로 internal API 들을 점진적으로 public 으로 노출하는 흐름이라, RN 0.84/0.85 에서 공식 API 가 나오면 그때 교체

### Multi-bundle vs Mono — 무엇을 정식으로 둘지

- **Multi-bundle**: page 추가/수정 시 page bundle 만 재배포. shared 는 그대로. 미니앱 분리 배포의 기반
- **Mono**: 한 jsbundle 파일에 다 들어가서 sandbox 변경 0 으로 부팅 검증 가능. 그러나 page 추가 = 전체 재배포

정식은 **multi-bundle**. mono 는 우리 build pipeline 의 회귀 검증용으로 남김 (apps/native 의 `bundle:mono`). 다만 mono 검증을 하려면 `SandboxApplication.jsBundleFilePath` 를 일시적으로 `assets://main.jsbundle` 로 되돌려야 함 — 정식 코드는 항상 `assets://shared.bundle.js`.

### 다음 스프린트 보강 항목

1. **iOS multi-bundle** — ios-wip/ 마무리 후 `loadJSBundle` iOS 측 API 조사 (`RCTHost`)
2. **NavBridge NativeModule** — JS → Native pop/replace. 현재는 `BackHandler.exitApp()` 으로 Fragment backStack pop
3. **Page bundle 캐싱** — `MainActivity` 에 `loadedPages: Set<String>` 추가해서 재진입 시 evaluate skip
4. **CDN URL fetch** — `JSBundleLoader.createCachedBundleFromNetworkLoader` 사용. 미니앱 추가/수정 시 APK 재배포 불필요
5. ~~**`RNContainerFragment.kt` 제거**~~ — 2026-05-14 종결. 디스크에서 제거

---

## 회고 (2026-05-14) — 부채 정리

- **HelloRN/ 폐기**: MVP 회고 2번에서 지적한 "HelloRN/을 어디 둘지 처음부터 정해야 함" 의 결말. node_modules 의 실재 위치를 sandbox 루트로 옮기고 symlink 와 HelloRN/ 디렉토리를 제거 (D-19). 결과적으로 "sandbox-poc 는 host shell 이고, RN 소스는 0이며, npm 패키지는 오직 gradle 의 RN AAR 해소를 위해 존재한다" 가 디렉토리 구조에서도 명확해짐
- **RNContainerFragment.kt 제거 종결**: RN 0.83 회고 2번의 부산물이 디스크에서도 사라짐
- **다음**: iOS 라인 정상화 (ios-wip pbxproj 정합성 → URL scheme 등록 → multi-bundle 이식)

---

## 회고 (2026-05-14) — iOS 라인 정상화

### MVP 회고 1번의 처방을 그대로 적용 → 정답이었음

ios-wip pbxproj 의 ObjC 잔재 + Swift 파일 미등록 상태를 손으로 고치려 들지 않고, **RN CLI 로 0.83.2 fresh init → Swift 베이스 → sandbox 코드 입히기** 패턴 (Android RN 0.83 회고 1번과 동일) 으로 갔다. 30분 안에 끝남.

흡수한 것:
- ios-wip 의 `DevToolViewController.swift` 그대로 (UI 로직 변경 없음)
- ios-wip 의 URI 라우팅 사상 (`handle(url:in:)` → push `RNContainerViewController`)

폐기한 것:
- ios-wip 의 `AppDelegate.swift` (구식 `RCTRootView` 직접 호출). 0.83 의 `RCTReactNativeFactory` + `ReactNativeDelegate` 패턴으로 재작성
- ios-wip 의 `RNContainerViewController.swift` 의 `RCTRootView(bundleURL:moduleName:initialProperties:launchOptions:)` 직접 호출. 0.83 의 `factory.rootViewFactory.view(withModuleName:initialProperties:)` 로 재작성. RESERVED_KEYS 가드 + URI query 평탄화는 Android `MainActivity.buildInitialProps` 와 같은 형태로 통일

### pbxproj 등록은 xcodeproj gem 으로 멱등 스크립트화

`ios/add_swift_sources.rb` (xcodeproj 1.25.1 사용). 추후 파일 추가 시 같은 스크립트에 항목 추가 후 재실행하면 됨 — UUID/group/buildPhase 정합성은 gem 이 보장.

### Ruby 환경 블로커 (시스템 Ruby 2.6 부족)

`bundle install` 첫 시도가 `ffi-1.17.4 requires ruby version >= 3.0` 으로 실패. 시스템 Ruby 가 2.6 인 게 원인. 해결: **rbenv 로 Ruby 3.2.11 local 고정** 후 `bundle install`. `.ruby-version` 파일이 sandbox 루트에 생김.

### Multi-bundle 평가 (P2-2) 는 후속 분리

D-22 참조. RN 0.83 iOS 의 `RCTHost` 가 public multi-bundle 평가 API 를 노출 안 함. **`RCTHostDelegate.loadBundleAtURL:onProgress:onComplete:`** 를 오버라이드해서 page bundle URL 을 `RCTJavaScriptLoader.loadBundle(at:...)` 로 직접 평가하는 패턴이 정답. Android `loadBundle` reflection (D-14) 의 iOS 대응이지만, reflection 은 불필요 (delegate protocol 의 optional method). 본 스프린트에선 single bundle 부팅 + URI 라우팅 골격까지만 완료, multi-bundle 평가는 후속 작업.

### 다음 스프린트

1. **Xcode 16.1+ 설치** ⚠️ — 본 스프린트 verify 단계의 진짜 블로커. 사용자 머신 Xcode 15.4 → RN 0.83.2 `prepare_react_native_project!` 가 16.1+ 요구. App Store 또는 `xcodes` (`brew install xcodesorg/made/xcodes`) 로 업그레이드 후 `bundle exec pod install` + `xcodebuild build` 로 verify 완성
2. **iOS multi-bundle 평가 (D-22)** — `ReactNativeDelegate.loadBundleAtURL:` 오버라이드 + `assets/pages/{moduleName}.bundle.js` lookup
3. **iOS deploy:ios pipeline** — `apps/native` 측에 `yarn deploy:ios` 추가 (Android 의 `deploy:android` 대응). shared.bundle.js + pages/*.bundle.js 를 `ios/SandboxApp/Resources/` 로 배치
4. **NavBridge NativeModule (Android/iOS 공통)** — JS → Native pop/replace
5. **Page bundle 캐싱**
6. **CDN URL fetch**

---

## 회고 (2026-05-14 추가) — Ruby/CocoaPods 환경 시리즈 + Xcode 16.1 블로커

iOS 라인 verify 단계에서 부닥친 환경 이슈 4건. 코드/설정 작업이 끝난 뒤 발견된 것들이라 별도 회고.

### 1. Ruby 2.6 ↔ ffi 1.17 호환 불가

- 시스템 Ruby = `/usr/bin/ruby` 2.6.10. macOS 14 (Darwin 23) 가 deprecated Ruby 를 그대로 둠
- `bundle install` 첫 시도가 `ffi-1.17.4 requires ruby version >= 3.0` 으로 즉시 실패. ffi 는 cocoapods 의 transitive dependency
- 해결: **rbenv + Ruby 3.2.11** + `rbenv local 3.2.11` (sandbox 루트에 `.ruby-version` 생성)

### 2. xcodeproj gem 단독 설치 (rbenv 도입 전 임시 해결)

- 시작 시점엔 rbenv 없이 system Ruby 2.6 만 있어서, pbxproj 등록만 먼저 처리해야 했음
- `gem install xcodeproj -v '1.25.1' --user-install` (1.26+ 은 Ruby 3 요구). 의존성 누락된 `CFPropertyList` 도 같이 단독 설치
- `GEM_HOME` / `GEM_PATH` 를 `~/.gem/ruby/2.6.0` 으로 export 해서 system Ruby 가 user-install gem 을 찾도록 함
- rbenv 도입 후로는 이 user-install 분기는 더 이상 쓰지 않음. `bundle exec ruby ios/add_swift_sources.rb` 가 정식 진입점

### 3. cocoapods 1.15.0~1.15.2 + Ruby 3.2 `unicode_normalize` 버그

- Ruby 3.2 의 `String#unicode_normalize` 가 **`Encoding::ASCII-8BIT` 인코딩 String 에서 `CompatibilityError`**
- cocoapods 의 `config.rb:167:in 'installation_root'` 가 `Dir.pwd` 를 unicode normalize 하는데, Ruby 3.2 + macOS 14 환경에선 `Dir.pwd` 가 ASCII-8BIT 로 반환
- Gemfile 의 `cocoapods >= 1.13, != 1.15.0, != 1.15.1` 제약은 1.15.2 를 가져옴 → 같은 버그
- 처음엔 `cocoapods >= 1.16` 으로 강제했지만 1.16.2 에서도 같은 코드 경로 → 여전히 버그
- **진짜 해결**: `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` 환경변수. Ruby 가 String 의 default external encoding 을 UTF-8 로 잡으면 `Dir.pwd` 가 UTF-8 로 나오고 `unicode_normalize` 통과
- 부산물: Gemfile 의 `xcodeproj < 1.26.0` 제약도 풀음 (cocoapods 1.16 이 xcodeproj 1.26+ 요구)

### 4. RN 0.83.2 의 Xcode 16.1+ 요구 ⚠️ + macOS 호환성 체인

- LANG 픽스 후 `pod install` 이 마지막 단계에서 멈춤: `React Native requires XCode >= 16.1. Found 15.4. [!] Invalid Podfile file: Please upgrade XCode.`
- `node_modules/react-native/scripts/cocoapods/utils.rb` 의 `prepare_react_native_project!` 가 Xcode 버전을 체크
- 시도 1: `xcodes install 16.4` → 설치는 성공했지만 Xcode 16.4 가 macOS 15.0+ Sequoia 요구 → 사용자 시스템 macOS 14.3.1 에서 `kLSIncompatibleSystemVersionErr -10825` 로 앱 자체가 안 열림
- 시도 2: `xcodebuild -downloadPlatform iOS` 로 iOS 18.5 simulator runtime 다운로드 시도 → "iOS 18.5 is not available for download" — macOS 14.3.1 가 platform catalog 도 정상 접근 못 함
- 시도 3: pbxproj 의 Swift 파일 path 가 group path 와 안 맞아 `Build input files cannot be found` 에러 → `path = SandboxApp/X.swift` 로 명시 갱신 (`ios/add_swift_sources.rb` 도 같이 갱신)

### macOS × RN 0.83 × Xcode 호환 매트릭스 (2026-05-14 정리)

**중요 사실** (2025 WWDC 에서 Apple 이 numbering 통일):
- macOS / iOS / iPadOS / watchOS / tvOS / visionOS / **Xcode** 모두 "26" 으로 점프 (연도+1 기반). Xcode 17 은 없음
- **2026-05-14 현재 mainline production**: macOS **26.5** Tahoe (2026-05-11 release) + Xcode **26.5**
- macOS 14 (Sonoma) / 15 (Sequoia) 는 mainline 종료, 보안패치만 (14.8.7 / 15.7.7)
- **App Store 제출은 2026-04-28 부터 Xcode 26 (iOS 26 / iPadOS 26 / tvOS 26 / visionOS 26 / watchOS 26 SDK) 의무 — Apple News 2026-02-03, https://developer.apple.com/news/?id=ueeok6yw . macOS 앱은 이 발표에 별도 언급 없음. 신규 앱 + 업데이트 모두 해당. 오늘 (2026-05-14) 시점 이미 발효 중**

Apple 공식 system-requirements 기준 (https://developer.apple.com/xcode/system-requirements/):

| Xcode 버전 | minimum macOS | RN 0.83 (≥16.1) 요구 | App Store 제출 (2026-04+) | 비고 |
|---|---|---|---|---|
| 15.4 (현재 사용자) | Sonoma 14.0 | ❌ | ❌ | RN 0.83 호환 X |
| 16.0 | Sonoma 14.5 | ❌ | ❌ | 16.0 만 ≥16.1 미달 |
| 16.1 ~ 16.2 | Sonoma 14.5 | ✅ | ❌ | App Store 제출 불가 |
| 16.3 | Sequoia 15.2 | ✅ | ❌ | |
| 16.4 | Sequoia 15.3 | ✅ | ❌ | |
| **26.0 ~ 26.3** | Sequoia **15.6** | ✅ | ✅ | App Store 통과 가능 |
| **26.4 ~ 26.5** | Tahoe **26.2** | ✅ | ✅ | **권장** (mainline) |

**결정 (회사 IT 정책상 OS 업그레이드 보류 — 2026-05-14 시점)**: 다음 iOS verify 재개 시점에 **Xcode 26.x (최신 26.5)** 를 표준으로 한다. 이유:

1. **App Store 제출 강제** — 본 iOS 레포 (lp-mktplatform-ios) 가 2026-04 이후 출시/업데이트하려면 Xcode 26 SDK 로 빌드된 IPA 필요. sandbox 가 거기에 맞춰야 통합 시점 마찰 0
2. **macOS Tahoe 26 이 현재 mainline** — Sonoma 14 / Sequoia 15 는 이미 보안패치만. 회사 IT 가 OS 를 올려준다면 Tahoe 가 자연스러운 선택
3. **RN 0.83 + Xcode 26 공식 지원 선언** — 단 Swift Explicit Modules 이슈 알려짐. 워크어라운드: 프로젝트 build settings 에 `SWIFT_ENABLE_EXPLICIT_MODULES = NO` (참조: https://github.com/react-native-community/discussions-and-proposals/discussions/978)

**현실적 단계별 fallback** (회사 IT 가 Tahoe 26 을 한 번에 안 풀어줄 경우):

| 회사가 풀어주는 OS | 권장 Xcode | App Store 제출 |
|---|---|---|
| Tahoe 26.2+ | **26.5** | ✅ |
| Sequoia 15.6+ (구버전) | **26.0 ~ 26.3** | ✅ (App Store OK) |
| Sequoia 15.0~15.5 | 16.2 | ❌ (시뮬레이터 검증만, App Store 제출 불가) |
| Sonoma 14.5+ (보안패치만 받은 상태) | 16.2 | ❌ (검증만) |

본 sprint 의 sandbox iOS 검증은 **Sequoia 15.6+ 도 충분** — App Store 제출이 아닌 simulator 검증 목적이라.

### 본 iOS 레포 (lp-mktplatform-ios) 와 align

본 iOS 레포 `mise.toml` / Fastlane / GitHub Actions 의 Xcode 버전 핀 확인 별도 TODO. 그 값이 sandbox 의 표준이 되는 게 통합 마찰 최소.

### 재개 조건 (회사 IT macOS 업그레이드 완료 후)

1. 시스템 검증: `sw_vers` 가 `ProductVersion: 26.x` 또는 `15.6+` 로 떴는지
2. Xcode 26.5 설치: `xcodes install 26.5 --select`
3. RN 0.83 의 Swift Explicit Modules 이슈 사전 처리: `ios/Podfile` 의 `post_install` 에 다음 한 줄 추가 검토
   ```ruby
   installer.pods_project.targets.each do |t|
     t.build_configurations.each do |c|
       c.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
     end
   end
   ```
4. iOS simulator runtime: Xcode 26 의 default iOS runtime 다운로드 (GUI Platforms 또는 `xcodebuild -downloadPlatform iOS`)
5. 본 sandbox 의 `bundle exec pod install` 은 이미 통과 (cocoapods 1.16+, Hermes 14.1, RN 80 deps). 재개 시점엔 `xcodebuild build` + `xcrun simctl boot` + `xcrun simctl openurl booted "lifeplus-tribes://HelloRN"` 만 남음

### 학습

- macOS 의 system Ruby 는 더 이상 신뢰 X. RN brownfield 작업 시작 시 첫 단계로 **rbenv + Ruby 3.x + `LANG=en_US.UTF-8`** 환경 보장이 합리적
- Gemfile 의 cocoapods/xcodeproj 제약은 RN CLI template 의 historical workaround 모음 — Ruby/cocoapods 버전 올라가면서 제약 자체가 발목을 잡음
- Xcode 버전 요구는 RN 메이저 릴리스마다 점프함. RN 0.83 = Xcode 16.1+ — Phase 1 진입 전 빌드 머신 사전 점검 항목으로 추가 필요

---

## 회고 (2026-05-15) — iOS verify 재개 + multi-bundle 완성

2026-05-14 회고의 "재개 조건" 이 모두 충족된 상태에서 verify 재개. 환경 점검 → fmt 호환 패치 → simulator 빌드/실행 → multi-bundle 평가까지 한 사이클로 완주.

### 환경 (확정)

| 항목 | 값 |
|---|---|
| macOS | **26.3 Tahoe** (회사 IT macOS 업그레이드 완료) |
| Xcode | **26.5** (`/Applications/Xcode-26.5.0.app`, `xcodes install 26.5 --select` 로 설치) |
| iOS Simulator runtime | iOS 26.5 (23F77) — `xcodebuild -downloadPlatform iOS` 로 추가 (~8.5 GB) |
| Ruby | 3.2.11 (rbenv, `.ruby-version`) |
| CocoaPods | 1.16+ (Gemfile) |
| LANG | `en_US.UTF-8` |

### 발견 1: Xcode SDK ↔ Simulator runtime 의 분리

`xcodes install 26.5 --select` 만으론 simulator 검증 불가. Xcode 26.5 의 default SDK = **iOS 26.5 SDK 만 번들**, iOS 17 SDK 는 같이 안 옴. 기존 Xcode 16.4 가 들고 있던 iOS 17.5 simulator 는 `xcodebuild build -destination 'OS=17.5'` 시점에 `Ineligible` (build 가 iOS 26.5 SDK 를 요구하는데 17 destination 매칭 X). 빌드 검증하려면 `xcodebuild -downloadPlatform iOS` 로 default iOS 26 runtime 추가 다운로드 필수.

**단 빌드 destination 과 install 가능 destination 은 별개**: Xcode 26.5 + iOS 26.5 SDK 로 빌드된 `.app` (deployment target 15.1) 은 iOS 17.5 simulator 에 install + run 가능 (2026-05-15 검증). 즉 **multi-version verify 매트릭스는 단일 빌드 산출물을 여러 OS 시뮬에 install 하는 형태** — Xcode 26.5 환경에 iOS 17 simulator runtime 만 있으면 충분 (별도 빌드 destination 필요 없음). iOS 17.5 runtime 은 시스템 catalog 에 disk image 로 살아있어 Xcode 16.4 삭제 후에도 그대로 사용 가능.

### 발견 2: fmt 11.0.2 ↔ Apple clang 21 (Xcode 26) consteval 호환 X

`xcodebuild build` 첫 시도가 **fmt 의 `FMT_STRING` 매크로**에서 5개 컴파일 에러:

```
fmt/include/fmt/format-inl.h:1394:33: error: call to consteval function ... is not a constant expression
```

원인: Apple clang 21 의 strict consteval 이 fmt 의 `FMT_STRING(s)` 매크로 lambda 안 `compile_string` constructor 호출을 거부. fmt 가 `__cpp_consteval` 매크로로 자동 enable 했는데 Xcode 26 clang 이 더 엄격해진 것. 알려진 이슈 (facebook/react-native#55601, fmtlib/fmt#4740).

해결: Podfile `post_install` 에서 `fmt/include/fmt/base.h` 의 `FMT_USE_CONSTEVAL` 매크로 체인을 sed-style 패치로 강제 0 — line 127, 129 의 두 `#define FMT_USE_CONSTEVAL 1` 모두 0 으로. fmt 의 매크로 체인이 외부 `-D` 로 못 덮는 구조 (조건문이 무조건 `#define` 한다) 라 헤더 자체 패치가 정답. CocoaPods 가 source 를 readonly (`-r--r--r--`) 로 설치하므로 `File.chmod(0o644)` 후 write. RN 0.84+ 의 fmt 업그레이드까지 임시방편 (D-28).

### 발견 3: D-22 사전 조사가 틀린 추측이었음

본 verify 사이클의 가장 큰 자산. 2026-05-14 의 D-22 "계획" 이 **`RCTHostDelegate.loadBundleAtURL:` override + `RCTJavaScriptLoader.loadBundleAtURL:`** 로 추측했는데, 실제 구현해보니 이건 잘못된 경로:

- `RCTHostDelegate.loadBundleAtURL:` 는 RN 이 *자기 안에서* additional bundle 을 요청할 때 dispatch 되는 **inbound hook** — sandbox 가 *외부에서* page bundle 을 강제 평가하기엔 부적합
- `RCTJavaScriptLoader.loadBundleAtURL:` 는 단순 fetch 기능만, JS 평가는 별도

**실제 정답** (D-22 갱신, PageBundleLoader.mm):
1. `RCTHost._instance` private ivar 를 ObjC runtime reflection (`class_getInstanceVariable(host, "_instance")`) 로 RCTInstance 추출
2. `RCTInstance.callFunctionOnBufferedRuntimeExecutor:^(jsi::Runtime &){ ... }` 로 JS thread hop
3. 그 lambda 안에서 `runtime.evaluateJavaScript(StringBuffer(source), sourceURL)` — jsi::Runtime& 가 RN 0.74+ Bridgeless 의 표준 진입점
4. callstack/react-native-sandbox `SandboxReactNativeDelegate.mm` 패턴 그대로

즉 Android `loadBundle$ReactAndroid_debug` reflection (D-14) 의 진짜 iOS 짝은 **delegate override 가 아니라 RCTInstance ivar reflection + `callFunctionOnBufferedRuntimeExecutor`**. 이 reflection 의 정당성은 D-24 에 정리.

### 발견 4: ObjC++ ↔ Swift bridging 의 함정 (RCTHost.h C++ STL)

`PageBundleLoader.h/.mm` 를 ObjC++ 로 분리한 이유 (D-25):
- `RCTHost.h` 가 C++ STL (`<string>`, `<functional>`, `<iosfwd>`, `react/runtime/JSRuntimeFactory.h`) 을 끌어옴
- Swift bridging header (`SandboxApp-Bridging-Header.h`) 는 Objective-C 모드라 C++ STL 헤더 못 받음 → build error
- 해결: PageBundleLoader 를 `.mm` 로 격리해서 자기 안에서 `<ReactCommon/RCTHost.h>` import. Swift 측은 `SandboxReactNativeDelegate` 라는 ObjC++ base class 만 import 받고 상속. Swift 코드는 RCTHost / jsi::Runtime 타입을 안 만짐

### 발견 5: prewarm 패턴

Android 의 `addReactInstanceEventListener` (cold path 대기) + `currentReactContext != null` (warm path 가드) 와 같은 분기를 iOS 에서 더 단순화 (D-23):
- `AppDelegate` 가 부팅 시 `factory.rootViewFactory.view(withModuleName: "__prewarm", ...)` 한 번 호출 → `RCTHost.start` 트리거 → shared.bundle 평가 + RCTInstance 생성
- `hostDidStart:` 가 RCTInstance 캐치 (PageBundleLoader 의 static 변수 `gRctInstance`)
- URI 진입 시점엔 `gRctInstance` 가 이미 set 돼 있음 → 즉시 evaluate (단 polling 16ms × max 5s 가드도 같이 둠 — race 방어)

### Verify 결과

`xcrun simctl openurl booted "lifeplus-tribes://detail?orderId=ABC123"` 결과 화면 (iPhone 17 Pro / iOS 26.5):

- 상단: `/detail` (moduleName = `detail`, title bar)
- 본문: "Auto-registered from src/pages/detail.tsx — no manual route table needed."
- **InitialProps (from sandbox)**: `initialPath=/`, `platform=ios`, `appVersion=1.0`
- **URI query params**: `orderId = ABC123` ← URI query 평탄화 (D-13) 가 iOS 에서도 동작
- 좌상단 ← back 버튼 (UINavigationController push)

→ 즉 shared.bundle 평가 + page bundle (`pages/detail.bundle.js`) 동적 평가 + `AppRegistry.registerComponent("detail", ...)` + RN surface mount + InitialProps 전달 + URI query 평탄화까지 **전 라인 통과**. iOS Phase 1.5 + Phase 2-1 (D-22) 한 번에 완성.

### iOS 17.5 multi-version verify (2026-05-15 추가 검증)

`xcodes uninstall 16.4` + Xcode.app (15.4) 삭제 후 같은 cycle 을 iOS 17.5 에서 재실행:

- iOS 17.5 simulator runtime 이 시스템 catalog 에 disk image 로 남아있음 (Xcode 16.4 본체 삭제 후에도) — `xcrun simctl runtime list` 가 `iOS 17.5 (21F79) ... (Ready)` 보고
- 동일 `.app` (재빌드 X, 26.5 빌드 산출물 그대로) 을 `xcrun simctl install "iPhone 15 Pro" ...` 으로 install
- `xcrun simctl launch --console + sleep 5 + openurl + sleep 6` 시퀀스로 same-process launch flow 유지 (kill 타이밍 어긋나면 iOS 17 의 "Sandbox에서 열겠습니까?" 사용자 동의 다이얼로그가 떠 verify 중단됨 — iOS 26 에선 안 뜸)
- 결과: 동일 화면 (`/detail` + InitialProps + `orderId=ABC123`). 즉 **Xcode 26.5 + iOS 26.5 SDK 빌드 산출물이 iOS 17 ~ 26 매트릭스에서 동작 일관성 확보**

### 다음 스프린트

1. **`apps/native` 의 `yarn deploy:ios`** — 현재는 사용자가 손으로 dist/ 산출물을 `ios/SandboxApp/{shared.bundle.js, pages/*.bundle.js}` 로 배치한 상태. 정식 자동화 필요 (Android `deploy:android` 의 iOS 짝)
2. **NavBridge NativeModule** — JS → Native pop/replace. 현재는 iOS `popViewController` / Android `BackHandler.exitApp()` 으로 임시
3. **NavBar UI 정리** — `RNContainerViewController` 가 `UINavigationController` push 패턴인데 iOS 17 에선 NavBar 가 light 로 그려져 RN 페이지와 색 안 맞음. `setNavigationBarHidden(true)` 또는 RN side 에서 자체 nav 처리 결정. 본 앱 host shell 통합 시 정리
4. **CDN URL fetch** — page bundle 을 원격 URL 에서 fetch + 캐시. `RCTJavaScriptLoader.loadBundleAtURL:` 가 file:// 외 http(s):// 도 지원하는지 검증 필요
5. **본 iOS 레포 (lp-mktplatform-ios) 의 Xcode 버전 핀 확인 + align** — sandbox 의 Xcode 26.5 표준이 본 레포와 동기되는지

### 학습

- **사전 조사는 *경로 후보 정찰* 까지가 가치 있고, *어떤 경로가 정답인지 단정* 은 실제 빌드 위에서만 검증됨**. 본 회고 발견 3번이 그 예 — D-22 사전 조사는 RCTHost.h 의 public surface 만 읽고 추측했는데 실제 구현은 `RCTInstance` (한 layer 아래) 가 답이었음. callstack/react-native-sandbox 같은 production 패턴을 사전 조사 단계에서 함께 보면 더 정확해짐
- **Android reflection ↔ iOS reflection 은 같은 사상의 다른 표현**. JVM mangled name (`loadBundle$ReactAndroid_debug`) 와 ObjC runtime ivar (`_instance`) 가 RN 0.83 의 internal API 가시성 정책의 양면. RN 0.84+ 에서 두 reflection 모두 동시에 제거 가능할 것
- **Xcode 메이저 점프시 RN 호환성 패치 라인업이 늘어남** — RN 0.83 + Xcode 26 = (a) Swift Explicit Modules disable + (b) fmt FMT_USE_CONSTEVAL=0 헤더 패치 두 개가 필수. 본 iOS 레포 통합 시 Podfile post_install 에 같이 반영 필요
