# sandbox-poc — RN Native Shell PoC

> **목적**: URI 스킴 수신 → RN Container 띄우기까지를 Native만으로 증명하는 최소 PoC.
> RN 측 코드 작성은 **없다**. 정적 hello-world `main.jsbundle`을 앱 번들에 박아 RN 런타임 부팅만 확인한다.

상위 컨텍스트는 Obsidian `1-Projects/Epic-RN-metro/sandbox-poc-mvp-todo.md` 참고.

---

## MVP DoD (Definition of Done)

| 항목 | 내용 |
|---|---|
| DoD-1 | iOS / Android 각각 빌드 성공 |
| DoD-2 | DevTool UI에서 URI 스킴 직접 입력 → 실행 가능 |
| DoD-3 | `lifeplus-sandbox://hello/world?foo=bar` 수신 → 파싱 로그 출력 |
| DoD-4 | 파싱 결과로 RN Container push → "RN 런타임 부팅 OK" 화면 노출 |

JS↔Native 통신, Metro 연결, hot reload, 파일 기반 라우팅은 **검증하지 않음**.

---

## 진행 상태 (2026-05-11 기준)

| 플랫폼 | 상태 | 비고 |
|---|---|---|
| Android | ✅ **빌드 성공** | `./gradlew assembleDebug` 통과 (124MB debug APK 산출, 정적 번들 887KB 포함, `lifeplus-sandbox://` 스킴 + `SandboxApplication` + `MainActivity` 등록 확인) |
| iOS | ⏸ 보류 (`ios-wip/`) | pbxproj의 ObjC → Swift 전환 시 안전한 수정 도구 필요. Xcode GUI 또는 `xcodeproj` Ruby gem 으로 별도 수행 |

### DoD 진행률 (Android)

| DoD | Android | iOS |
|---|---|---|
| DoD-1 빌드 성공 | ✅ `./gradlew assembleDebug` 3분 4초, 124MB debug APK | ⏸ |
| DoD-2 DevTool UI에서 스킴 입력 가능 | ✅ 에뮬레이터(Medium_Phone_API_36.1)에서 시각 확인 | ⏸ |
| DoD-3 스킴 파싱 로그 | ✅ `I/sandbox-poc: open url=lifeplus-sandbox://HelloRN/world?foo=bar appName=HelloRN path=/world params={foo=bar}` | ⏸ |
| DoD-4 "RN 런타임 부팅 OK" 화면 | ✅ 정적 번들에서 RN 부팅, 화면 노출 (`I/ReactNativeJS: Running "HelloRN"`) | ⏸ |

`ios-wip/` 내용: HelloRN의 ios 디렉토리 복사본 + 작성된 Swift 파일(`AppDelegate.swift`, `RNContainerViewController.swift`, `DevToolViewController.swift`) + 정적 번들(`SandboxApp/RN/main.jsbundle`). project.pbxproj는 여전히 `AppDelegate.h/.mm/main.m`를 참조 → Xcode에서 ObjC 파일 삭제 + Swift 파일 추가 + Info.plist에 `CFBundleURLTypes` 추가 작업 필요.

## 레포 구조

```
sandbox-poc/
  ios-wip/                      ← 보류. iOS 본작업 시 ios/ 로 이름 변경 후 Xcode에서 마무리
    Podfile
    SandboxApp/
      AppDelegate.swift        (← 추가됨, pbxproj 등록 필요)
      RNContainerViewController.swift  (← 추가됨, pbxproj 등록 필요)
      DevToolViewController.swift      (← 추가됨, pbxproj 등록 필요)
      Info.plist               (← URL scheme 추가 필요)
      RN/main.jsbundle         (← 정적 번들, 커밋됨)
    SandboxApp.xcodeproj
  android/
    app/
      src/main/
        java/com/lifeplus/sandbox/
          MainActivity.kt
          SandboxApplication.kt
          RNContainerFragment.kt
          DevToolFragment.kt
        assets/main.jsbundle    ← 정적 번들 (커밋)
        AndroidManifest.xml
      build.gradle
    build.gradle
    settings.gradle
  HelloRN/                       ← 정적 번들 재생성용 scratch (gitignored)
  decisions.md
  README.md
  .gitignore
```

---

## 빌드 & 실행

### 사전 요구
- macOS, Xcode 15+, CocoaPods, Ruby
- Android Studio + JDK 17 + Android SDK API 34
- Node.js 18+ (정적 번들 재생성 시에만 필요)

### iOS
```bash
cd ios
pod install
open SandboxApp.xcworkspace
# Xcode에서 시뮬레이터 선택 후 Run
```

### Android
```bash
cd android
./gradlew assembleDebug
# 또는 Android Studio에서 임포트 후 Run
```

