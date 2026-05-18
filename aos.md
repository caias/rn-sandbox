# sandbox-poc — Android 개발자 가이드

> **한 줄 정체성**: life 모노레포 `apps/native` 가 빌드한 미니앱 번들을 동적으로 띄우는 Android Native Host Shell.

빠른 시작 (머신에 Android 환경이 이미 갖춰진 경우):

```bash
# 1) page bundle 이 이미 sandbox 레포에 커밋돼 있는지 확인
ls android/app/src/main/assets/shared.bundle.js android/app/src/main/assets/pages/
# 세 파일(shared.bundle.js + pages/ 디렉토리 + 그 안의 bundle 파일)이 보이면 그대로 빌드 가능.
# 없으면 아래 "부록: RN 개발자가 page bundle 을 갱신하는 경우" 섹션 참조.

# 2) sandbox APK 빌드 + 설치 + 진입
cd path/to/sandbox/android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am force-stop com.lifeplus.sandbox
adb shell am start -W -a android.intent.action.VIEW \
  -d "lifeplus-tribes://HelloRN?foo=hello&bar=42"
# -W: wait until launch completes (실패 시 stack trace 출력)
# logcat: I sandbox-poc: RN mode: static multi-bundle (shared + pages/*)
#         I sandbox-poc: loading page bundle: assets://pages/HelloRN.bundle.js
#         I ReactNativeJS: Running "HelloRN"
```

---

## 사전 요구 매트릭스

| 항목 | 최소 버전 | 비고 |
|---|---|---|
| **Android Studio** | — | *선택*. `./gradlew assembleDebug` + `adb` 만으로 빌드/설치 가능. IDE 통합 필요 시 Ladybug (2024.2.1)+ 권장 |
| **JDK** | **17** | Gradle 8.x + AGP 8.x 요구. Android Studio 번들 JDK 사용 권장 |
| **Android SDK** | API **34** (compileSdk 36) | SDK Manager 에서 "Android 14.0 (API 34)" + "Android SDK Build-Tools 36" 설치 |
| **minSdk** | **24** (Android 7.0) | RN 0.74+ 권장값. 기기/에뮬레이터가 API 24 이상이어야 실행 가능 |
| **compileSdk** | **36** | `android/build.gradle` ext 블록 설정값 |
| **NDK** | `rootProject.ext.ndkVersion` | AGP 가 자동 매칭. 별도 버전 지정 불필요 |
| **Node.js** | 18+ | apps/native `yarn deploy:android` 실행 시 필요. 디바이스 런타임엔 불필요 |

---

## 첫 세팅 (한 번만)

### Android Studio 설치

