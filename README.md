# sandbox-poc — RN Multi-Bundle Native Shell

> **현재 정체성**: life 모노레포의 `apps/native` 가 만드는 미니앱 번들들을 *동적으로* 띄우는 Native Host Shell. Granite 스타일의 micro-frontend 모델.
>
> **이전 정체성 (MVP)**: URI 스킴 수신 → RN Container 띄우기까지를 Native만으로 증명하는 최소 PoC. 정적 hello-world `main.jsbundle` 부팅 검증. 이 단계는 종결됐고, 그 흔적은 [decisions.md](decisions.md) 의 회고 섹션에.

상위 컨텍스트는 Obsidian `1-Projects/Epic-RN-metro/` + life 모노레포 [apps/native/README.md](https://github.com/lp-mktplatform/life/tree/main/apps/native) 참고.

---

## 아키텍처 한 장 요약

```
              부팅                                        URI 진입
                │                                            │
                ▼                                            ▼
       SandboxApplication                          MainActivity.handleIntent
       └ getDefaultReactHost(                      └ appName  = uri.host (=moduleName)
           jsBundleFilePath =                      └ path     = uri.path
           "assets://shared.bundle.js")            └ params   = uri.queryParameters
                │                                            │
                ▼                                            ▼
       ReactHost 가 shared 평가                     loadPageBundle(appName, onComplete)
       (RN polyfill + InitializeCore +              └ ReactInstance 미준비:
        globalThis.__SHARED__ 채움)                    addReactInstanceEventListener 대기
                                                    └ 준비 완료:
                                                       ReactHostImpl.loadBundle (reflection)
                                                       ↓
                                                    assets://pages/{appName}.bundle.js 평가
                                                       ↓
                                                    AppRegistry.registerComponent(appName)
                                                       ↓
                                                    ReactFragment.Builder()
                                                       .setComponentName(appName)
                                                       .setLaunchOptions(initialProps)
                                                    → surface mount
```

핵심 약속:

| 항목 | 값 |
|---|---|
| URI 스킴 | `lifeplus-tribes` (life 모노레포 `AppScheme` 공통, [decisions.md](decisions.md) D-3) |
| 부팅 번들 | `assets://shared.bundle.js` (metro-wrap 된 vendor 묶음, ~860KB) |
| 미니앱 번들 | `assets://pages/{moduleName}.bundle.js` (raw IIFE, ~5KB) |
| InitialProps | `initialPath`, `platform`, `appVersion` + URI query 평탄화 (모든 query 키 putString) |
| moduleName | URI host = `AppRegistry.registerComponent` 의 첫 인자 |

미니앱 번들 생성 + 본 host shell 로의 배치는 모두 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) 측 책임. 본 레포는 *호스트*.

---

## 진행 상태

### MVP (2026-05-11 완료, iOS 는 2026-05-15 verify 완료)

