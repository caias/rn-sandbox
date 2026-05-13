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

### MVP (2026-05-11 완료)

| DoD | Android | iOS |
|---|---|---|
| DoD-1 빌드 성공 | ✅ | ⏸ ios-wip/ |
| DoD-2 DevTool UI 스킴 입력 | ✅ | ⏸ |
| DoD-3 스킴 파싱 로그 | ✅ | ⏸ |
| DoD-4 정적 번들로 RN 부팅 | ✅ | ⏸ |

### Phase 1 — Multi-bundle host shell (2026-05-13 완료, Android)

| 항목 | 상태 | 비고 |
|---|---|---|
| InitialProps query params 평탄화 | ✅ | `MainActivity.handleIntent` 가 `uri.queryParameterNames` 를 모두 `putString`. RESERVED_KEYS 가드. |
| Multi-bundle 평가 | ✅ | `MainActivity.loadPageBundle` 가 `JSBundleLoader.createAssetLoader` + `ReactHostImpl.loadBundle` (reflection) |
| ReactInstance ready 대기 | ✅ | `addReactInstanceEventListener` + `currentReactContext` 가드 |
| URI 스킴 통일 | ✅ | `lifeplus-sandbox` → `lifeplus-tribes` (모노레포 공통) |
| iOS multi-bundle | ⏸ | ios-wip/ 마무리 + multi-bundle 적용 별도 작업 |

### 다음 단계 (Phase 2)

1. **NavBridge NativeModule** — JS → Native pop/replace. 현재는 `BackHandler.exitApp()` 으로 임시
2. **Page bundle 캐싱** — 같은 appName 재진입 시 `loadBundle` 재호출 회피
3. **CDN URL fetch** — page bundle 을 원격 URL 에서 fetch + 캐시. 미니앱 추가/수정 시 APK 재배포 불필요
4. **iOS multi-bundle** — `ios-wip/` 마무리 후
5. **`ReactHostImpl.loadBundle` 의 public API 교체** — RN 0.84+ 에서 노출되면 reflection 제거

---

## 레포 구조

```
sandbox-poc/
  ios-wip/                       ← iOS 보류. 본작업 시 ios/ 로 이름 변경 후 Xcode에서 마무리
    SandboxApp/
      AppDelegate.swift
      RNContainerViewController.swift
      DevToolViewController.swift
      Info.plist                  (← URL scheme 추가 필요)
    SandboxApp.xcodeproj          (← pbxproj 정합성 작업 필요)
  android/
    app/
      src/main/
        java/com/lifeplus/sandbox/
          SandboxApplication.kt   ← jsBundleFilePath="assets://shared.bundle.js"
          MainActivity.kt         ← URI host → loadPageBundle → ReactFragment commit
          DevToolFragment.kt      ← Metro IP 입력 + 정적/Metro 모드 토글
          RNContainerFragment.kt  ← (DEPRECATED) RN 0.83 ReactFragment 로 대체. 잔존 파일
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
  HelloRN/                        ← MVP 시절 RN scratch. multi-bundle 도입 후로는 미사용 (gitignored)
  decisions.md
  README.md
```

`assets/` 내용은 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) 의 `yarn deploy:android` 가 채움. 본 레포에선 *받는 쪽 계약*만 정의.

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

### iOS (보류)

`ios-wip/` 에 작성된 Swift + 정적 번들이 있지만 pbxproj 정합성 작업이 미완. Xcode GUI 또는 `xcodeproj` Ruby gem 으로 별도 수행 필요. 자세한 건 [decisions.md](decisions.md) 회고 1번.

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

`MainActivity.loadPageBundle` 가 핵심. 호출 흐름:

1. **`ReactInstance` 가 살아있는지 확인** — `reactHost.currentReactContext != null`
   - 살아있으면 즉시 `invokeLoadBundle` 호출 (warm path, 두번째 진입부터)
   - 없으면 `addReactInstanceEventListener` 등록 후 `host.start()` → 초기 shared 평가 끝나면 listener 콜백 (cold path, 첫 진입)
2. **`JSBundleLoader.createAssetLoader(context, "assets://pages/{appName}.bundle.js", false)`** — public API
3. **`ReactHostImpl.loadBundle$ReactAndroid_debug(loader)`** — reflection 으로 호출. Kotlin `internal` 가시성을 JVM mangled name prefix match 로 우회
4. **Bolts `Task<Boolean>` 폴링** — `isCompleted` / `isFaulted` / `getResult` / `getError` 를 16ms 단위로 체크 (page bundle 평가 끝나는 시점 감지)
5. **성공 시** — 그 안의 `AppRegistry.registerComponent({appName}, ...)` 가 이미 호출됨 → `ReactFragment.Builder().setComponentName(appName)` 로 surface mount

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

---

## 좌표

- **부팅 호스트**: [SandboxApplication.kt](android/app/src/main/java/com/lifeplus/sandbox/SandboxApplication.kt)
- **URI 파싱 + Multi-bundle 로더**: [MainActivity.kt](android/app/src/main/java/com/lifeplus/sandbox/MainActivity.kt) (`handleIntent` / `loadPageBundle` / `invokeLoadBundle` / `pollTaskCompletion`)
- **DevTool UI**: [DevToolFragment.kt](android/app/src/main/java/com/lifeplus/sandbox/DevToolFragment.kt) + [fragment_devtool.xml](android/app/src/main/res/layout/fragment_devtool.xml)
- **URI 스킴 등록**: [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) (`<data android:scheme="lifeplus-tribes" />`)
- **미니앱 번들 소스**: life 모노레포 [apps/native](https://github.com/lp-mktplatform/life/tree/main/apps/native) (별도 레포)
- **결정 회고**: [decisions.md](decisions.md)

---

## 의도적으로 안 한 것

| 항목 | 이유 |
|---|---|
| Fast Refresh / dev menu / redbox UI | sandbox-poc 는 Native Shell 컨테이너. RN 개발 환경(Metro) 은 별도로 가짐 |
| 자체 RN 컴포넌트 (`HelloRN/App.tsx` 등) | apps/native 가 미니앱 소스의 단일 진실의 원천. 본 레포에는 RN 코드 없음 |
| `RNContainerFragment` 같은 자체 Fragment | RN 0.83 의 공식 `ReactFragment.Builder` 가 lifecycle/surface 를 자동 처리. 잔존 파일은 제거 예정 |
| 푸시 / 권한 / 기존 SDK 통합 | Phase 3 |
| iOS multi-bundle | ios-wip/ 마무리 후 별도 작업 |