### 자체 호출 (DevTool 미사용 검증)
```bash
# iOS 시뮬레이터
xcrun simctl openurl booted "lifeplus-sandbox://HelloRN"

# Android 에뮬레이터/실기기
adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-sandbox://HelloRN"
```

---

## DevTool 사용법

앱 첫 진입 시 자동 노출되는 화면.
1. TextField에 스킴 입력: `lifeplus-sandbox://HelloRN`
2. "실행" 버튼 → 앱이 자체 openURL 호출
3. RN Container로 화면 전환 → "RN 런타임 부팅 OK"

DEBUG 빌드에서만 노출.

---

## RN / React 버전

- **React Native 0.83.2** (New Architecture only, Bridgeless)
- **React 19.2.1** (life 모노레포 React 19 통일에 맞춤)
- Hermes ON · Fabric ON

이전 (Phase 1 초기) RN 0.74.5 + React 18.x → 2026-05-11 업그레이드. 자세한 회고는 [decisions.md](decisions.md).

## 정적 번들 재생성

번들은 이미 커밋되어 있다. RN 코드(`HelloRN/App.tsx`)를 바꾼 후 재생성이 필요한 경우:

```bash
cd HelloRN
npx react-native bundle --platform android --dev false \
  --entry-file index.js \
  --bundle-output ../android/app/src/main/assets/main.jsbundle \
  --assets-dest ../android/app/src/main/res
```

HelloRN scratch가 통째로 사라졌다면 재초기화:

```bash
npx @react-native-community/cli init HelloRN --version 0.83.2 --skip-install --skip-git-init
cd HelloRN && npm pkg set dependencies.react="19.2.1" && npm install
# App.tsx를 본 레포의 ship-state 텍스트로 교체 후 위 bundle 명령 실행
```

---

## Metro 모드 (Phase 1-2, Android 완료)

Android에서는 DevTool 화면 상단에 "Metro 서버 IP" 입력 필드가 있다.

- **비워두면** → 정적 `assets://main.jsbundle` 그대로 사용 (MVP와 동일)
- **`10.0.2.2:8081` 등 입력 후 저장** → 앱 재진입 시 RN이 Metro 서버에서 dev bundle을 fetch (cold reload)

내부 동작:
- 저장된 IP는 `sandbox` SharedPreferences (`metroIp` 키) + RN이 보는 `react-native-dev-preferences`의 `debug_http_host`에 동시에 주입
- [SandboxApplication.kt](android/app/src/main/java/com/lifeplus/sandbox/SandboxApplication.kt)에서 `getJSBundleFile()`이 IP 유무로 분기: 있으면 null(=Metro fetch), 없으면 assets 경로
- `getUseDeveloperSupport()`도 IP 유무로 분기 — Metro fetch 자체에 필요한 플래그
- IP 변경은 **앱 재시작 후** 반영됨 (RN ReactNativeHost는 instance 생성 시 한 번만 읽음)

### 의도적으로 안 한 것 — Fast Refresh / dev menu

sandbox-poc는 **Native Shell 컨테이너**일 뿐, RN 개발 환경이 아니다. Fast Refresh, dev menu, redbox UI는 RN 팀이 본인의 RN 개발 환경(`HelloRN` 또는 Phase 2의 모노레포)에서 누리는 기능이고, sandbox-poc 앱이 보여줄 필요가 없다.

검증 범위: **"RN 코드를 바꾸고 앱 재진입하면 새 화면이 뜬다"** — 이게 sandbox의 책임. 확인됨.

### 사용법

```bash
# 에뮬레이터: 호스트 머신은 10.0.2.2로 접근
# 실기기: adb reverse tcp:8081 tcp:8081 후 IP=localhost:8081

# Metro 서버 기동 (HelloRN scratch 안에서)
cd HelloRN && npx react-native start
```

DevTool 화면에서 IP 입력 → 저장 → 앱 종료(`force-stop`) → 다시 실행 → 스킴 호출

## 의도적으로 안 하는 것

| 빼는 것 | 이월 단계 |
|---|---|
| JS → Native NavBridge | Phase 2-2 |
| 모노레포 / 자동 라우팅 / esbuild serializer | Phase 2 |
| InitialProps 전달 | Phase 1-3 |
| 푸시 / 권한 / 기존 SDK 통합 | Phase 3 |

---

## RN 개발자 가이드

> sandbox-poc는 **Native Shell 컨테이너**다. RN 화면을 띄우는 통이고, JS 코드 작성과 hot reload는 RN 개발자가 본인의 RN 환경(아래)에서 한다.

### 셋업 (한 번만)

```bash
# 1) sandbox-poc 레포 체크아웃 후
cd HelloRN && npm install   # node_modules는 sandbox 루트로 symlink 돼 있음

# 2) sandbox-poc Android 앱 빌드 + 설치 (정적 번들로 한 번)
cd ../android && ./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk

# 3) Metro 서버 기동 (이후 RN 작업 동안 켜둠)
cd ../HelloRN && npx react-native start
```

