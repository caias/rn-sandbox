# Decisions — sandbox-poc MVP

> 결정 카드. 각 항목은 MVP 시작 전 한 번 통과시켜 두는 게 목적이고, 본작업 단계에서 재확인한다.

---

## 결정 (MVP 시작 시점, 2026-05-11)

| # | 항목 | 결정 | 근거 / 비고 |
|---|---|---|---|
| D-1 | RN 버전 | **0.83.2** (2026-05-11 업그레이드) | life 모노레포(admin/web)의 React 19 통일에 맞춰 React 19.2.1 사용. 0.83 시리즈가 19.2.x peer (`^19.2.0`)를 정확히 충족. Toss Granite 카탈로그(RN 0.84 + React 19.2.3)와도 1 minor 차이로 정렬 |
| D-1a | React 버전 | **19.2.1** | life 모노레포 통일 버전. RN 0.83 peer `^19.2.0` 만족. 향후 모노레포가 19.2.x 어디로 가도 함께 움직임 |
| D-1b | Architecture | **New Architecture (Bridgeless) only** | RN 0.82+는 Old Architecture 제거. `ReactHost` + `ReactSurface` 단일 모델 |
| D-2 | Hermes | **ON** | RN 0.71+ 기본값. RN 0.83 + Android compileSdk 36 / minSdk 24 환경에서 검증됨 |
| D-3 | URI 스킴 | **`lifeplus-sandbox`** | 기존 iOS/Android의 `lifeplus-tribes`와 분리. 본 레포 통합 단계에서 재논의 |
| D-4 | iOS Deployment Target | **iOS 15.0** | RN 0.74 안전선. 본 레포(`LifePlusTribesApp`) Tuist 추출값과 비교 필요 |
| D-5 | Android minSdk | **24** | RN 0.74 권장. 본 레포 28과 다르지만 sandbox-poc는 보수적 최소값 |
| D-6 | iOS UI 프레임워크 | **UIKit + Storyboard** | 본 레포는 SwiftUI + UIKit lifecycle. MVP는 UIKit 단독이 가장 빠름 |
| D-7 | Android UI 프레임워크 | **View System** | 본 레포는 Compose. MVP는 View System으로 단순화. `AndroidView` 래핑 부담 회피 |
| D-8 | iOS 의존성 관리 | **CocoaPods** | 본 레포는 Tuist + SPM. MVP는 RN 공식 가이드 그대로 따라가는 CocoaPods가 가장 짧은 경로 |
| D-9 | Android 모듈 구조 | **단일 모듈** | 본 레포는 `:app / :presentation / :domain / :data` 4모듈. MVP는 분리할 가치 없음 |
| D-10 | Bundle ID / Package | iOS `com.lifeplus.sandbox`, Android `com.lifeplus.sandbox` | sandbox 전용. 본 레포와 분리 |
| D-11 | RN Module Name | **`HelloRN`** | RN CLI init 기본값. MVP 종료 시까지 변경 없음 |
| D-12 | Metro 사용 | **NO** (정적 번들만) | DoD-4가 RN 런타임 부팅만 요구. Metro는 Phase 1 본작업 |

---

## 추후 재확인 필요 (본작업 진입 전)

- [ ] iOS Tuist `Project.swift`에서 Deployment Target 실제값 추출 → D-4 갱신
- [ ] RN 0.74.5가 Android compileSdk 36 (본 레포)에서 빌드되는지 확인 → D-1 갱신
- [ ] Swift 6 strict concurrency 환경에서 RN ObjC bridge 통과 여부 → D-1, D-8 갱신
- [ ] 본 레포 통합 시 `lifeplus-sandbox` 스킴이 기존 `lifeplus-tribes`와 함께 등록 가능한지 → D-3 갱신
- [ ] AppsFlyer DeepLinkIngressQueue 동작과 RN 진입 순서 충돌 여부 (iOS 분석 6.1 참조)
- [ ] `singleTop` 유지 vs `singleTask` 변경 (Android 분석 6.1 참조)