| DoD | Android | iOS |
|---|---|---|
| DoD-1 빌드 성공 | ✅ | ✅ Xcode 26.5 / macOS 26.3 / iOS 26.5 SDK |
| DoD-2 DevTool UI 스킴 입력 | ✅ | ✅ DevToolViewController |
| DoD-3 스킴 파싱 로그 | ✅ | ✅ AppDelegate.handle |
| DoD-4 정적 번들로 RN 부팅 | ✅ | ✅ shared.bundle.js + pages/*.bundle.js |

### Phase 1 — Multi-bundle host shell (2026-05-13 완료, Android)

| 항목 | 상태 | 비고 |
|---|---|---|
| InitialProps query params 평탄화 | ✅ | `MainActivity.handleIntent` 가 `uri.queryParameterNames` 를 모두 `putString`. RESERVED_KEYS 가드. iOS 도 `RNContainerViewController.buildInitialProps` 가 동일 형태 |
| Multi-bundle 평가 (Android) | ✅ | `MainActivity.loadPageBundle` 가 `JSBundleLoader.createAssetLoader` + `ReactHostImpl.loadBundle` (reflection) |
| ReactInstance ready 대기 | ✅ | `addReactInstanceEventListener` + `currentReactContext` 가드 |
| URI 스킴 통일 | ✅ | `lifeplus-sandbox` → `lifeplus-tribes` (모노레포 공통). iOS `CFBundleURLTypes` 에도 등록 |

### Phase 1.5 — iOS 라인 정상화 (2026-05-14)

| 항목 | 상태 | 비고 |
|---|---|---|
| ios-wip/ → ios/ 전환 | ✅ | RN 0.83.2 fresh init 의 Swift 템플릿 베이스로 재구성. ObjC 잔재 0 |
| Bundle ID / URL scheme | ✅ | `com.lifeplus.sandbox` / `lifeplus-tribes` (Info.plist `CFBundleURLTypes`) |
| DevToolViewController.swift | ✅ | ios-wip 의 코드 흡수, 동작 변경 없음 |
| RNContainerViewController.swift | ✅ | `factory.rootViewFactory.view(withModuleName:initialProperties:)` 패턴으로 재작성 |
| pbxproj Swift 등록 | ✅ | `ios/add_swift_sources.rb` (xcodeproj gem) 멱등 스크립트 |
| iOS multi-bundle 평가 | ✅ | 2026-05-15 완성 — Phase 2-1 참조 |

### Phase 2-1 — iOS multi-bundle host shell (2026-05-15 완료)

| 항목 | 상태 | 비고 |
|---|---|---|
| Xcode 26.5 + macOS 26.3 환경 정착 | ✅ | `xcodes install 26.5 --select` + iOS 26.5 simulator runtime 다운로드 (~8.5GB) |
| fmt 11.0.2 ↔ Apple clang 21 호환 패치 | ✅ | Podfile post_install 에서 `fmt/base.h` 의 `FMT_USE_CONSTEVAL` 매크로 체인 강제 0 (D-28, facebook/react-native#55601) |
| Swift Explicit Modules disable | ✅ | Podfile post_install 의 `SWIFT_ENABLE_EXPLICIT_MODULES = NO` (D-28) |
| RCTInstance prewarm | ✅ | `AppDelegate` 가 부팅 시 dummy moduleName 으로 `view(...)` 호출 → `RCTHost.start` 트리거 (D-23) |
| RCTInstance reflection | ✅ | `class_getInstanceVariable(host, "_instance")` 로 RCTInstance 추출. `hostDidStart:` 가 캐치 (D-24) |
| Multi-bundle 평가 | ✅ | `RCTInstance.callFunctionOnBufferedRuntimeExecutor:^(jsi::Runtime &){ runtime.evaluateJavaScript(...); }` (PageBundleLoader.mm, D-22) |
| ObjC++ ↔ Swift bridging | ✅ | `PageBundleLoader.h/.mm` 격리 + `SandboxApp-Bridging-Header.h`. `RCTHost.h` 의 C++ STL 회피 (D-25) |
| Page bundle 캐싱 | ✅ | `RNContainerViewController.loadedPages: Set<String>` 으로 두번째 진입부터 evaluate skip (D-26) |
| iOS page bundle 배치 | ✅ | `ios/SandboxApp/{shared.bundle.js, pages/{moduleName}.bundle.js}` — Xcode folder reference (D-27) |
| Verify (iPhone 17 Pro / iOS 26.5) | ✅ | `lifeplus-tribes://detail?orderId=ABC123` → `/detail` 페이지 + InitialProps + URI query 평탄화 전부 동작 |
| Verify (iPhone 15 Pro / iOS 17.5) | ✅ | 동일 `.app` (재빌드 X) 을 iOS 17.5 시뮬에 install → 동일 화면. 단일 빌드 산출물의 multi-version 매트릭스 확정 |

### 다음 단계 (Phase 2-2 이후)

1. **`apps/native` 의 `yarn deploy:ios`** — 현재는 손으로 dist/ 산출물을 ios resources 로 배치. 정식 자동화 (Android `deploy:android` 의 iOS 짝)
2. **NavBridge NativeModule** — JS → Native pop/replace. 현재는 `BackHandler.exitApp()` / iOS `popViewController` 으로 임시
3. **NavBar UI 정리** — iOS NavController 의 NavBar 와 RN 페이지 색 충돌. 본 앱 host shell 통합 시점에 처리
4. **CDN URL fetch** — page bundle 을 원격 URL 에서 fetch + 캐시. 미니앱 추가/수정 시 APK/IPA 재배포 불필요
5. **`ReactHostImpl.loadBundle` (Android D-14) + `RCTHost._instance` (iOS D-22/D-24) reflection 제거** — RN 0.84+ 에서 public API 가 나오면 동시에 제거 가능
6. **본 iOS 레포 (lp-mktplatform-ios) 와 Xcode 버전 핀 align** — `mise.toml` / Fastlane / GitHub Actions 확인

---

## 레포 구조

```
sandbox-poc/
  ios/
    SandboxApp/
      AppDelegate.swift           ← @main, ReactNativeDelegate, URI 라우팅
      DevToolViewController.swift ← URI 입력 + 최근 실행 목록
      RNContainerViewController.swift ← URI 진입 시 page bundle 평가 + RN surface mount
      PageBundleLoader.h/.mm      ← ObjC++ multi-bundle 평가 (RCTInstance reflection + jsi::Runtime)
      SandboxApp-Bridging-Header.h ← Swift ↔ ObjC++ 브릿지
      Info.plist                  ← CFBundleURLTypes (lifeplus-tribes)
      shared.bundle.js            ← apps/native deploy:ios 산출물 (수동 배치 중 — 자동화 TODO)
      pages/                      ← Xcode folder reference (파란 아이콘)
        HelloRN.bundle.js
        detail.bundle.js
    SandboxApp.xcodeproj          ← pbxproj. Swift/ObjC++ 등록은 add_swift_sources.rb 멱등 스크립트
    SandboxApp.xcworkspace        ← CocoaPods 통합. xed -b . 진입점
    Podfile                       ← post_install 워크어라운드 (D-28): SWIFT_ENABLE_EXPLICIT_MODULES=NO + fmt/base.h FMT_USE_CONSTEVAL 패치
    add_swift_sources.rb          ← pbxproj 에 새 source 파일 멱등 등록
  android/
    app/
      src/main/
        java/com/lifeplus/sandbox/
          SandboxApplication.kt   ← jsBundleFilePath="assets://shared.bundle.js"
          MainActivity.kt         ← URI host → loadPageBundle → ReactFragment commit
          DevToolFragment.kt      ← Metro IP 입력 + 정적/Metro 모드 토글
        assets/
          shared.bundle.js        ← apps/native deploy:android 산출물 (커밋)
          pages/
            HelloRN.bundle.js     ← apps/native moduleName 기반 산출물
            detail.bundle.js
        AndroidManifest.xml       ← <data android:scheme="lifeplus-tribes" />
        res/layout/fragment_devtool.xml
      build.gradle
    build.gradle
    settings.gradle
  Gemfile                         ← CocoaPods + xcodeproj gem (iOS 작업용)
  package.json                    ← RN 0.83.2 + React 19.2.1 빌드 의존성 (gradle plugin 이 node_modules 참조)
  node_modules/
  decisions.md
  README.md
```

`assets/` 내용은 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) 의 `yarn deploy:android` 가 채움. 본 레포에선 *받는 쪽 계약*만 정의.

본 레포는 자체 RN 소스(`App.tsx` / `index.js` 등)는 없다. node_modules 가 필요한 이유는 단순히 **Android Gradle 빌드가 RN Gradle Plugin + `react-android` AAR + Hermes AAR 을 npm 패키지에서 해소**하기 때문 ([decisions.md](decisions.md) D-19). 디바이스 런타임에는 node 가 없어도 됨.

---

## 빌드 & 실행

### 사전 요구

- macOS, Xcode 15+ (iOS 작업 시), CocoaPods, Ruby
- Android Studio + JDK 17 + Android SDK API 34+
- Node.js 18+ (apps/native 빌드 시)

### Android

```bash
# 1) apps/native 에서 미니앱 번들 빌드 + 본 레포 assets/ 로 배치
cd path/to/life/apps/native
yarn bundle:mono android      # shared + 모든 page 빌드
yarn deploy:android           # assets/shared.bundle.js + assets/pages/*.bundle.js 로 복사

# 2) sandbox APK 빌드 + 설치
cd path/to/sandbox/android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk

# 3) 진입
adb shell am force-stop com.lifeplus.sandbox
adb shell am start -W -a android.intent.action.VIEW \
  -d "lifeplus-tribes://HelloRN?foo=hello&bar=42"
# logcat:
#   I sandbox-poc: RN mode: static multi-bundle (shared + pages/*)
#   I sandbox-poc: loading page bundle: assets://pages/HelloRN.bundle.js
#   I ReactNativeJS: Running "HelloRN"
```

### iOS

2026-05-15 multi-bundle verify 완료 ([decisions.md](decisions.md) 회고 2026-05-15). Phase 1.5 (ios-wip → ios 정상화, D-20) + Phase 2-1 (PageBundleLoader 기반 multi-bundle 평가, D-22~D-27) 한 사이클로 마감.

#### 사전 요구 (한 번만)

| 항목 | 버전 | 비고 |
|---|---|---|
| **macOS** | **26.2+ Tahoe** (또는 Sequoia 15.6+) | Xcode 26.x 의 minimum macOS |
| **Xcode** | **26.5** (권장) | RN 0.83 ≥16.1 + App Store 제출 2026-04+ 의무 ≥26. `xcodes install 26.5 --select` ([decisions.md](decisions.md) 회고 환경 시리즈 #4) |
| **iOS Simulator runtime** | **iOS 26.5** | Xcode 26.5 의 default SDK 만 들어옴, simulator runtime 은 별개. `xcodebuild -downloadPlatform iOS` 로 추가 (~8.5 GB) |
| **Ruby** | ≥ **3.2** (3.2.11 권장) | macOS system Ruby 2.6 은 ffi 1.17+ 호환 X. `.ruby-version` 가 sandbox 루트에 박힘 → rbenv 가 자동 픽 |
| **CocoaPods** | 1.16+ (Gemfile 이 강제) | 1.15.x 는 Ruby 3.2 `unicode_normalize` 버그 |
| 셸 로케일 | `LANG=en_US.UTF-8` / `LC_ALL=en_US.UTF-8` | `pod install` 실행 시 필수 — Ruby 3.2 가 `Dir.pwd` 를 ASCII-8BIT 로 반환하면 cocoapods 가 죽음 |

#### 빌드

```bash
# 1) Ruby + bundler (한 번만)
brew install rbenv ruby-build
rbenv install -s 3.2.11
eval "$(rbenv init - $(basename $SHELL))"
cd path/to/sandbox
bundle install   # cocoapods 1.16+, xcodeproj, activesupport, ...

# 2) Xcode 26.5 + iOS simulator runtime (한 번만)
xcodes install 26.5 --select
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS   # iOS 26.5 simulator runtime (~8.5 GB)

# 3) pod install (LANG + Podfile 워크어라운드 자동 적용)
#    Podfile post_install 이 (a) SWIFT_ENABLE_EXPLICIT_MODULES=NO + (b) fmt/base.h FMT_USE_CONSTEVAL=0 패치를 한다 (D-28)
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
cd ios
bundle exec pod install

# 4) page bundle 배치 (apps/native deploy:ios 자동화 전까진 수동)
#    ios/SandboxApp/shared.bundle.js
#    ios/SandboxApp/pages/{moduleName}.bundle.js  (예: HelloRN, detail)
#    Xcode 에서 folder reference 로 추가 (파란색 아이콘). 그래야 .app/pages/ 디렉토리가 유지됨 (D-27)

# 5) Xcode 열기
xed -b .   # 또는 open SandboxApp.xcworkspace

# 6) xcodebuild CLI 빌드 (시뮬레이터)
bundle exec xcodebuild \
  -workspace SandboxApp.xcworkspace \
  -scheme SandboxApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath build \
  build

# 7) 시뮬레이터 부팅 + 앱 설치 + URL scheme 진입
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/SandboxApp.app
xcrun simctl launch booted com.lifeplus.sandbox
xcrun simctl openurl booted "lifeplus-tribes://detail?orderId=ABC123"
# NSLog (console=stdout 모드일 때):
#   [sandbox-poc] open url=lifeplus-tribes://detail?orderId=ABC123 appName=detail path=/ params=["orderId":"ABC123"]
#   [sandbox-poc] loading page bundle: file://.../pages/detail.bundle.js
#   [PageBundleLoader] captured RCTInstance: 0x...
#   [sandbox-poc] page bundle evaluated: detail
#   [sandbox-poc] mounted RN surface moduleName=detail initialPath=/ params=["orderId":"ABC123"]
```

pbxproj 에 새 Swift / ObjC++ 파일을 추가할 일이 생기면 `ios/add_swift_sources.rb` 에 항목을 더하고 `bundle exec ruby ios/add_swift_sources.rb` 재실행 (멱등).

---

## DevTool 사용법

앱 첫 진입 시 (URI 없이 런처에서 띄울 때) 자동 노출되는 화면.

1. **스킴 입력 필드** — `lifeplus-tribes://HelloRN` 같은 URI 직접 입력 + 실행 버튼
2. **Metro 서버 IP 입력 필드** — 비워두면 정적 multi-bundle 모드, IP 입력 시 Metro 단일 번들 모드 (Phase 1-2 잔존)
3. **최근 입력 스킴 목록** — 자주 쓰는 URI 빠른 진입

자체 호출 (DevTool 미사용):

```bash
# iOS 시뮬레이터 (ios-wip 마무리 시)
xcrun simctl openurl booted "lifeplus-tribes://HelloRN"

# Android 에뮬레이터/실기기
adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-tribes://HelloRN"
```

---

## RN / React 버전

- **React Native 0.83.2** (New Architecture only, Bridgeless)
- **React 19.2.1** (life 모노레포 React 19 통일에 맞춤)
- Hermes ON · Fabric ON

이전 (MVP 초기) RN 0.74.5 + React 18.x → 2026-05-11 0.83.2 업그레이드. 자세한 회고는 [decisions.md](decisions.md).

---

## 동작 모드

sandbox-poc 는 세 가지 모드로 동작. `SandboxApplication.useMetro` 가 `metroIp` SharedPreferences 의 비어있지 않음 여부로 분기.

| 모드 | 트리거 | 부팅 번들 | 미니앱 번들 | 용도 |
|---|---|---|---|---|
| **Multi-bundle (정식)** | `metroIp` 비어있음 + `assets://shared.bundle.js` 존재 | `assets://shared.bundle.js` | `assets://pages/{moduleName}.bundle.js` (URI 진입 시 동적 평가) | 본 배포 흐름. apps/native deploy:android 산출물 사용 |
| **Mono 회귀 (선택)** | `metroIp` 비어있음 + `assets://main.jsbundle` 사용 | `assets://main.jsbundle` (shared+pages concat) | 단일 번들 | 우리 build pipeline 회귀 검증용. `SandboxApplication.jsBundleFilePath` 를 일시적으로 main.jsbundle 로 되돌려야 동작 |
| **Metro (개발)** | `metroIp` 입력됨 | Metro 서버에서 fetch (`http://{ip}/index.bundle`) | 단일 번들 | RN 개발 hot reload 용도. Phase 1-2 잔존 |

`SandboxApplication.reactHost`:
```kotlin
override val reactHost: ReactHost by lazy {
    getDefaultReactHost(
        context = applicationContext,
        packageList = PackageList(this).packages,
        jsMainModulePath = "index",
        jsBundleFilePath = if (useMetro) null else "assets://shared.bundle.js",
        useDevSupport = useMetro,
    )
}
```

---

## Multi-bundle 로더 내부 동작

### Android — `MainActivity.loadPageBundle`

1. **`ReactInstance` 가 살아있는지 확인** — `reactHost.currentReactContext != null`
   - 살아있으면 즉시 `invokeLoadBundle` 호출 (warm path, 두번째 진입부터)
   - 없으면 `addReactInstanceEventListener` 등록 후 `host.start()` → 초기 shared 평가 끝나면 listener 콜백 (cold path, 첫 진입)
2. **`JSBundleLoader.createAssetLoader(context, "assets://pages/{appName}.bundle.js", false)`** — public API
3. **`ReactHostImpl.loadBundle$ReactAndroid_debug(loader)`** — reflection 으로 호출. Kotlin `internal` 가시성을 JVM mangled name prefix match 로 우회
4. **Bolts `Task<Boolean>` 폴링** — `isCompleted` / `isFaulted` / `getResult` / `getError` 를 16ms 단위로 체크 (page bundle 평가 끝나는 시점 감지)
5. **성공 시** — 그 안의 `AppRegistry.registerComponent({appName}, ...)` 가 이미 호출됨 → `ReactFragment.Builder().setComponentName(appName)` 로 surface mount

### iOS — `PageBundleLoader.evaluatePageBundle` + `RNContainerViewController`

Android 의 `loadPageBundle` 시퀀스를 RN 0.83 Bridgeless iOS 의 표준 진입점으로 변환:

1. **prewarm** — `AppDelegate.didFinishLaunchingWithOptions` 가 부팅 시 `factory.rootViewFactory.view(withModuleName: "__prewarm", ...)` 한 번 호출. 이게 `RCTHost.start` 를 트리거 → shared.bundle 평가 + RCTInstance 생성 (D-23)
2. **RCTInstance capture** — `SandboxReactNativeDelegate.hostDidStart:` 가 발화되면 `class_getInstanceVariable(host, "_instance")` reflection 으로 RCTInstance 추출, static 변수에 보관 (Android `loadBundle$ReactAndroid_debug` reflection 의 iOS 짝, D-24)
3. **page URL lookup** — `Bundle.main.url(forResource: "{moduleName}.bundle", withExtension: "js", subdirectory: "pages")` — Android `assets://pages/{appName}.bundle.js` 의 iOS 짝 (D-27, folder reference 필수)
4. **page bundle 평가** — `RCTInstance.callFunctionOnBufferedRuntimeExecutor:^(jsi::Runtime &rt){ rt.evaluateJavaScript(StringBuffer(source), url); }` — RN 0.74+ Bridgeless 의 표준 JS thread hop. callstack/react-native-sandbox 패턴 (D-22). RCTInstance 가 polling 안 잡히면 16ms × max 5s 가드
5. **surface mount** — `factory.rootViewFactory.view(withModuleName: appName, initialProperties: ...)` — page bundle 안 `AppRegistry.registerComponent({appName}, ...)` 가 이미 호출돼 있어야 동작. Android `ReactFragment.Builder().setComponentName` 의 iOS 짝
6. **warm path** — `RNContainerViewController.loadedPages: Set<String>` 가 동일 appName 재진입 시 evaluate skip → 즉시 mountSurface (D-26)

iOS 측 모든 단계가 ObjC++ (`PageBundleLoader.mm`) 에서 격리 처리되는 이유는 `RCTHost.h` 가 C++ STL 을 끌어와 Swift bridging header 가 못 받기 때문 (D-25). Swift 측은 `SandboxReactNativeDelegate` 라는 ObjC++ base class 만 import 받고 상속.

### Reflection 우회의 근거

RN 0.83 Bridgeless 는 multi-bundle 평가를 위한 public API 가 없음. `ReactHost` interface 의 public 메서드는 단일 번들 reload 만 노출 (`setBundleSource(filePath)`). 실제 multi-bundle 진입점인 `ReactHostImpl.loadBundle(JSBundleLoader)` 는 `internal` 가시성:

```kotlin
internal fun loadBundle(bundleLoader: JSBundleLoader): Task<Boolean>
```

JVM bytecode 에선 mangled name 으로 노출: `loadBundle$ReactAndroid_debug` (release 빌드는 `loadBundle$ReactAndroid_release`). 우리는 `declaredMethods.firstOrNull { it.name.startsWith("loadBundle") }` prefix match 로 빌드 variant 무관하게 찾는다.

표준 public API 가 나오면 reflection 제거. RN 0.84+ 또는 Toss Granite 의 [plugin-micro-frontend](https://github.com/toss/granite/blob/main/packages/plugin-micro-frontend/src/microFrontendPlugin.ts) 처럼 정식 진입점이 노출되는 게 이상적.

### 같은 appName 두 번 진입

현재는 매 진입마다 `loadBundle` 을 재호출. page bundle 이 다시 evaluate 되지만 `AppRegistry.registerComponent` 가 idempotent 라 무해. 다만 evaluate 비용이 든다 — TODO 항목 "Page bundle 캐싱" 으로 `loadedPages: Set<String>` 추가 예정.

---

## InitialProps

`MainActivity.buildInitialProps` 가 URI 정보를 `android.os.Bundle` 로 빚어 `ReactFragment.Builder().setLaunchOptions(bundle)` 에 넘긴다. JS 측 `AppRegistry.registerComponent` 의 component factory 의 첫 인자로 들어감.

| key | 값 | 비고 |
|---|---|---|
| `initialPath` | `uri.path` (없으면 `"/"`) | RN 측 Router 가 initial route 로 사용 |
| `platform` | `"android"` | |
| `appVersion` | `BuildConfig.VERSION_NAME` | |
| 그 외 query 키들 | `uri.getQueryParameter(k)` (모두 string) | URI query 가 평탄화되어 들어감 |

RESERVED_KEYS = {`initialPath`, `platform`, `appVersion`} — 사용자 query 가 같은 이름이면 무시 (`Log.w`).

예:

```
lifeplus-tribes://HelloRN/path/x?foo=hello&bar=42
  ↓
Bundle = {
  initialPath: "/path/x",
  platform: "android",
  appVersion: "1.0",
  foo: "hello",
  bar: "42",
}
```

JS 측 `useInitialProps()` 가 이걸 그대로 받음. 타입 정의는 [apps/native/src/router.tsx](https://github.com/lp-mktplatform/life/blob/main/apps/native/src/router.tsx) 의 `InitialProps`.

---

## 흔한 함정

| 증상 | 원인 | 조치 |
|---|---|---|
| logcat 에 `reactInstance is null. Dropping work.` | `MainActivity.loadPageBundle` 이 ReactInstance 준비 전 `loadBundle` 호출 | `addReactInstanceEventListener` + `currentReactContext` 가드가 살아있는지 확인 |
| logcat 에 `NoSuchMethodException: ReactHostImpl.loadBundle` | RN 업그레이드로 Kotlin `internal` mangled name 변경 (예: `loadBundle$ReactAndroid_debug` → 다른 suffix) | `declaredMethods.firstOrNull { it.name.startsWith("loadBundle") }` prefix match 가 살아있는지 확인. RN 0.84+ 에서 public API 가 나오면 reflection 제거 |
| `Unable to load script: pages/{X}.bundle.js` | sandbox 가 `assets/pages/{moduleName}.bundle.js` 를 못 찾음 | `apps/native` 의 `yarn deploy:android` 가 출력한 page 목록과 URI host 가 일치하는지 확인. 파일명은 moduleName (`HelloRN` 등) 이지 파일 경로 (`index`) 가 아님 |
| `Compiling JS failed: Invalid expression encountered` | shared bundle 이 metro-wrap 없이 평가됨 | apps/native 의 `deploy:android` 가 shared 만 `wrapAsMetroModule` 로 감싸 배치하는지 확인 |
| Metro IP 가 비워졌는데도 Metro 로 가려고 함 | 앱 재시작 안 한 것. `reactHost` 는 lazy 라 첫 평가에만 IP 읽음 | `force-stop` 후 재진입 |
| 에뮬레이터에서 `localhost` 입력 시 Metro 안 됨 | 에뮬레이터의 `localhost` 는 *에뮬레이터 자기 자신* | 호스트 머신은 `10.0.2.2`. 실기기는 `adb reverse tcp:8081 tcp:8081` 후 `localhost:8081` |
| JS 수정했는데 화면 그대로 | force-stop 안 하고 다시 띄움 → 기존 RN 인스턴스가 살아있어서 새 bundle 안 받음 | `adb shell am force-stop com.lifeplus.sandbox` 후 재진입 |
| 본앱(lifeplus tribes)이 같이 설치된 디바이스에서 disambiguator 다이얼로그가 뜸 | `lifeplus-tribes` 스킴이 두 앱에 동시 등록됨 | 의도된 동작 ([decisions.md](decisions.md) D-3). sandbox-poc 가 본앱 host shell 로 흡수되는 경로에서는 한 앱으로 통합될 예정 |
| (iOS) `xcodebuild build` 가 fmt `FMT_STRING` 매크로에서 5개 에러 | Apple clang 21 (Xcode 26) 의 strict consteval 이 fmt 11.0.2 의 매크로 거부 | Podfile post_install 의 `fmt/base.h` 패치가 자동 적용. `pod install` 출력에 `patched fmt/base.h: FMT_USE_CONSTEVAL forced 0 for Xcode 26` 로그 확인 (D-28) |
| (iOS) `Ineligible destination ... iOS 26.5 is not installed` | Xcode 26.5 가 default SDK 만 들고 옴, simulator runtime 별개 | `xcodebuild -downloadPlatform iOS` 로 iOS 26.5 simulator runtime 추가 다운로드 (~8.5GB) |
| (iOS) `No script URL provided` redbox | `shared.bundle.js` 가 `.app` 안에 없음. AppDelegate.bundleURL 의 1번 분기 (`Bundle.main.url(forResource: "shared.bundle", ...)`) 가 nil → DEBUG 빌드는 Metro 로 fallback 시도, Metro 도 없으면 redbox | `ios/SandboxApp/shared.bundle.js` 배치 + Xcode 가 인식하도록 folder reference 추가. `apps/native deploy:ios` 자동화 전까진 수동 |
| (iOS) `RCTInstance not captured within timeout` | `SandboxReactNativeDelegate.hostDidStart:` 가 발화 안 됨. RCTHost.start 가 트리거 안 됐거나 base class 가 `RCTDefaultReactNativeFactoryDelegate` 가 아님 | AppDelegate 의 prewarm `factory.rootViewFactory.view(withModuleName: "__prewarm", ...)` 호출이 살아있는지 확인 (D-23). Swift `ReactNativeDelegate` 가 `SandboxReactNativeDelegate` 를 상속하는지 확인 (D-25) |
| (iOS) `PageBundleLoader ❌ RCTHost has no _instance ivar` | RN 업그레이드로 `_instance` ivar 명이 바뀜 | RN 0.84+ 에서 public API 가 나왔는지 확인. 임시 우회는 `RCTHostImpl.h` 안의 ivar 이름 갱신 (D-24) |
| (iOS) log show 결과가 `<compose failure [shared UUID]>` 로 가려짐 | macOS 26 의 `os_log` private-data 기본 차단 — NSLog format 변수가 private 마킹 | `xcrun simctl launch --console booted com.lifeplus.sandbox` 로 stdout 직접 캡처. 또는 `log config --enable-private-data` |
| (iOS 17) `simctl openurl` 시 "Sandbox에서 열겠습니까?" 다이얼로그 | iOS 17 의 보안 — 새 launch session 으로 진입할 때 사용자 동의. iOS 26 에선 없음 | 같은 process 가 살아있는 상태에서 openurl 호출 (`launch --console &` 백그라운드로 띄우고 sleep 후 openurl). 즉 same-app self-invocation 패턴이면 다이얼로그 회피 |

---

## 좌표

### Android
- **부팅 호스트**: [SandboxApplication.kt](android/app/src/main/java/com/lifeplus/sandbox/SandboxApplication.kt)
- **URI 파싱 + Multi-bundle 로더**: [MainActivity.kt](android/app/src/main/java/com/lifeplus/sandbox/MainActivity.kt) (`handleIntent` / `loadPageBundle` / `invokeLoadBundle` / `pollTaskCompletion`)
- **DevTool UI**: [DevToolFragment.kt](android/app/src/main/java/com/lifeplus/sandbox/DevToolFragment.kt) + [fragment_devtool.xml](android/app/src/main/res/layout/fragment_devtool.xml)
- **URI 스킴 등록**: [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) (`<data android:scheme="lifeplus-tribes" />`)

### iOS
- **부팅 호스트 + URI 파싱**: [AppDelegate.swift](ios/SandboxApp/AppDelegate.swift) (`application(_:didFinishLaunchingWithOptions:)` 가 RCTInstance prewarm + DevTool 마운트, `application(_:open:options:)` 가 URI 진입)
- **Multi-bundle 평가**: [PageBundleLoader.h](ios/SandboxApp/PageBundleLoader.h) + [PageBundleLoader.mm](ios/SandboxApp/PageBundleLoader.mm) (`captureRCTInstanceFromHost:` / `evaluatePageBundleAtURL:completion:`)
- **RN surface mount + page 캐싱**: [RNContainerViewController.swift](ios/SandboxApp/RNContainerViewController.swift) (`loadedPages` / `pageBundleURL(for:)` / `mountSurface`)
- **DevTool UI**: [DevToolViewController.swift](ios/SandboxApp/DevToolViewController.swift)
- **URI 스킴 등록**: [Info.plist](ios/SandboxApp/Info.plist) (`CFBundleURLTypes`)
- **Podfile 워크어라운드**: [Podfile](ios/Podfile) (`SWIFT_ENABLE_EXPLICIT_MODULES=NO` + `fmt/base.h FMT_USE_CONSTEVAL` 패치, D-28)

### 공통
- **미니앱 번들 소스**: life 모노레포 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) (별도 레포)
- **결정 회고**: [decisions.md](decisions.md)

---

## 의도적으로 안 한 것

| 항목 | 이유 |
|---|---|
| Fast Refresh / dev menu / redbox UI | sandbox-poc 는 Native Shell 컨테이너. RN 개발 환경(Metro) 은 별도로 가짐 |
| 자체 RN 컴포넌트 (`App.tsx` 등) | apps/native 가 미니앱 소스의 단일 진실의 원천. 본 레포에는 RN 코드 없음 |
| `RNContainerFragment` 같은 자체 Fragment | RN 0.83 의 공식 `ReactFragment.Builder` 가 lifecycle/surface 를 자동 처리. 자체 Fragment 구현은 시도했다가 흰 화면 → 폐기 ([decisions.md](decisions.md) 회고 RN 0.83 2번) |
| 푸시 / 권한 / 기존 SDK 통합 | Phase 3 |
| 이전 — iOS multi-bundle | 2026-05-15 완성 (PageBundleLoader.mm, D-22) |