[developer.android.com/studio](https://developer.android.com/studio) 에서 최신 stable 다운로드 + 설치.
설치 마법사가 SDK, 에뮬레이터, Build-Tools 를 자동으로 구성한다.

### ANDROID_HOME 환경변수

`~/.zshrc` (또는 `~/.bashrc`) 에 추가:

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

이후 `source ~/.zshrc` 로 적용. 확인:

```bash
adb --version
# Android Debug Bridge version 1.0.41
```

### SDK 구성 확인

Android Studio → SDK Manager (또는 `sdkmanager --list`) 로 아래 항목이 설치됐는지 확인:

| 패키지 | 용도 |
|---|---|
| Android SDK Platform 34 | compileSdk 소스 |
| Android SDK Build-Tools 36.x | aapt, dx, zipalign |
| Android Emulator | 에뮬레이터 실행 |
| Android SDK Platform-Tools | adb |
| NDK (Side by side) | Hermes SO 빌드 |

### JDK 확인

```bash
java -version
# openjdk version "17.x.x" 2023-xx-xx
```

Android Studio 를 사용한다면 `File > Settings > Build > Gradle > Gradle JDK` 에서 "Android Studio default JDK" 선택.

### node_modules 설치

sandbox 루트의 `package.json` 이 gradle 빌드에 필요한 RN Gradle Plugin + AAR 해소에 쓰인다 (D-19: node_modules 는 gradle RN AAR 해소 전용으로 sandbox 루트에 위치). apps/native 빌드와 무관하게 sandbox 루트에서 한 번 실행:

```bash
cd path/to/sandbox
npm install
# 또는 yarn install
```

`settings.gradle` 의 `includeBuild("../node_modules/@react-native/gradle-plugin")` 과 `build.gradle` 의 `apply plugin: "com.facebook.react"` 가 이 `node_modules` 를 참조한다. 디바이스 런타임엔 Node.js 가 불필요하다.

---

## page bundle 배치

### 처음 빌드 전 확인

sandbox 레포에 page bundle 이 이미 커밋돼 있는지 먼저 확인한다:

```bash
ls android/app/src/main/assets/shared.bundle.js android/app/src/main/assets/pages/
```

아래 파일들이 보이면 apps/native 없이 그대로 APK 빌드 + 실행 가능하다:

```
android/app/src/main/assets/
  shared.bundle.js            ← metro-wrap 된 vendor 묶음 (~860KB). 부팅 번들
  pages/
    HelloRN.bundle.js         ← URI host "HelloRN" 진입 시 평가
    detail.bundle.js          ← URI host "detail" 진입 시 평가
    (추가 미니앱 번들 ...)
```

파일이 없거나 갱신이 필요한 경우 → 아래 "파일명 규칙" 및 "수동 배치" 섹션 참조. apps/native 측 빌드가 필요한 경우 → 문서 말미 "부록: RN 개발자가 page bundle 을 갱신하는 경우" 참조.

### 파일명 규칙

번들 파일명 = `moduleName` = URI host = `AppRegistry.registerComponent` 의 첫 인자.
예: `lifeplus-tribes://HelloRN` → `assets://pages/HelloRN.bundle.js` → `AppRegistry.registerComponent("HelloRN", ...)`

파일 경로(`index`) 가 아닌 **모듈 이름**이어야 한다 (D-18: bundle 파일명 = moduleName = URI host = AppRegistry 등록명 일치 규칙).

### 수동 배치가 필요한 경우

`apps/native` 의 `deploy:android` 가 없는 환경이라면 직접 복사:

```bash
cp dist/pages/android/HelloRN.bundle.js path/to/sandbox/android/app/src/main/assets/pages/
cp dist/shared/android/shared.bundle.js  path/to/sandbox/android/app/src/main/assets/
```

---

## 빌드 + 디바이스 실행

### APK 빌드

```bash
cd path/to/sandbox/android
./gradlew assembleDebug
# 출력: app/build/outputs/apk/debug/app-debug.apk
```

빌드가 느린 경우 (`--parallel`, `--build-cache` 는 이미 적용됨):

```bash
# 최초 빌드는 Hermes NDK 컴파일 때문에 5~10분 소요. 이후 incremental 빌드는 수십 초.
```

빌드 실패 원인을 좁힐 때 (로그 필터링):

```bash
./gradlew assembleDebug --info 2>&1 | grep -E "(BUILD|FAILED|error)"
```

### ADB 설치

```bash
# 연결된 기기 목록 확인
adb devices
# List of devices attached
# emulator-5554  device

# 설치
adb install -r app/build/outputs/apk/debug/app-debug.apk
# Success
```

### 앱 시작 + URI 진입

```bash
# 앱 강제 종료 후 URI 진입 (reactHost lazy 초기화를 깨끗하게 하려면 force-stop 필수)
adb shell am force-stop com.lifeplus.sandbox
adb shell am start -W -a android.intent.action.VIEW \
  -d "lifeplus-tribes://HelloRN?foo=hello&bar=42"
# -W: wait until launch completes (실패 시 stack trace 출력)
```

기대 logcat:

```
I sandbox-poc: RN mode: static multi-bundle (shared + pages/*)
I sandbox-poc: open url=lifeplus-tribes://HelloRN?foo=hello&bar=42 appName=HelloRN path=/ params={foo=hello, bar=42}
I sandbox-poc: loading page bundle: assets://pages/HelloRN.bundle.js
I ReactNativeJS: Running "HelloRN"
```

### logcat 필터링

```bash
adb logcat -s sandbox-poc ReactNativeJS ReactNative
```

---

## 세 가지 동작 모드

`SandboxApplication.reactHost` 의 lazy 초기화가 `SharedPreferences("sandbox").metroIp` 의 비어있지 않음 여부로 분기한다.

| 모드 | 트리거 | 부팅 번들 | 미니앱 번들 | 용도 |
|---|---|---|---|---|
| **Multi-bundle (정식)** | `metroIp` 비어있음 + `assets://shared.bundle.js` 존재 | `assets://shared.bundle.js` | `assets://pages/{moduleName}.bundle.js` (URI 진입 시 동적 평가) | 본 배포 흐름. apps/native `deploy:android` 산출물 사용 |
| **Mono 회귀 (선택)** | `metroIp` 비어있음 + [`SandboxApplication.kt`](android/app/src/main/java/com/lifeplus/sandbox/SandboxApplication.kt) 의 `jsBundleFilePath = if (useMetro) null else "assets://shared.bundle.js"` 줄을 `"assets://main.jsbundle"` 로 일시 변경 후 재빌드. 평시엔 안 씀 | `assets://main.jsbundle` (shared+pages 합본) | 단일 번들 (페이지 포함) | apps/native build pipeline 회귀 검증용. 코드 일시 수정 필요 |
| **Metro (개발)** | DevTool 에서 Metro 서버 IP 입력 + 앱 재시작 | Metro 서버에서 fetch (`http://{IP}:8081/index.bundle?platform=android&dev=true`) | 단일 번들 | RN hot reload 개발용 |

`SandboxApplication.kt` 의 핵심 분기:

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

> **주의**: `reactHost` 는 `lazy` 라 앱 프로세스 생성 시 딱 한 번 초기화된다. Metro IP 변경 후에는 반드시 `force-stop` 후 재진입해야 반영된다.

---

## DevTool 사용법

URI 없이 런처에서 앱을 직접 열면 자동으로 DevTool 화면이 표시된다.

구현 파일: [DevToolFragment.kt](android/app/src/main/java/com/lifeplus/sandbox/DevToolFragment.kt) + [fragment_devtool.xml](android/app/src/main/res/layout/fragment_devtool.xml)

### 기능

| UI 요소 | 동작 |
|---|---|
| **스킴 입력 필드** (`schemeField`) | `lifeplus-tribes://HelloRN` 같은 URI 직접 입력. 기본값 `lifeplus-tribes://HelloRN` |
| **실행 버튼** (`runButton`) | `Intent(ACTION_VIEW, uri)` 로 MainActivity 재진입 |
| **Metro IP 입력 필드** (`metroIpField`) | 비워두면 정적 multi-bundle 모드. IP 입력 시 Metro 단일 번들 모드 전환 (앱 재시작 필요) |
| **저장 / 초기화 버튼** | `SharedPreferences("sandbox")` 의 `metroIp` 키 쓰기/삭제 |
| **최근 실행 목록** (`recentLabel`) | 최근 10개 스킴. 클릭 없이 입력 필드에 직접 수정 |

### 자체 호출 (DevTool 미사용)

```bash
# 에뮬레이터
adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-tribes://HelloRN"

# 실기기 (PC 포트 포워딩 후 Metro 모드 시)
adb reverse tcp:8081 tcp:8081
```

---

## 핵심 파일 좌표

### Android

| 파일 | 역할 |
|---|---|
| [SandboxApplication.kt](android/app/src/main/java/com/lifeplus/sandbox/SandboxApplication.kt) | `ReactHost` 생성 + Metro/정적 모드 분기. `jsBundleFilePath="assets://shared.bundle.js"`. `PackageList(this).packages + LifePlusAppPackage()` 로 sandbox 내부 NativeModule 수동 등록 |
| [MainActivity.kt](android/app/src/main/java/com/lifeplus/sandbox/MainActivity.kt) | URI 파싱 (`handleIntent`) + `showDevTool` root commit + `loadPageBundle` + `commitReactFragment`. `DefaultHardwareBackBtnHandler` 구현 |
| [DevToolFragment.kt](android/app/src/main/java/com/lifeplus/sandbox/DevToolFragment.kt) | Metro IP 입력 + 스킴 입력 + 최근 스킴 목록 |
| [fragment_devtool.xml](android/app/src/main/res/layout/fragment_devtool.xml) | DevTool UI 레이아웃 |
| [LifePlusAppModule.kt](android/app/src/main/java/com/lifeplus/sandbox/LifePlusAppModule.kt) | `@lifeplus/native-bridge` 의 `NativeModules.LifePlusApp` sandbox reference 구현. `back` (fragment popBackStack / DevTool root finish) + `share` (Intent.ACTION_SEND). 본 앱 통합 시 호스트별 새 구현체로 대체 (decisions.md D-33) |
| [LifePlusAppPackage.kt](android/app/src/main/java/com/lifeplus/sandbox/LifePlusAppPackage.kt) | `ReactPackage` — autolink 외부 라이브러리가 아니라 sandbox 내부 NativeModule 이라 `SandboxApplication.reactHost` 의 packageList 에 수동으로 합쳐 등록 |
| [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) | `<data android:scheme="lifeplus-tribes" />` URI 스킴 등록. `launchMode="singleTask"` |
| [app/build.gradle](android/app/build.gradle) | RN + AppCompat + fragment-ktx 의존성. `compileSdk 36`, `minSdk 24` |
| [settings.gradle](android/settings.gradle) | `includeBuild("../node_modules/@react-native/gradle-plugin")` — sandbox 루트 node_modules 참조 |

### node_modules 위치

`package.json` + `node_modules` 는 **sandbox 루트**에 있다. `android/` 폴더 안이 아니다 (D-19).

```
sandbox-poc/
  package.json          ← RN 0.83.2 + React 19.2.1
  node_modules/         ← gradle 이 여기서 react-android / hermes-android AAR 해소
  android/
    settings.gradle     ← includeBuild("../node_modules/...")  ← 루트를 참조
```

---

## apps/native 와의 계약

sandbox 가 apps/native 로부터 받는 산출물의 계약 명세.

| 항목 | 값 | 위치 |
|---|---|---|
| **JS 부팅 번들** | `assets://shared.bundle.js` | `SandboxApplication.jsBundleFilePath` |
| **미니앱 번들** | `assets://pages/{moduleName}.bundle.js` | `MainActivity.loadPageBundle` 에서 lookup |
| **동적 평가 진입점** | `ReactHostImpl.loadBundle$ReactAndroid_debug` reflection | `MainActivity.invokeLoadBundle` (D-14: RN 0.83 Bridgeless 에 multi-bundle public API 없어 reflection 우회) |
| **moduleName** | URI host = `AppRegistry.registerComponent` 의 첫 인자 | `MainActivity.handleIntent` 의 `appName = uri.host` 분기 |
| **URI 스킴** | `lifeplus-tribes://{moduleName}?{query}` | [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) |
| **InitialProps** | `initialPath`, `platform`, `appVersion` + URI query 평탄화 | `MainActivity.buildInitialProps` |
| **Metro fetch URL** | `http://{IP}:8081/index.bundle?platform=android&dev=true` | `metroIp` SharedPreferences 가 비어있지 않을 때 (단일 번들 모드) |

---

## multi-bundle 동작 (핵심 시퀀스)

### 전체 흐름 다이어그램

```
부팅                                    URI 진입
 │                                       │
 ▼                                       ▼
SandboxApplication                    MainActivity.handleIntent
└ getDefaultReactHost(                └ appName = uri.host  (= moduleName)
    jsBundleFilePath =                └ path    = uri.path
    "assets://shared.bundle.js")      └ params  = uri.queryParameters
 │                                       │
 ▼                                       ▼
ReactHost shared.bundle 평가          loadPageBundle(appName, onComplete)
(RN polyfill + InitializeCore +       └ ReactInstance 미준비 (cold):
 globalThis.__SHARED__ 채움)             addReactInstanceEventListener 대기
                                       └ 준비 완료 (warm):
                                          currentReactContext != null 가드 → 즉시 호출
                                          ↓
                                       JSBundleLoader.createAssetLoader(
                                          "assets://pages/{appName}.bundle.js")
                                          ↓
                                       ReactHostImpl.loadBundle (reflection)
                                          ↓
                                       Bolts Task<Boolean> polling (16ms)
                                          ↓
                                       AppRegistry.registerComponent(appName)
                                          ↓
                                       ReactFragment.Builder()
                                          .setComponentName(appName)
                                          .setLaunchOptions(initialProps)
                                       → surface mount
```

`MainActivity.loadPageBundle` 의 세부 흐름. 반드시 이 순서로 실행된다.

### cold path (첫 진입)

1. `host.currentReactContext != null` 체크 → `null` 이면 cold path 진입
2. `host.addReactInstanceEventListener(listener)` 등록
3. `host.start()` 호출 → shared.bundle.js 평가 시작 (RN polyfill + `globalThis.__SHARED__` 채움)
4. 평가 완료 → `onReactContextInitialized` 콜백 → listener 제거 → warm path 로 진입

### warm path (두 번째 진입부터)

1. `host.currentReactContext != null` → 즉시 `invokeLoadBundle` 호출
2. `JSBundleLoader.createAssetLoader(context, "assets://pages/{appName}.bundle.js", false)` — public API
3. `ReactHostImpl.loadBundle$ReactAndroid_debug(loader)` — reflection 호출 (D-14)
4. Bolts `Task<Boolean>` 폴링 (16ms 단위) — `isCompleted` 가 true 가 될 때까지 대기 (D-16)
5. page bundle IIFE 평가 완료 → `AppRegistry.registerComponent({appName}, ...)` 가 호출됨
6. `ReactFragment.Builder().setComponentName(appName).setLaunchOptions(initialProps).setFabricEnabled(true).build()` 로 surface mount

### Reflection 우회의 정당성 (D-14)

RN 0.83 Bridgeless 는 multi-bundle 평가를 위한 public API 가 없다. `ReactHost` 의 public 메서드는 단일 번들 reload (`setBundleSource`) 만 노출한다. 실제 진입점인 `ReactHostImpl.loadBundle(JSBundleLoader)` 는 `internal` 가시성:

```kotlin
// ReactHostImpl.kt (RN 내부)
internal fun loadBundle(bundleLoader: JSBundleLoader): Task<Boolean>
```

JVM bytecode 에서는 mangled name `loadBundle$ReactAndroid_debug` (debug 빌드) / `loadBundle$ReactAndroid_release` (release 빌드) 로 노출된다. sandbox 는 빌드 variant 에 무관하게:

```kotlin
host.javaClass.declaredMethods.firstOrNull { m ->
    m.name.startsWith("loadBundle") &&
        m.parameterTypes.size == 1 &&
        m.parameterTypes[0] == JSBundleLoader::class.java
}
```

prefix match 로 찾는다. RN 0.84+ 에서 표준 public API 가 노출되면 reflection 을 제거한다.

---

## InitialProps 표

`MainActivity.buildInitialProps` 가 URI 정보를 `android.os.Bundle` 로 빚어 `ReactFragment.Builder().setLaunchOptions(bundle)` 에 넘긴다. JS 측 `AppRegistry.registerComponent` component factory 의 첫 인자로 들어온다.

| 키 | 값 | 비고 |
|---|---|---|
| `initialPath` | `uri.path` (없으면 `"/"`) | RN 라우터가 initial route 로 사용 |
| `platform` | `"android"` | |
| `appVersion` | `BuildConfig.VERSION_NAME` | |
| 그 외 query 키 | `uri.getQueryParameter(k)` (모두 String) | URI query 평탄화 |

**RESERVED_KEYS** = `{"initialPath", "platform", "appVersion"}` — 사용자 query 가 같은 이름이면 무시하고 `Log.w` 출력.

### 예시

```
lifeplus-tribes://HelloRN/path/x?foo=hello&bar=42
  ↓
Bundle = {
  initialPath: "/path/x",
  platform:    "android",
  appVersion:  "1.0",
  foo:         "hello",
  bar:         "42",
}
```

```
lifeplus-tribes://detail?orderId=ABC123&platform=custom
  ↓ (platform 은 RESERVED_KEY → 무시, Log.w 출력)
Bundle = {
  initialPath: "/",
  platform:    "android",
  appVersion:  "1.0",
  orderId:     "ABC123",
}
```

---

## 트러블슈팅

빌드 / 런타임 / 환경 단계에서 만나는 증상별 조치.

| 증상 | 원인 | 조치 |
|---|---|---|
| sandbox 가 Metro 모드로 부팅 (`RN mode: Metro http://...`) 인데 multi-bundle 을 검증하고 싶은 경우 | `SharedPreferences("sandbox")` 의 `metroIp` 가 비어있지 않음 | DevTool 화면에서 Metro IP 필드를 비우고 저장 → `adb shell am force-stop com.lifeplus.sandbox` → 재진입 |
| logcat 에 `reactInstance is null. Dropping work.` | `MainActivity.loadPageBundle` 이 ReactInstance 준비 전에 `loadBundle` 호출 (D-15) | `addReactInstanceEventListener` + `currentReactContext != null` 가드가 살아있는지 [MainActivity.kt](android/app/src/main/java/com/lifeplus/sandbox/MainActivity.kt) 에서 확인 |
| logcat 에 `NoSuchMethodException: ReactHostImpl.loadBundle` | RN 업그레이드로 Kotlin `internal` mangled name 이 변경됨 (예: `loadBundle$ReactAndroid_debug` → 다른 suffix) | `declaredMethods.firstOrNull { it.name.startsWith("loadBundle") }` prefix match 가 살아있는지 확인. RN 0.84+ 에서 public API 가 나오면 reflection 제거 |
| `Unable to load script: pages/{X}.bundle.js` | sandbox 가 `assets/pages/{moduleName}.bundle.js` 를 못 찾음 | apps/native 의 `yarn deploy:android` 가 출력한 page 목록과 URI host 가 일치하는지 확인. 파일명은 moduleName (`HelloRN` 등) 이지 파일 경로 (`index`) 가 아님 (D-18) |
| `Compiling JS failed: Invalid expression encountered` | shared bundle 이 metro-wrap 없이 평가됨 (D-17) | apps/native 의 `deploy:android` 가 shared 만 `wrapAsMetroModule` 로 감싸 배치하는지 확인 |
| Metro IP 를 비웠는데도 Metro 로 연결 시도함 | 앱 재시작 안 한 것. `reactHost` 는 `lazy` 라 첫 평가에만 IP 를 읽음 | `adb shell am force-stop com.lifeplus.sandbox` 후 재진입 |
| 에뮬레이터에서 `localhost` 입력 시 Metro 에 안 붙음 | 에뮬레이터의 `localhost` 는 에뮬레이터 자기 자신 | 호스트 머신 IP 는 `10.0.2.2`. 실기기는 `adb reverse tcp:8081 tcp:8081` 후 `localhost:8081` |
| JS 수정했는데 화면이 그대로 | force-stop 없이 다시 띄움 → 기존 RN 인스턴스가 살아있어서 새 bundle 을 안 받음 | `adb shell am force-stop com.lifeplus.sandbox` 후 재진입 |
| 본앱(lifeplus tribes) 이 같이 설치된 기기에서 앱 선택 다이얼로그가 뜸 | `lifeplus-tribes` 스킴이 두 앱에 동시 등록됨 | 의도된 동작 (D-3: URI 스킴을 본앱과 공유해 sandbox 가 본앱 host shell 로 합류하는 경로). sandbox-poc 가 본앱 host shell 로 흡수되는 경로에서 한 앱으로 통합될 예정 |
| 첫 진입 시 ANR 비슷한 증상, logcat 에 `start timeout` | zygote cold start — RN dex 로딩 + GC init 에 ~8s 소요 (process attach 10s timeout 직전) | 우리 코드 이슈 아님. 두 번째 진입부터 warm dex 캐시로 정상화됨 |
| `Gradle sync failed: Could not resolve com.facebook.react:react-android` | `node_modules` 가 없거나 경로가 틀림 | sandbox 루트에서 `npm install` 실행. `settings.gradle` 의 `includeBuild("../node_modules/...")` 경로 확인 |
| `AppCompatActivity.commit {}` 컴파일 에러 | `fragment-ktx` 미포함 | `app/build.gradle` 의 `implementation("androidx.fragment:fragment-ktx:1.8.0")` 확인 |
| `ClassCastException` in `onResume` | `MainActivity` 가 `DefaultHardwareBackBtnHandler` 미구현 | `MainActivity : AppCompatActivity(), DefaultHardwareBackBtnHandler` 선언 + `invokeDefaultOnBackPressed()` override 확인 |
| FATAL: `TurboModule method "back" called with 1 arguments (expected argument count: 0)` (RN 0.83 Bridgeless) | `native-bridge` 의 `sdk-native.ts` 의 `call(command, params?)` helper 가 params 없이 호출돼도 항상 `fn(undefined)` 1-arg 로 invoke. TurboModule 검증이 사용자 arg 수 vs `@ReactMethod` 시그니처 arg 수를 strict 비교 | void 커맨드도 시그니처에 `params: ReadableMap?` 자리를 둔다. 예: `@ReactMethod fun back(params: ReadableMap?, promise: Promise)` (decisions.md D-30) |
| `Unresolved reference 'currentActivity'` in NativeModule | Kotlin 에서 `ReactContextBaseJavaModule` 의 `currentActivity` 는 property 가 아니라 protected method | `getCurrentActivity()` 로 호출 |
| `Unresolved reference 'runOnUiThread' / 'startActivity'` in NativeModule lambda | smart-cast 가 lambda 안에선 깨짐 | 캡처 변수를 명시적 타입으로 새 변수에 받아 사용 (예: `val mainActivity: MainActivity = activity` 후 `mainActivity.runOnUiThread { ... }`) |

---

## 알려진 이슈와 배경

코드/패치가 왜 이렇게 짜였는지 배경 — 빌드 중 막혔을 때 *원인* 을 이해하는 자료.

> 설계 결정의 배경과 히스토리는 [decisions.md](decisions.md) 참조.

### AppCompat / fragment-ktx 누락

RN 0.83 CLI 템플릿의 `app/build.gradle` 에는 React 의존성만 있고 AppCompat 이 없다. `AppCompatActivity` + `commit { }` 확장 함수를 쓰려면 명시적으로 추가해야 한다:

```groovy
// app/build.gradle
dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.fragment:fragment-ktx:1.8.0")
}
```

### Process attach timeout — zygote cold start

첫 진입 시 logcat 에 `Killing 16549:com.lifeplus.sandbox (adj 0): start timeout` 이 찍히는 경우가 있다. zygote 가 RN 앱 dex 로딩 + GC init 에 ~8s 걸린 게 process attach 10s timeout 직전까지 잡아먹은 것이다. 우리 코드 이슈가 아니다. 두 번째 진입부터 warm dex 캐시로 정상화된다.

### Reflection 우회 (D-14)

RN 0.83 Bridgeless 에 multi-bundle 평가용 public API 가 없어 `ReactHostImpl.loadBundle` 을 reflection 으로 호출한다. RN 0.84+ 에서 표준 API 가 나오면 제거 예정. 자세한 정당성은 [decisions.md](decisions.md) D-14.

### node_modules 위치

`package.json` + `node_modules` 는 sandbox 루트에 있다. `android/` 안이 아님 (D-19). gradle 이 `includeBuild("../node_modules/...")` 로 RN AAR 를 해소하기 때문에 sandbox 루트에서 `npm install` 을 실행해야 한다.

### singleTop vs singleTask

현재 `AndroidManifest.xml` 은 `launchMode="singleTask"` 다. `onNewIntent` 가 새 URI 진입을 받는다. `singleTop` 으로 변경 가능한지는 추후 확인 항목 (DeepLinkIngressQueue 동작과의 충돌 여부).

---

## 부록: RN 개발자가 page bundle 을 갱신하는 경우

sandbox 레포에 커밋된 bundle 을 최신 apps/native 산출물로 교체해야 할 때 실행한다. **앱 개발자는 이 섹션을 건드릴 필요 없다.**

```bash
cd path/to/life/apps/native
yarn bundle:mono android      # shared + 모든 page bundle 빌드
yarn deploy:android           # sandbox android/app/src/main/assets/ 로 복사
```

`deploy:android` 완료 후 sandbox 에 아래 파일들이 갱신된다:

```
android/app/src/main/assets/
  shared.bundle.js
  pages/
    HelloRN.bundle.js
    detail.bundle.js
    (추가 미니앱 번들 ...)
```

갱신 후 평소처럼 `./gradlew assembleDebug` + `adb install` 하면 된다.

---

## 관련 문서

- [README.md](README.md) — 프로젝트 공통 정체성 + 아키텍처 + 진행 상태
- [decisions.md](decisions.md) — 모든 결정 카드 + 회고
- [ios.md](ios.md) — iOS 개발자 가이드
- apps/native [README.md](https://github.com/lp-mktplatform/life/tree/main/apps/native) — 번들 빌드 + deploy 파이프라인 (별도 레포)
