# sandbox-poc — RN Multi-Bundle Native Host Shell

> **본 README 는 본앱 개발자(lp-mktplatform-ios / lp-mktplatform-android) 입장 입문 가이드.**
> 결정 과정 / 회고 / 히스토리는 Obsidian `Epic-RN-metro/01-history/` 참조.
> 본앱 통합 시작 입력 명세는 Obsidian `Epic-RN-metro/03-host-integration/host-integration-spec.md`.

life 모노레포의 `apps/native` 가 만드는 미니앱 번들을 CDN 에서 동적으로 fetch 해 띄우는 Native Host Shell **참조 구현**.
본 앱 (lp-mktplatform-ios / lp-mktplatform-android) 이 같은 패턴으로 구현해야 미니앱이 동작한다.

---

## 빠른 시작 (clone 직후)

### Android

1. emulator 부팅 (KT 사내 DNS 회피 — CDN fetch 필수):
   ```bash
   $HOME/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_36.1 -dns-server 8.8.8.8,1.1.1.1
   ```

2. APK 빌드 + 설치:
   ```bash
   cd android && ./gradlew :app:assembleDebug
   adb install -r app/build/outputs/apk/debug/app-debug.apk
   ```

3. URI 진입 (3가지 케이스):
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-tribes://promotion?foo=hello"
   adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-tribes://event"
   adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-tribes://event/detail"
   ```

4. logcat 확인:
   ```bash
   adb logcat | grep -E "sandbox-poc|ReactNativeJS"
   ```
   기대 결과: `Running "promotion"` / `Running "event"` 출력 + `✅ fetched from CDN: ...` 로그

### iOS

1. 시뮬레이터 GUI 활성 (필수 — headless 부팅 직후엔 SIGABRT 가능):
   ```bash
   open -a Simulator
   xcrun simctl boot 79CFCF4C-BF4E-407B-8C1E-D0739B809838  # iPhone 17 / iOS 26.5
   ```

2. CocoaPods + 빌드 + 설치:
   ```bash
   cd ios && bundle install && bundle exec pod install
   xcodebuild -workspace SandboxApp.xcworkspace -scheme SandboxApp \
     -configuration Debug -sdk iphonesimulator build
   xcrun simctl install booted "<path-to>/SandboxApp.app"
   ```

3. URI 진입:
   ```bash
   xcrun simctl openurl booted 'lifeplus-tribes://promotion?foo=hello'
   xcrun simctl openurl booted 'lifeplus-tribes://event/detail'
   ```

4. 로그 확인:
   ```bash
   xcrun simctl spawn booted log stream --level=info \
     --predicate 'processImagePath contains "SandboxApp"' --style compact
   ```

자세한 빌드 디테일: [aos.md](aos.md) / [ios.md](ios.md)

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
       (RN polyfill + InitializeCore +              └ CDN fetch 시도
        globalThis.__SHARED__ 채움)                    {CDNBaseURL}/{platform}/pages/{appName}.bundle.js
                                                    └ 실패 시 local fallback
                                                       assets://pages/{appName}.bundle.js
                                                    └ ReactHostImpl.loadBundle (reflection)
                                                       ↓
                                                    AppRegistry.registerComponent(appName)
                                                       ↓
                                                    ReactFragment.Builder()
                                                       .setComponentName(appName)
                                                       .setLaunchOptions(initialProps)
                                                    → surface mount
```

미니앱 번들 생성 + CDN 업로드는 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) 측 책임 (`yarn deploy:cdn:android` / `yarn deploy:cdn:ios`). 본 레포는 *받는 쪽*.

---

## 의존성 명세

### RN / React 버전

- **React Native 0.83.2** (New Architecture only, Bridgeless / Fabric / Hermes ON)
- **React 19.2.1** (life 모노레포 React 19 통일)

### ⚠️ @lifeplus/native-bridge — 특정 브랜치 핀 사용

`@lifeplus/native-bridge` 는 JSON Schema 단일 소스 + TypeScript SDK + Swift / Kotlin 타입을 quicktype 으로 자동 생성하는 **NativeModule 인터페이스 명세 패키지**. 레포 자체가 명세이므로 본앱 통합 테스트 시점에는 다음 브랜치를 핀해야 한다:

```json
"@lifeplus/native-bridge": "git+https://github.com/lp-mktplatform/lp-mktplatform-native-bridge.git#feature/native-bridge"
```

| 단계 | 사용할 ref |
|---|---|
| 현재 (Phase 4 완료 / 본앱 통합 전) | `feature/native-bridge` 브랜치 핀 |
| `main` 머지 후 | 기존 패턴 그대로 `main` 의 최신 커밋 기준 |

본앱 PR 시 `package.json` / `Podfile.lock` / `gradle` 에 위 브랜치 또는 태그가 박혀 있는지 검증 필수.

sandbox 의 `LifePlusApp.{h,mm}` / `LifePlusAppModule.kt` 는 **sandbox 단독 시나리오용 reference 구현** (D-33 A안). 본 앱 통합 시점엔 본앱이 자기 navigator (iOS: SwiftUI `NavigationPath` / Android: Compose `Navigation3.backStack`) 와 묶인 새 NativeModule 구현체로 대체한다. **JS SDK 변경 0**.

---

## 핵심 약속 (변경 시 양쪽 동시 수정)

| 항목 | 값 | sandbox 위치 | 본앱이 가져가야 할 위치 |
|---|---|---|---|
| URI 스킴 | `lifeplus-tribes` | `AndroidManifest.xml`, `Info.plist` `CFBundleURLTypes` | 본앱 manifest / Info.plist |
| 부팅 번들 | `shared.bundle.js` (`apps/native yarn deploy:*` 산출물) | `assets/`, `ios/SandboxApp/` | 본앱 빌드 산출물 |
| 미니앱 번들 (CDN, 정식) | `{LifePlusCDNBaseURL}/{platform}/pages/{appName}.bundle.js` — **현재는 테스트용 임시 URL, 향후 환경별(develop/qa/prod)로 분리 예정** | `Info.plist::LifePlusCDNBaseURL`, `AndroidManifest <meta-data android:name="LifePlusCDNBaseURL">` | 본앱 manifest / Info.plist (환경별 빌드 config 로 주입) |
| 미니앱 번들 (local fallback) | `assets://pages/{appName}.bundle.js` / iOS `pages/{appName}.bundle.js` | `assets/pages/`, `ios/SandboxApp/pages/` | 본앱 빌드 산출물 |
| moduleName | URI host = `AppRegistry.registerComponent` 첫 인자 | `MainActivity::handleIntent` / `AppDelegate::handle(url:)` | 본앱 URI 파서 |
| InitialProps | `initialPath`, `platform`, `appVersion` + URI query 평탄화 (RESERVED_KEYS 가드) | `buildInitialProps` 양쪽 | 본앱 RN Container VC / Activity |
| `@lifeplus/native-bridge` 핀 | `feature/native-bridge` 브랜치 (현재) | `package.json` | 본앱 `package.json` |

---

## CDN URL — 현재 상태와 향후 계획

> ⚠️ **현재 `LifePlusCDNBaseURL` 은 테스트 검증용 임시 URL** 이다. 단일 URL 로 고정돼 있으며 환경 분리가 없다.

본앱 통합 시점에는 **환경별 URL 로 분리**되어야 한다:

| 환경 | 예시 |
|---|---|
| develop | `https://cdn-dev.lifeplus.co.kr` |
| qa | `https://cdn-qa.lifeplus.co.kr` |
| prod | `https://cdn.lifeplus.co.kr` |

주입 방식은 본앱의 기존 빌드 환경 config 패턴을 따른다 (Android: `BuildConfig` / `manifestPlaceholders`, iOS: `xcconfig` / `Info.plist` 환경별 값).
`apps/native` 측 `yarn deploy:cdn:{platform}` 업로드 대상 버킷도 환경별로 맞춰져야 한다.

---

## InitialProps

URI 정보 + 본앱 세션 정보를 `android.os.Bundle` (Android) / `NSDictionary` (iOS) 로 빚어 RN surface 의 launch options 로 넘긴다.

| key | 값 | 비고 |
|---|---|---|
| `initialPath` | `uri.path` (없으면 `"/"`) | RN 측 Router 가 initial route 로 사용 |
| `platform` | `"android"` / `"ios"` | |
| `appVersion` | `BuildConfig.VERSION_NAME` / `CFBundleShortVersionString` | |
| `accessToken` | 본앱이 보유한 로그인 세션 토큰 | 미니앱 측 API 호출 시 Authorization 헤더 구성 |
| `userId` | 본앱 로그인 사용자 식별자 | 미니앱 측 사용자 컨텍스트 / 로깅 |
| 그 외 query 키들 | `uri.getQueryParameter(k)` (모두 string) | URI query 평탄화. RESERVED_KEYS 충돌 시 무시 |