---

## 회고 (2026-05-11)

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

- **D-1 (RN 버전)**: 0.74.5로 확정. Android 빌드 통과 — Hermes + compileSdk(루트 ext에서 default 34) 호환됨
- **D-2 (Hermes)**: ON 확정. gradle.properties `hermesEnabled=true` 기본값으로 빌드 통과
- **D-7 (Android UI)**: View System + `FrameLayout` 컨테이너 + AppCompatActivity → 의도대로 동작
- **D-12 (Metro 미사용)**: `getJSBundleFile() = "assets://main.jsbundle"` + `getUseDeveloperSupport = false`로 확정. APK에 정적 번들 포함 확인

### RN 0.83 업그레이드 회고 (2026-05-11)

1. **incremental upgrade(0.74→0.78→0.80→...)를 시도하지 않고 fresh init이 정답이었다**
   - 0.74 → 0.83 점프는 ReactNativeHost 제거 / autolinking 변경 / SoLoader 변경 / Hermes 통합 변경 등 깨지는 곳이 너무 많음
   - HelloRN을 RN CLI로 새로 init한 후 sandbox 코드를 그 위에 다시 입히는 패턴이 가장 안전

2. **자체 Fragment + ReactSurfaceView 구현은 함정**
   - 처음 RN 0.83에서 `host.createSurface().start()` → `surface.view`를 Fragment에 add했을 때 화면이 흰 채로 안 그려졌음. ReactHost lifecycle (`onHostResume/Pause/Destroy`) 연결 누락으로 Fabric renderer가 surface 측정/렌더링을 시작 안 함
   - **정답은 RN 공식 `com.facebook.react.ReactFragment` 사용.** `ReactFragment.Builder().setComponentName(...).setLaunchOptions(...).setFabricEnabled(true).build()` 한 줄로 ReactSurface 생성/attach/lifecycle 모두 RN이 처리
   - 단 호스트 Activity가 **`DefaultHardwareBackBtnHandler`를 구현해야 함** — onResume에서 ClassCastException 발생

3. **Toss Granite로부터 흡수한 것 (Granite 자체는 도입하지 않음)**
   - RN 0.84 + React 19.2.3 catalog (우리의 RN 0.83.2 + React 19.2.1 결정의 reality-check)
   - brownfield 시나리오는 RN 공식 `ReactFragment`만 잘 쓰면 충분 — 별도 helper 불필요
   - 참고: [callstack/react-native-brownfield](https://github.com/callstack/react-native-brownfield)도 RN 0.76+ Fast Refresh 호환 helper. 필요해지면 도입 검토

### 다음 스프린트 보강 항목

1. **iOS 마무리** (별도 한나절~1일)
   - Xcode에서 SandboxApp 프로젝트 생성 (UIKit Storyboard, iOS 15, Swift)
   - `ios-wip/SandboxApp/*.swift`와 `RN/main.jsbundle`을 새 프로젝트로 import
   - Podfile은 `ios-wip/Podfile` 그대로 사용
   - Info.plist에 `CFBundleURLTypes` 추가
   - 시뮬레이터 검증 → DoD 4종

2. **Android 에뮬레이터 검증** (반나절)
   - `adb install app-debug.apk` → DevTool 화면 노출 확인 (DoD-2)
   - `adb shell am start -W -a android.intent.action.VIEW -d "lifeplus-sandbox://HelloRN"` → 파싱 로그 + RN 화면 노출 (DoD-3, DoD-4)
   - `adb logcat -s sandbox-poc:*` 로 파싱 로그 캡처

3. **Phase 1 본작업 진입 항목**
   - DevTool에 Metro IP 입력 + SharedPreferences/UserDefaults 저장
   - `getJSBundleFile()`을 Debug build variant에서는 Metro URL로 분기
   - `NavBridge` NativeModule 추가 (JS → Native pop/replace)
   - InitialProps 확장 (`initialParams`, `platform`, `appVersion`, `isDarkMode`)
