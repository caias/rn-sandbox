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

## 추후 재확인 필요

- [ ] iOS Tuist `Project.swift`에서 Deployment Target 실제값 추출 → D-4 갱신
- [ ] Swift 6 strict concurrency 환경에서 RN ObjC bridge 통과 여부 → D-1, D-8 갱신
- [ ] AppsFlyer DeepLinkIngressQueue 동작과 RN 진입 순서 충돌 여부 (iOS 분석 6.1 참조)
- [ ] `singleTop` 유지 vs `singleTask` 변경 (Android 분석 6.1 참조)
- [ ] RN 0.84+ 에서 `loadBundle` public API 가 노출되면 D-14 reflection 제거

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
   - 이 결정의 부산물로 `RNContainerFragment.kt` 가 deprecated. 잔존 파일이지만 더 이상 사용처 없음

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
5. **`RNContainerFragment.kt` 제거** — RN 0.83 ReactFragment 로 대체된 후 잔존. 미사용 코드 정리