> ⚠️ `accessToken` / `userId` 는 **예시일 뿐 확정 스키마가 아니다.** 본앱 통합 시점에 필요한 세션 정보(예: `tenantId`, `deviceId`, `locale`, `theme`, `ageVerified` 등)를 자유롭게 추가할 수 있다. 추가 시 양쪽 native (`buildInitialProps`) 와 미니앱 측 `InitialProps` 타입 ([apps/native/src/router.tsx](https://github.com/lp-mktplatform/life/blob/main/apps/native/src/router.tsx)) 을 동시 수정해야 한다.

RESERVED_KEYS = {`initialPath`, `platform`, `appVersion`, `accessToken`, `userId`} (확장 시 같이 추가)

예:
```
lifeplus-tribes://HelloRN/path/x?foo=hello&bar=42
  ↓
{
  initialPath: "/path/x",
  platform: "android",
  appVersion: "1.0",
  accessToken: "eyJhbGciOi...",
  userId: "u-12345",
  foo: "hello",
  bar: "42"
}
```

JS 측 `useInitialProps()` 가 이걸 그대로 받음. 타입 정의는 [apps/native/src/router.tsx](https://github.com/lp-mktplatform/life/blob/main/apps/native/src/router.tsx) 의 `InitialProps`.

---

## 동작 모드

`SandboxApplication.useMetro` 가 `metroIp` SharedPreferences 의 비어있지 않음 여부로 분기.

| 모드 | 트리거 | 부팅 번들 | 미니앱 번들 | 용도 |
|---|---|---|---|---|
| **CDN + local fallback (정식)** | `metroIp` 비어있음 | `assets://shared.bundle.js` | CDN fetch 우선 → 실패 시 `assets://pages/{moduleName}.bundle.js` | 본 배포 흐름. `LifePlusCDNBaseURL` 미설정 시 자동으로 local fallback 전용 |
| **Mono 회귀 (선택)** | `metroIp` 비어있음 + `main.jsbundle` 사용 | `assets://main.jsbundle` (shared+pages concat) | 단일 번들 | 빌드 파이프라인 회귀 검증용 |
| **Metro (개발)** | `metroIp` 입력됨 | Metro 서버에서 fetch (`http://{ip}/index.bundle`) | 단일 번들 | RN 개발 hot reload |

---

## 레포 구조

```
sandbox-poc/
  ios/
    SandboxApp/
      AppDelegate.swift             ← @main, ReactNativeDelegate, URI 라우팅
      DevToolViewController.swift   ← URI 입력 + 최근 실행 목록
      RNContainerViewController.swift ← URI 진입 시 CDN fetch → page bundle 평가 → RN surface mount
      PageBundleLoader.h/.mm        ← ObjC++ multi-bundle 평가 (RCTInstance reflection + jsi::Runtime)
      SandboxApp-Bridging-Header.h  ← Swift ↔ ObjC++ 브릿지
      LifePlusApp.h/.mm             ← NativeModule sandbox reference 구현 (back/share)
      Info.plist                    ← CFBundleURLTypes (lifeplus-tribes), LifePlusCDNBaseURL (임시 URL)
      shared.bundle.js              ← apps/native `yarn deploy:ios` 산출물 (부팅 전용)
      pages/                        ← local fallback 번들 (Xcode folder reference, 파란 아이콘)
        promotion.bundle.js
        event.bundle.js
    SandboxApp.xcodeproj            ← Swift/ObjC++ 등록은 add_swift_sources.rb 멱등 스크립트
    SandboxApp.xcworkspace          ← CocoaPods 통합 진입점 (`xed -b .`)
    Podfile                         ← post_install 워크어라운드 (D-28)
    add_swift_sources.rb            ← pbxproj 에 새 source 파일 멱등 등록
  android/
    app/src/main/
      java/com/lifeplus/sandbox/
        SandboxApplication.kt       ← jsBundleFilePath="assets://shared.bundle.js"
        MainActivity.kt             ← URI host → CDN fetch → loadPageBundle → ReactFragment commit
        DevToolFragment.kt          ← Metro IP 입력 + 정적/Metro 모드 토글
        LifePlusAppModule.kt        ← NativeModule sandbox reference 구현 (back/share)
        LifePlusAppPackage.kt
      assets/
        shared.bundle.js            ← apps/native deploy:android 산출물 (부팅 전용)
        pages/                      ← local fallback 번들
          promotion.bundle.js
          event.bundle.js
      AndroidManifest.xml           ← lifeplus-tribes scheme + LifePlusCDNBaseURL meta-data (임시 URL)
  package.json                      ← RN 0.83.2 + @lifeplus/native-bridge 핀
  decisions.md
  README.md
```

본 레포는 자체 RN 소스(`App.tsx` / `index.js` 등)는 없다. `node_modules` 가 필요한 이유는 **Android Gradle 이 RN Gradle Plugin + `react-android` AAR + Hermes AAR 을 npm 패키지에서 해소**하기 때문 (decisions.md D-19).

---

## 흔한 함정

본앱 개발자가 받자마자 부닥칠 패턴:

| 증상 | 원인 | 조치 |
|---|---|---|
| (Android emulator) `UnknownHostException` / `Unable to resolve host` | emulator 가 KT 사내 DNS (`168.126.63.1`) 사용 → CloudFront 도메인 resolution 실패 | `emulator -avd ... -dns-server 8.8.8.8,1.1.1.1` 로 재부팅 |
| (Android) 부팅 직후 `adb: device offline` | adb daemon 갱신 안 됨 | `adb kill-server && adb start-server` |
| (iOS 시뮬) headless 부팅 직후 `SIGABRT / Abort trap: 6` | iOS 26.x 시뮬레이터 CoreText/UIKit race | `xcrun simctl shutdown && boot && open -a Simulator` 로 GUI 활성 |
| `NativeModules.LifePlusApp not registered` | `@lifeplus/native-bridge` 브랜치 핀 누락 또는 native 구현 미등록 | `package.json` 의 `feature/native-bridge` ref 확인. Android: `SandboxApplication.reactHost` packageList 에 `LifePlusAppPackage()` 추가. iOS: `add_swift_sources.rb` 에 `LifePlusApp.h/.mm` 포함 확인 |
| `TurboModule method "X" called with 1 arguments (expected argument count: 0)` | `sdk-native.ts` 가 void 커맨드도 항상 1-arg invoke. native 시그니처가 0-arg 면 FATAL | Android: `@ReactMethod fun X(params: ReadableMap?, promise: Promise)`. iOS: `RCT_REMAP_METHOD(X, XWithParams:(NSDictionary*)params resolver:... rejecter:...)`. (D-30) |
| (iOS) CocoaPods install 중 `FMT_USE_CONSTEVAL` 컴파일 에러 | Xcode 26 + fmt 11.0.2 strict consteval 충돌 (D-28) | `Podfile` 의 `post_install` 패치 적용 확인 후 `pod install` 재실행 |

카테고리별 상세 트러블슈팅: Obsidian `Epic-RN-metro/02-current-state/troubleshooting.md`

---

## 의도적으로 안 한 것

| 항목 | 이유 |
|---|---|
| Fast Refresh / dev menu / redbox UI | sandbox-poc 는 Native Shell 컨테이너. RN 개발 환경(Metro)은 별도로 가짐 |
| 자체 RN 컴포넌트 (`App.tsx` 등) | `apps/native` 가 미니앱 소스의 단일 진실의 원천. 본 레포에는 RN 코드 없음 |
| `RNContainerFragment` 같은 자체 Fragment | RN 0.83 의 공식 `ReactFragment.Builder` 가 lifecycle/surface 를 자동 처리. 자체 Fragment 는 흰 화면 → 폐기 (decisions.md D-7 회고) |
| 푸시 / 권한 / 기존 SDK 통합 | 본앱 통합 시점에 처리 |

---

## 빌드 가이드 (디테일)

- Android: [aos.md](aos.md)
- iOS: [ios.md](ios.md)
- 결정 카드 (D-1 ~ D-33): [decisions.md](decisions.md)
- 본앱 통합 시작 입력: Obsidian `Epic-RN-metro/03-host-integration/host-integration-spec.md`