### 일상 워크플로

| 상황 | 해야 할 것 |
|---|---|
| **JS 코드만 수정 (가장 흔함)** | 1) `App.tsx` 등 수정 → 2) 앱에서 force-stop → 3) 스킴 재진입 (`adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-sandbox://HelloRN"`) → 4) 새 화면 확인 |
| Metro IP 변경 | DevTool 진입 → IP 입력 → 저장 → **앱 재시작** (RN host는 부팅 시 1회만 IP 읽음) |
| 정적 번들 모드로 전환 (Metro 끄고 테스트) | DevTool → "정적 번들로 초기화" → 앱 재시작 |
| Native(Kotlin) 코드 수정 | `./gradlew assembleDebug` → `adb install -r ...` (Metro 무관, 풀 빌드) |
| 출고용 정적 번들 갱신 | `cd HelloRN && npx react-native bundle --platform android --dev false --entry-file index.js --bundle-output ../android/app/src/main/assets/main.jsbundle --assets-dest ../android/app/src/main/res` |

### Metro 진입 / 정적 모드 빠른 검증

```bash
# 현재 어느 모드인지 logcat로 확인
adb logcat -c
adb shell am force-stop com.lifeplus.sandbox
adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-sandbox://HelloRN"
adb logcat -d | grep "RN mode:"
# I/sandbox-poc: RN mode: Metro http://10.0.2.2:8081/    ← Metro 모드
# I/sandbox-poc: RN mode: static assets://main.jsbundle  ← 정적 모드
```

### 흔한 함정

- **Metro IP가 비워졌는데도 Metro로 가려고 함**: 앱 재시작 안 한 것. `getJSBundleFile()`은 `ReactNativeHost` 생성 시 한 번만 평가됨
- **"Cannot connect to Metro" 토스트**: Metro 서버가 죽어 있거나 IP/포트가 안 맞음. `curl http://localhost:8081/status` (호스트) 또는 `adb shell curl http://10.0.2.2:8081/status` (에뮬레이터)로 확인
- **에뮬레이터에서 `localhost` 입력 시 안 됨**: 에뮬레이터의 `localhost`는 *에뮬레이터 자기 자신*. 호스트 머신은 `10.0.2.2`. 실기기는 `adb reverse tcp:8081 tcp:8081` 후 `localhost:8081`
- **JS 수정했는데 화면 그대로**: 앱을 force-stop 안 하고 다시 띄움 → 기존 RN 인스턴스가 살아있어서 bundle 다시 안 받음. **`force-stop` 후 진입이 필수**
- **번들에 한국어가 깨져 보임**: 정상. RN bundle은 한국어를 `\uXXXX` 이스케이프로 박음. 화면 렌더링 시점에 복원됨

### 좌표

- **RN 소스**: [HelloRN/App.tsx](HelloRN/App.tsx) — Phase 2 전까진 이게 유일한 RN 컴포넌트
- **Metro 진입 분기**: [SandboxApplication.kt](android/app/src/main/java/com/lifeplus/sandbox/SandboxApplication.kt) (`useMetro`)
- **URI 파싱**: [MainActivity.kt](android/app/src/main/java/com/lifeplus/sandbox/MainActivity.kt) (`handleIntent`)
- **DevTool UI**: [DevToolFragment.kt](android/app/src/main/java/com/lifeplus/sandbox/DevToolFragment.kt) + [fragment_devtool.xml](android/app/src/main/res/layout/fragment_devtool.xml)
- **RN View 마운트**: [RNContainerFragment.kt](android/app/src/main/java/com/lifeplus/sandbox/RNContainerFragment.kt)

### Phase 2 진입 시 가져갈 것 / 버릴 것

| 자산 | 운명 |
|---|---|
| `HelloRN/` scratch | **버린다.** Phase 2는 모노레포의 `apps/sandbox-rn`이 RN 소스가 됨 |
| `lifeplus-sandbox://` 스킴 | **유지.** 모노레포 미니앱들이 그대로 이걸 호출 |
| `SandboxApplication`/`MainActivity`/`RNContainerFragment` | **유지.** 본 레포 통합 단계까지 Native Shell의 골격 |
| DevTool의 Metro IP UI | **유지.** 모노레포의 Metro 서버 IP를 그대로 입력해서 쓸 수 있음 |
| `assets://main.jsbundle` 정적 모드 | **유지 + 확장.** Phase 4에서 CDN URL fetch 모드 추가 |
| `getUseDeveloperSupport()` 분기 | **재검토 필요.** 본 레포는 release 빌드 기준이라 통째로 false로 둘지, Debug variant로만 분기할지 결정 |
