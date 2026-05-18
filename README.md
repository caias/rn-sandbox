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

| Phase | Android | iOS | verify |
|---|---|---|---|
| **MVP** — URI 스킴 수신 + 정적 번들 부팅 | ✅ | ✅ | 2026-05-15 |
| **Phase 1** — Multi-bundle host shell | ✅ | — | 2026-05-13 (Android) |
| **Phase 1.5** — iOS 라인 정상화 (ios-wip → ios 전환) | — | ✅ | 2026-05-14 |
| **Phase 2-1** — iOS multi-bundle host shell | — | ✅ | 2026-05-15 |

세부 항목 및 결정 근거는 [decisions.md](decisions.md) 와 [ios.md](ios.md) / [aos.md](aos.md) 참고.

---

## 다음 단계 (Phase 2-2 이후)

1. **NavBar UI 정리** — iOS NavController 의 NavBar 와 RN 페이지 색 충돌. 본 앱 host shell 통합 시점에 처리
2. **CDN URL fetch** — page bundle 을 원격 URL 에서 fetch + 캐시. 미니앱 추가/수정 시 APK/IPA 재배포 불필요
3. **`ReactHostImpl.loadBundle` (Android D-14) + `RCTHost._instance` (iOS D-22/D-24) reflection 제거** — RN 0.84+ 에서 public API 가 나오면 동시에 제거 가능
4. **본 iOS 레포 (lp-mktplatform-ios) `develop-cd.yml` Xcode 버전 align** — 2026-05-15 조사 완료 ([decisions.md](decisions.md)). 현재 `XC_VERSION='14.2'` + `macos-12` runner 가 RN 0.83 호환 불가 + App Store 제출 (Xcode 26 의무) 불가 → CD workflow 를 `Xcode 26.5 + macos-26` 로 점프 필요. sandbox 측 작업 아니라 본 레포 PR

### 완료된 항목

- ~~**`apps/native` 의 `yarn deploy:ios`**~~ — life monorepo `apps/native/scripts/deploy-ios.ts` 로 구현됨 (Android `deploy:android` 의 짝). `yarn deploy:ios [SANDBOX_PATH]`
- ~~**본 iOS 레포 Xcode 버전 핀 조회**~~ — 2026-05-15. `mise.toml` 에 Xcode 핀 없음, `develop-ci.yml` 은 `macos-latest` 소프트 가드, `develop-cd.yml:43` 의 `XC_VERSION='14.2'` 가 P0 통합 이슈로 식별. 후속은 본 레포 CD workflow PR (위 #4)
- ~~**NavBridge NativeModule (sandbox reference 구현)**~~ — 2026-05-18. `@lifeplus/native-bridge` 의존성 + `back` / `share` 두 커맨드를 iOS (`LifePlusApp.{h,mm}`) / Android (`LifePlusAppModule.kt` + `LifePlusAppPackage.kt`) 양쪽에 구현 + verify 완료 (decisions.md D-29~D-33). **본 앱 host shell 통합 시점엔 본앱이 자기 navigator 와 묶인 새 NativeModule 구현체로 대체** (D-33 — A안: JS SDK 통일 + 구현체 호스트별)

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
      shared.bundle.js            ← apps/native `yarn deploy:ios` 산출물
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

## 빌드 가이드

Android 개발자는 [aos.md](aos.md) 를, iOS 개발자는 [ios.md](ios.md) 를 보세요. 양쪽 공통 RN 사상은 아래 섹션에서 다룹니다.

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

---

## InitialProps

URI 정보를 `android.os.Bundle` (Android) / `NSDictionary` (iOS) 로 빚어 RN surface 의 launch options 로 넘긴다. JS 측 `AppRegistry.registerComponent` 의 component factory 첫 인자로 들어감.

| key | 값 | 비고 |
|---|---|---|
| `initialPath` | `uri.path` (없으면 `"/"`) | RN 측 Router 가 initial route 로 사용 |
| `platform` | `"android"` / `"ios"` | |
| `appVersion` | `BuildConfig.VERSION_NAME` / `CFBundleShortVersionString` | |
| 그 외 query 키들 | `uri.getQueryParameter(k)` (모두 string) | URI query 가 평탄화되어 들어감 |

RESERVED_KEYS = {`initialPath`, `platform`, `appVersion`} — 사용자 query 가 같은 이름이면 무시 (`Log.w` / `NSLog`).

예:

```
lifeplus-tribes://HelloRN/path/x?foo=hello&bar=42
  ↓
{ initialPath: "/path/x", platform: "android", appVersion: "1.0", foo: "hello", bar: "42" }
```

JS 측 `useInitialProps()` 가 이걸 그대로 받음. 타입 정의는 [apps/native/src/router.tsx](https://github.com/lp-mktplatform/life/blob/main/apps/native/src/router.tsx) 의 `InitialProps`. 플랫폼별 `buildInitialProps` 구현은 [aos.md](aos.md) / [ios.md](ios.md) 참고.

---

## 의도적으로 안 한 것

| 항목 | 이유 |
|---|---|
| Fast Refresh / dev menu / redbox UI | sandbox-poc 는 Native Shell 컨테이너. RN 개발 환경(Metro) 은 별도로 가짐 |
| 자체 RN 컴포넌트 (`App.tsx` 등) | apps/native 가 미니앱 소스의 단일 진실의 원천. 본 레포에는 RN 코드 없음 |
| `RNContainerFragment` 같은 자체 Fragment | RN 0.83 의 공식 `ReactFragment.Builder` 가 lifecycle/surface 를 자동 처리. 자체 Fragment 구현은 시도했다가 흰 화면 → 폐기 ([decisions.md](decisions.md) 회고 RN 0.83 2번) |
| 푸시 / 권한 / 기존 SDK 통합 | Phase 3 |

---

결정 카드 및 회고 전문: [decisions.md](decisions.md)
