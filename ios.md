# sandbox-poc — iOS 개발자 가이드

> sandbox-poc 의 iOS 컴포넌트: `apps/native` 가 빌드한 JS 번들을 받아 URI 스킴으로 미니앱을 동적 평가·마운트하는 Native Host Shell.
>
> **이 문서만 읽고 macOS 머신에서 처음부터 빌드·실행할 수 있어야 한다**는 것을 목표로 작성함.

---

## 빠른 시작

새 macOS 머신에서 처음 실행하는 경우 순서대로 따라가면 된다.

```bash
# 1) Ruby 환경 (한 번만)
brew install rbenv ruby-build
rbenv install -s 3.2.11
eval "$(rbenv init - zsh)"   # 또는 bash

# 2) sandbox 루트에서 gem 설치
cd /path/to/sandbox
bundle install

# 3) Xcode 26.5 설치 + 라이선스 + iOS simulator runtime (한 번만)
brew install xcodesorg/made/xcodes   # xcodes 미설치 머신에서만 필요
xcodes install 26.5 --select
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS   # iOS 26.5 simulator runtime (~8.5 GB)

# 4) pod install (ios/ 디렉토리에서)
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
cd /path/to/sandbox/ios
bundle exec pod install

# 5) page bundle 배치 — sandbox 에 이미 커밋돼 있으면 skip. 갱신 시 apps/native 에서:
#    cd path/to/life/apps/native && yarn deploy:ios /path/to/sandbox
#    → ios/SandboxApp/{shared.bundle.js, pages/{HelloRN,detail}.bundle.js} 자동 복사
#    → Xcode 에서 folder reference (파란 아이콘) 로 추가됐는지 확인 (D-27 — group reference 는 pages/ 디렉토리를 flat 처리해 Bundle lookup 실패)

# 6) 빌드 + 시뮬레이터 실행 (cwd: /path/to/sandbox/ios)
cd /path/to/sandbox/ios
bundle exec xcodebuild \
  -workspace SandboxApp.xcworkspace \
  -scheme SandboxApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath build \
  build

# 디바이스 사전 확인 (Xcode 26.5 + iOS 26.5 runtime 설치 시 기본으로 생성됨, 없으면 xcrun simctl create)
xcrun simctl list devices | grep "iPhone 17 Pro"
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
# 아래 경로도 ios/ 디렉토리 기준 상대경로
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/SandboxApp.app
xcrun simctl launch booted com.lifeplus.sandbox
xcrun simctl openurl booted "lifeplus-tribes://detail?orderId=ABC123"
```

성공 시 콘솔에:

```
[sandbox-poc] open url=lifeplus-tribes://detail?orderId=ABC123 appName=detail path=/ params=["orderId":"ABC123"]
[sandbox-poc] loading page bundle: file://.../pages/detail.bundle.js
[PageBundleLoader] captured RCTInstance: 0x...
[sandbox-poc] page bundle evaluated: detail
[sandbox-poc] mounted RN surface moduleName=detail initialPath=/ params=["orderId":"ABC123"]
```

---

## 사전 요구 매트릭스

| 항목 | 버전 | 비고 |
|---|---|---|
| **macOS** | **26.2+ Tahoe** | Xcode 26.4~26.5 의 minimum macOS. Sequoia 15.6 이라면 Xcode 26.0~26.3 까지 가능 (App Store 제출은 Xcode 26 필수) |
| **Xcode** | **26.5** (권장) | RN 0.83 은 Xcode 16.1+ 요구. App Store 제출은 2026-04-28 이후 Xcode 26(iOS 26 SDK) 의무. `xcodes` 로 설치 권장 |
| **iOS Simulator runtime** | **iOS 26.5** | Xcode 26.5 설치 시 default SDK 만 들어옴. simulator runtime 은 별도 다운로드 필요 (`xcodebuild -downloadPlatform iOS`) |
| **Ruby** | **3.2.11** (rbenv 권장) | macOS system Ruby 2.6 은 ffi 1.17+ 호환 불가. `.ruby-version` 이 sandbox 루트에 있어 rbenv 가 자동 픽 |
| **CocoaPods** | **1.16+** (Gemfile 강제) | 1.15.x 는 Ruby 3.2 + macOS 에서 `unicode_normalize` 버그. 1.16 으로 고정 |
| **셸 로케일** | `LANG=en_US.UTF-8` / `LC_ALL=en_US.UTF-8` | `bundle exec pod install` 실행 시 필수. 없으면 Ruby 3.2 가 `Dir.pwd` 를 ASCII-8BIT 로 반환해 CocoaPods 가 죽음 |

macOS × Xcode × App Store 제출 가능 여부:

| Xcode | minimum macOS | RN 0.83 (≥16.1) | App Store 제출 (2026-04+) |
|---|---|---|---|
| 15.4 | Sonoma 14.0 | ❌ | ❌ |
| 16.1 ~ 16.2 | Sonoma 14.5 | ✅ | ❌ |
| 16.3 ~ 16.4 | Sequoia 15.2+ | ✅ | ❌ |
| **26.0 ~ 26.3** | **Sequoia 15.6** | ✅ | ✅ |
| **26.4 ~ 26.5** | **Tahoe 26.2** | ✅ | ✅ (권장) |

---

## 첫 세팅 (한 번만)

### rbenv + Ruby 3.2.11

```bash
brew install rbenv ruby-build
rbenv install -s 3.2.11    # -s: 이미 설치돼 있으면 skip
rbenv local 3.2.11          # sandbox 루트에 .ruby-version 생성 (이미 커밋돼 있음)
eval "$(rbenv init - zsh)"  # bash 라면 bash 로 교체. 셸 프로파일에도 추가 권장
ruby -v                     # ruby 3.2.11 (2024-...) [arm64-darwin...]
```

`.ruby-version` 파일이 sandbox 루트에 이미 커밋돼 있어, rbenv 가 설치됐으면 자동으로 3.2.11 이 선택된다.

### gem 설치

```bash
cd /path/to/sandbox
bundle install
# cocoapods 1.16+, xcodeproj, activesupport 등 설치
# 완료 메시지: Bundle complete! N gems now installed.
```

### Xcode 26.5

`xcodes` 를 사용한다. App Store Xcode 와 공존 가능.

```bash
brew install xcodesorg/made/xcodes
xcodes install 26.5 --select
# 설치 후 /Applications/Xcode-26.5.0.app 이 생기고 xcode-select 자동 전환

sudo xcodebuild -license accept
xcodebuild -runFirstLaunch    # 보조 도구 설치 (일부 환경에서 필요)
```

### iOS 26.5 Simulator Runtime

Xcode 26.5 를 설치해도 **simulator runtime 은 별도 다운로드**가 필요하다. `xcodes install 26.5 --select` 는 Xcode 앱 + iOS 26.5 SDK 만 번들하며 simulator runtime 은 포함하지 않는다 (D-28). 기본 bundle 에는 SDK 만 포함.

```bash
xcodebuild -downloadPlatform iOS
# iOS 26.5 simulator runtime 다운로드. 약 8.5 GB, 시간이 걸림
# 완료 후 Xcode > Settings > Platforms 에서 iOS 26.5 Installed 확인
```

iOS 17 시뮬레이터 추가 verify 절차는 [## multi-version 시뮬레이터 (iOS 17 + 26)](#multi-version-시뮬레이터-ios-17--26) 섹션 참조.

---

## page bundle 배치

**처음 빌드 전 확인**: 현재 sandbox 레포에는 `ios/SandboxApp/shared.bundle.js` 와 `ios/SandboxApp/pages/{HelloRN,detail}.bundle.js` 가 이미 커밋되어 있습니다. 다음 명령으로 확인:

```bash
ls ios/SandboxApp/shared.bundle.js ios/SandboxApp/pages/
```

세 파일이 모두 보이면 그대로 빌드 가능. 새 미니앱을 추가하거나 산출물을 갱신하려면 `apps/native` 에서 `yarn deploy:ios /path/to/sandbox` 를 실행 (Android `deploy:android` 의 짝 — `apps/native/scripts/deploy-ios.ts`).

### 파일 위치

```
ios/SandboxApp/
  shared.bundle.js          ← apps/native 가 빌드한 vendor 번들 (metro-wrap)
  pages/
    HelloRN.bundle.js       ← apps/native 의 src/pages/index.tsx 산출물
    detail.bundle.js        ← apps/native 의 src/pages/detail.tsx 산출물
```

파일명은 `{moduleName}.bundle.js` 형식이어야 한다. URI 스킴의 host 가 moduleName 이고 sandbox 가 이 이름으로 lookup 한다 (D-18 — `lifeplus-tribes://{moduleName}` URI host 를 `AppRegistry.registerComponent` 첫 인자 + 번들 파일명과 1:1 매핑하는 계약, D-27).

### Xcode folder reference 등록 (최초 1회)

`pages/` 디렉토리는 반드시 **folder reference** (파란색 아이콘) 로 추가해야 한다. group reference (노란색 아이콘) 는 디렉토리 구조를 무시하고 파일을 flat 하게 처리하기 때문에 `.app/pages/` 디렉토리가 생기지 않아 `Bundle.main.url(forResource:subdirectory:)` lookup 이 실패한다 (D-27).

1. Xcode 에서 `ios/SandboxApp.xcworkspace` 열기
2. Project navigator 에서 `SandboxApp` 그룹 선택
3. `File > Add Files to "SandboxApp"...`
4. `ios/SandboxApp/pages` 폴더 선택 → **"Create folder references"** 선택 (기본값 "Create groups" 가 아니라)
5. `shared.bundle.js` 는 파일 단독으로 Add (folder reference 불필요)

이미 등록돼 있다면 Xcode project navigator 에서 `pages` 옆 아이콘이 파란색인지 확인.

### 새 미니앱 번들 추가

```bash
# apps/native 에서 새 page bundle 빌드 후
cp path/to/life/apps/native/dist/pages/ios/newPage.bundle.js \
   ios/SandboxApp/pages/newPage.bundle.js
```

Xcode folder reference 로 `pages/` 를 등록했으면 **디렉토리 안의 파일을 추가하는 것만으로 자동 포함**된다. pbxproj 재편집 불필요.

---

## 빌드 + 시뮬레이터 실행

### pod install

반드시 sandbox 루트에서 `LANG` 환경변수를 지정한 뒤 `ios/` 디렉토리에서 실행한다.

```bash
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
cd /path/to/sandbox/ios
bundle exec pod install
```

성공 시 출력 끝에:

```
patched fmt/base.h: FMT_USE_CONSTEVAL forced 0 for Xcode 26
[!] Please close any current Xcode sessions and use `SandboxApp.xcworkspace` for this project from now on.
Pod installation complete! There are N dependencies from the Podfile ...
```

`patched fmt/base.h` 로그가 없으면 Podfile post_install 훅이 안 돌아간 것이다. [ios/Podfile](ios/Podfile) 을 확인.

### xcodebuild (CLI)

```bash
cd /path/to/sandbox/ios
bundle exec xcodebuild \
  -workspace SandboxApp.xcworkspace \
  -scheme SandboxApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath build \
  build
```

빌드 성공 시:

```
** BUILD SUCCEEDED **
```

### 시뮬레이터 부팅 + 앱 설치 + URI 진입

```bash
# 디바이스 사전 확인
# Xcode 26.5 + iOS 26.5 simulator runtime 설치 시 "iPhone 17 Pro" 디바이스가 기본으로 생성된다.
# 목록에 없으면 xcrun simctl create "iPhone 17 Pro" "iPhone 17 Pro" "iOS 26.5" 로 수동 생성.
xcrun simctl list devices | grep "iPhone 17 Pro"

# 시뮬레이터 부팅
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator

# 앱 설치
xcrun simctl install booted \
  build/Build/Products/Debug-iphonesimulator/SandboxApp.app

# 앱 실행
xcrun simctl launch booted com.lifeplus.sandbox

# URI 스킴 진입
xcrun simctl openurl booted "lifeplus-tribes://HelloRN"
xcrun simctl openurl booted "lifeplus-tribes://detail?orderId=ABC123"
```

### Xcode GUI 빌드

```bash
cd /path/to/sandbox/ios
xed -b .    # SandboxApp.xcworkspace 열기 + 빌드 scheme 자동 선택
```

또는 직접:

```bash
open SandboxApp.xcworkspace
```

Scheme `SandboxApp`, destination `iPhone 17 Pro (iOS 26.5)` 선택 후 ⌘R.

### pbxproj 에 새 Swift / ObjC++ 파일 추가

기존 소스 파일 외에 새 파일을 추가해야 할 때:

1. [ios/add_swift_sources.rb](ios/add_swift_sources.rb) 에 파일 경로 항목 추가
2. `bundle exec ruby ios/add_swift_sources.rb` 실행 (멱등, 이미 등록된 파일은 skip)

---

## multi-version 시뮬레이터 (iOS 17 + 26)

Xcode 26.5 + iOS 26.5 SDK 로 빌드된 `.app` (deployment target 15.1) 은 **iOS 17 시뮬레이터에도 install 가능**하다. 단일 빌드 산출물로 iOS 17 ~ 26 매트릭스를 검증할 수 있다.

### iOS 17.5 simulator runtime 확인

```bash
xcrun simctl runtime list
# iOS 17.5 (21F79) - com.apple.CoreSimulator.SimRuntime.iOS-17-5 (Ready) ...
```

`(Ready)` 상태이면 추가 다운로드 없이 사용 가능. Xcode 16.x 가 남긴 runtime 이 시스템 catalog 에 남아있을 수 있다.

### iOS 17 시뮬레이터에 install + 실행

```bash
# iOS 17.5 시뮬레이터 기기 이름 확인
xcrun simctl list devices | grep -i "17"
# 예: iPhone 15 Pro (XXXXXXXX-XXXX-...) (Shutdown) -- iOS 17.5

# 시뮬레이터 부팅
xcrun simctl boot "iPhone 15 Pro"

# 기존 빌드 산출물 (iOS 26.5 SDK 로 빌드된 것) 그대로 install
xcrun simctl install "iPhone 15 Pro" \
  build/Build/Products/Debug-iphonesimulator/SandboxApp.app
```

### iOS 17 의 `openurl` 다이얼로그 회피

iOS 17 에서는 새 launch session 으로 URI 를 열 때 **"Sandbox에서 열겠습니까?" 사용자 동의 다이얼로그**가 뜬다. 자동화 검증 중단을 막으려면 **앱 프로세스가 살아있는 상태**에서 openurl 을 호출해야 한다 (same-process self-invocation 패턴). iOS 26 에서는 이 다이얼로그가 없다.

```bash
# 앱을 백그라운드로 띄워두고
xcrun simctl launch --console "iPhone 15 Pro" com.lifeplus.sandbox &

# 프로세스가 살아날 시간을 주고
sleep 5

# 같은 프로세스 위에서 URI 진입
xcrun simctl openurl "iPhone 15 Pro" "lifeplus-tribes://detail?orderId=ABC123"

# 콘솔 출력 확인 후 kill
sleep 6
kill %1
```

`--console` 플래그가 stdout 을 터미널에 직접 연결해주기 때문에 `log show` 없이도 `[sandbox-poc]` NSLog 를 볼 수 있다.

---

## 핵심 파일 좌표

| 파일 | 역할 |
|---|---|
| [ios/SandboxApp/AppDelegate.swift](ios/SandboxApp/AppDelegate.swift) | `@main`, `RCTReactNativeFactory` + `ReactNativeDelegate`, 부팅 시 RCTInstance prewarm, `application(_:open:options:)` URI 파싱 + 라우팅 |
| [ios/SandboxApp/RNContainerViewController.swift](ios/SandboxApp/RNContainerViewController.swift) | URI 진입 시 page bundle 평가 요청 + RN surface mount, `loadedPages: Set<String>` 캐시, `buildInitialProps` |
| [ios/SandboxApp/PageBundleLoader.h](ios/SandboxApp/PageBundleLoader.h) | ObjC++ public interface — Swift 측이 import 하는 헤더 |
| [ios/SandboxApp/PageBundleLoader.mm](ios/SandboxApp/PageBundleLoader.mm) | ObjC++ 구현 — `captureRCTInstanceFromHost:` (ivar reflection), `evaluatePageBundleAtURL:completion:` (`callFunctionOnBufferedRuntimeExecutor`), `waitForRCTInstanceWithTimeout:` polling |
| [ios/SandboxApp/SandboxApp-Bridging-Header.h](ios/SandboxApp/SandboxApp-Bridging-Header.h) | Swift ↔ ObjC++ 브릿지. `PageBundleLoader.h` + `SandboxReactNativeDelegate.h` import. `RCTHost.h` 는 여기에 넣으면 C++ STL 오류 (D-25 — `RCTHost.h` 가 C++ STL 을 전이 포함해 Swift bridging header 에서 `'string' file not found` 컴파일 오류 발생) |
| [ios/SandboxApp/LifePlusApp.h](ios/SandboxApp/LifePlusApp.h) / [.mm](ios/SandboxApp/LifePlusApp.mm) | `@lifeplus/native-bridge` 의 `NativeModules.LifePlusApp` sandbox reference 구현. `RCT_EXPORT_MODULE(LifePlusApp)` + `back` (UINavigationController popViewController / root no-op) + `share` (UIActivityViewController). 본 앱 통합 시 호스트별 새 구현체로 대체 (decisions.md D-33) |
| [ios/SandboxApp/DevToolViewController.swift](ios/SandboxApp/DevToolViewController.swift) | URI 직접 입력 UI + 최근 실행 목록. 앱 첫 진입 시 (URI 없이 런처에서 열 때) 자동 노출 |
| [ios/SandboxApp/Info.plist](ios/SandboxApp/Info.plist) | `CFBundleURLTypes` — `lifeplus-tribes` 스킴 등록 |
| [ios/Podfile](ios/Podfile) | post_install 워크어라운드 (D-28): `SWIFT_ENABLE_EXPLICIT_MODULES=NO` + `fmt/base.h FMT_USE_CONSTEVAL` 헤더 패치 |
| [ios/add_swift_sources.rb](ios/add_swift_sources.rb) | xcodeproj gem 으로 pbxproj 에 Swift/ObjC++ 파일 멱등 등록 |
| [ios/add_multibundle_resources.rb](ios/add_multibundle_resources.rb) | `shared.bundle.js` + `pages/` folder reference 를 pbxproj 에 멱등 등록 |

---

## apps/native 와의 계약

sandbox 의 iOS 측이 `apps/native` 빌드 산출물을 어떻게 소비하는지 정의한 계약. 양쪽 중 한쪽이 바뀌면 이 표와 같이 반영해야 한다.

| 항목 | 값 | 위치 |
|---|---|---|
| JS 부팅 번들 | `Bundle.main.url(forResource:"shared.bundle", withExtension:"js")` | `AppDelegate.bundleURL` |
| 미니앱 번들 | `Bundle.main.url(forResource:"{moduleName}.bundle", withExtension:"js", subdirectory:"pages")` | `RNContainerViewController.pageBundleURL` |
| 동적 평가 진입점 | `RCTInstance.callFunctionOnBufferedRuntimeExecutor` → `runtime.evaluateJavaScript(StringBuffer, sourceUrl)` | `PageBundleLoader.mm` |
| RCTInstance 캡처 | `RCTHost._instance` ivar reflection (`class_getInstanceVariable(host, "_instance")`) in `hostDidStart:` | `PageBundleLoader.mm` |
| RCTHost 부팅 시점 | `AppDelegate` 에서 `factory.rootViewFactory.view(withModuleName:"__prewarm",...)` 한 줄로 prewarm | `AppDelegate.swift` |
| Xcode resource | `shared.bundle.js` 단일 파일 + `pages/` folder reference | `ios/add_multibundle_resources.rb` |
| moduleName | URI host = `AppRegistry.registerComponent` 의 첫 인자 | `AppDelegate.handle(url:in:)` |
| URI 스킴 | `lifeplus-tribes://{moduleName}?{query}` | `Info.plist` `CFBundleURLTypes` |
| InitialProps | `initialPath`, `platform="ios"`, `appVersion`(`CFBundleShortVersionString`) + URI query 평탄화 | `RNContainerViewController.buildInitialProps` |

InitialProps 예:

```
lifeplus-tribes://detail/path/x?orderId=ABC123&tab=1
  ↓
{
  initialPath: "/path/x",
  platform: "ios",
  appVersion: "1.0",
  orderId: "ABC123",
  tab: "1",
}
```

RESERVED_KEYS = `{initialPath, platform, appVersion}` — URI query 가 같은 키를 갖고 있으면 무시하고 로그 경고.

---

## multi-bundle 동작 (최소 정보)

iOS 측 평가 시퀀스. 디버깅할 때 이 흐름을 따라가면 된다.

```
1. prewarm (AppDelegate.didFinishLaunchingWithOptions)
   └ factory.rootViewFactory.view(withModuleName: "__prewarm", ...)
   └ RCTHost.start 트리거 → shared.bundle.js 평가 → RCTInstance 생성

2. RCTInstance 캡처 (SandboxReactNativeDelegate.hostDidStart:)
   └ class_getInstanceVariable(host, "_instance") → gRctInstance 에 보관
   └ [PageBundleLoader] captured RCTInstance: 0x...

3. URI 진입 (AppDelegate.application(_:open:options:))
   └ host = moduleName, query 파싱 → RNContainerViewController push

4. page bundle lookup (RNContainerViewController)
   └ loadedPages.contains(appName) ?
       → true : mountSurface 즉시 (warm path, D-26 — 동일 moduleName 재진입 시 page bundle 재평가 없이 surface 재사용)
       → false : PageBundleLoader.evaluatePageBundleAtURL 호출 (cold path)

5. page bundle 평가 (PageBundleLoader.mm)
   └ gRctInstance 가 nil 이면 16ms 단위 polling (최대 5s 가드)
   └ callFunctionOnBufferedRuntimeExecutor:^(jsi::Runtime &rt) {
         rt.evaluateJavaScript(StringBuffer(source), sourceURL)
     }
   └ page bundle 안 AppRegistry.registerComponent(moduleName, ...) 호출됨

6. surface mount (RNContainerViewController.mountSurface)
   └ factory.rootViewFactory.view(withModuleName: appName, initialProperties: ...)
   └ loadedPages 에 appName 추가
   └ view 를 UIViewController 에 embed → UINavigationController push
```

iOS 측 모든 ObjC++ 연산 (`RCTHost.h`, `jsi/jsi.h`, `RCTInstance.h`) 은 `PageBundleLoader.mm` 에 격리돼 있다. Swift 코드는 `SandboxReactNativeDelegate` (ObjC++ base class) 를 상속하는 것 외에는 C++ 타입을 직접 다루지 않는다 (D-25).

---

## 트러블슈팅

빌드 / 런타임 / 환경 단계에서 만나는 증상별 조치.

> 발생한 에러를 보고 해결책을 찾는 트러블슈팅 가이드.

### 빌드 오류

| 증상 | 원인 | 조치 |
|---|---|---|
| `xcodebuild build` 시 `fmt/format-inl.h: call to consteval function ... is not a constant expression` 5개 에러 | Apple clang 21 (Xcode 26) 의 strict consteval 이 fmt 11.0.2 의 `FMT_STRING` 매크로를 거부 (D-28, facebook/react-native#55601) | `bundle exec pod install` 을 다시 실행. Podfile post_install 이 `fmt/base.h` 를 자동 패치. 출력에 `patched fmt/base.h: FMT_USE_CONSTEVAL forced 0 for Xcode 26` 이 있어야 함 |
| `Ineligible destination ... iOS 26.5 is not installed` | Xcode 26.5 가 default SDK 만 번들. simulator runtime 미설치 | `xcodebuild -downloadPlatform iOS` 로 iOS 26.5 simulator runtime 추가 다운로드 (~8.5 GB) |
| `Bridging header fatal error: 'string' file not found` | `SandboxApp-Bridging-Header.h` 에 C++ STL 을 끌어오는 헤더 (`RCTHost.h`, `RCTInstance.h` 등) 를 직접 import 했을 때 | bridging header 에는 `PageBundleLoader.h` 와 `SandboxReactNativeDelegate.h` 만 남겨야 함. C++ 의존 헤더는 `PageBundleLoader.mm` 안에서만 import (D-25) |
| `cannot find type 'RCTHost' in scope` (Swift 소스에서) | Swift 에서 `RCTHost` 를 직접 import 하려 했을 때 — `RCTHost.h` 가 C++ STL 때문에 bridging 불가 | Swift 에서 `RCTHost` 를 직접 쓰지 말고 `ReactNativeDelegate: SandboxReactNativeDelegate` 상속 패턴을 유지. `hostDidStart:` 는 ObjC++ 측이 가로챔 (D-25) |
| `Build input files cannot be found: SandboxApp/X.swift` | pbxproj 의 파일 경로가 실제 디스크와 불일치 | `ios/add_swift_sources.rb` 의 path 항목을 `SandboxApp/X.swift` 형태로 확인 후 `bundle exec ruby ios/add_swift_sources.rb` 재실행 |
| `main.jsbundle: No such file or directory` | 이전 mono 검증 단계에서 등록한 file_ref 가 pbxproj 에 잔존 | `bundle exec ruby ios/remove_mono_jsbundle_ref.rb` 실행 (멱등) |
| `SWIFT_ENABLE_EXPLICIT_MODULES` 관련 모듈 충돌 빌드 오류 | RN 0.83 의 일부 ObjC++ 헤더가 Swift Explicit Modules 와 충돌 (D-28) | `bundle exec pod install` 재실행. Podfile post_install 이 `SWIFT_ENABLE_EXPLICIT_MODULES = NO` 를 자동 설정 |

### 런타임 오류

| 증상 | 원인 | 조치 |
|---|---|---|
| `[sandbox-poc] ❌ page bundle eval failed: RCTInstance not captured` | `hostDidStart:` 가 아직 호출 안 됨. `gRctInstance == nil`. AppDelegate 의 prewarm 호출 누락 또는 너무 빠른 URI 진입 | (1) `AppDelegate.swift` 의 `factory.rootViewFactory.view(withModuleName:"__prewarm",...)` 한 줄이 있는지 확인 (D-23 — 앱 시작 시점에 `RCTHost.start` 를 강제 트리거해 `hostDidStart:` 가 URI 진입 전에 발화되도록 보장). (2) `PageBundleLoader.mm` 의 `waitForRCTInstanceWithTimeout:` polling 이 살아있는지 확인 |
| `[PageBundleLoader] ❌ RCTHost has no _instance ivar` | RN 업그레이드로 `RCTHostImpl` 의 private ivar 이름이 바뀜 | `PageBundleLoader.mm` 의 `class_getInstanceVariable([host class], "_instance")` 가 찾는 이름 갱신 필요. RN 0.84+ 에서 public API 가 나오면 reflection 제거 (D-24 — `RCTHost` 가 `RCTInstance` 를 공개 API 없이 private ivar 로만 보유해 ObjC runtime reflection 으로 추출하는 임시 방편) |
| `[sandbox-poc] ❌ RCTInstance not captured within timeout (5s)` | `hostDidStart:` 가 5초 안에 발화 안 됨. `RCTHost.start` 가 트리거 안 됐거나 `SandboxReactNativeDelegate` 를 base class 로 상속 안 한 상태 | `AppDelegate.swift` 의 `ReactNativeDelegate` 가 `SandboxReactNativeDelegate` 를 상속하는지 확인 (D-25). AppDelegate 의 prewarm 호출 확인 (D-23) |
| `No script URL provided` redbox | `shared.bundle.js` 가 `.app` 안에 없음. `AppDelegate.bundleURL` 의 `Bundle.main.url(forResource:"shared.bundle",...)` 가 nil → DEBUG 빌드는 Metro fallback 시도, Metro 도 없으면 redbox | `ios/SandboxApp/shared.bundle.js` 파일이 있는지, Xcode 에서 파일 참조로 등록됐는지 확인. 갱신은 `apps/native` 에서 `yarn deploy:ios` 실행 (D-27) |
| `Unable to load page bundle: pages/HelloRN.bundle.js not found` | `pages/` 폴더가 `.app` 안에 없거나 파일명이 moduleName 과 다름 | Xcode 에서 `pages/` 가 **folder reference** (파란 아이콘) 인지 확인. group reference 이면 디렉토리가 flat 처리됨. 파일명이 `{moduleName}.bundle.js` 형식인지 확인 (D-27) |
| `[native-bridge] NativeModules.LifePlusApp not registered (command=back)` | `LifePlusApp` ObjC++ 모듈이 pbxproj 에 등록 안 됐거나 `RCT_EXPORT_MODULE` 누락 | `ios/add_swift_sources.rb` 가 `LifePlusApp.h/.mm` 까지 등록하는지 확인 (FILES 배열에 포함 + `.mm` 은 source build phase). `.mm` 안의 `RCT_EXPORT_MODULE(LifePlusApp)` 매크로 확인 |
| `[native-bridge] NativeModules.LifePlusApp.back is not implemented` | `RCT_REMAP_METHOD(back, ...)` 시그니처 오타 또는 method name mangling 실패 | `RCT_REMAP_METHOD` 의 첫 인자 (JS 이름) 가 `back` 이고 두 번째부터 (`backWith...:`) 가 ObjC selector. JS 이름이 schema 의 `title` 의 lowerCamel 과 일치하는지 확인 |
| native-bridge void 커맨드 호출이 silent reject 또는 warning | `sdk-native.ts` 의 `call(command, params?)` 가 항상 `fn(undefined)` 1-arg 호출. ObjC selector 가 `back:(RCTPromiseResolveBlock)resolve...` 시그니처면 params 자리가 없어 first arg 가 잘못 매칭 | void 커맨드도 시그니처에 first arg 자리를 둔다. 예: `RCT_REMAP_METHOD(back, backWithParams:(NSDictionary*)params resolver:... rejecter:...)` (decisions.md D-30 — Android 와 동일 함정) |

### 환경 오류

| 증상 | 원인 | 조치 |
|---|---|---|
| `ffi-1.17.x requires ruby version >= 3.0` | 시스템 Ruby 2.6 사용 중 | rbenv 로 Ruby 3.2.11 설치 + `rbenv local 3.2.11`. `.ruby-version` 이 이미 sandbox 루트에 커밋됨 |
| `pod install: Encoding::CompatibilityError in installation_root` | `LANG` / `LC_ALL` 미설정. Ruby 3.2 가 `Dir.pwd` 를 ASCII-8BIT 로 반환 | `export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` 후 `pod install` 재시도 |
| `React Native requires XCode >= 16.1. Found 15.x` | pod install 시 `prepare_react_native_project!` 가 Xcode 버전 체크 | Xcode 26.5 설치 + `xcodes select 26.5` (또는 `xcodes install 26.5 --select`) |
| `kLSIncompatibleSystemVersionErr -10825` (Xcode 앱이 안 열림) | 설치된 Xcode 버전이 현재 macOS 보다 높은 버전 요구 | Xcode × macOS 호환 매트릭스 표 참조. macOS 26.2 미만이면 Xcode 26.4+ 설치 불가 |
| `log show` 결과가 `<compose failure [shared UUID]>` 로 가려짐 | macOS 26 의 `os_log` private-data 기본 차단. NSLog format 변수가 private 마킹됨 | `xcrun simctl launch --console booted com.lifeplus.sandbox` 로 stdout 직접 캡처 (평소 권장). 또는 `sudo log config --enable-private-data` — ⚠️ 이 명령은 macOS 전역 보안 정책을 해제하여 모든 앱의 private 로그가 평문 노출됨. 검증용 임시 사용만 권장. |
| (iOS 17) `simctl openurl` 시 "Sandbox에서 열겠습니까?" 다이얼로그 | iOS 17 의 보안 정책 — 새 launch session 으로 URI 진입 시 사용자 동의 요구. iOS 26 에서는 없음 | `launch --console &` 로 백그라운드 부팅 후 `sleep 5` + `openurl` (same-process 패턴). 위 multi-version 시뮬레이터 섹션 참조 |

---

## 알려진 이슈와 배경

코드/패치가 왜 이렇게 짜였는지 배경 — 빌드 중 막혔을 때 *원인* 을 이해하는 자료.

> 설계 결정의 배경과 히스토리는 [decisions.md](decisions.md) 참조.

### Xcode 16.1+ 강제 (RN 0.83)

`node_modules/react-native/scripts/cocoapods/utils.rb` 의 `prepare_react_native_project!` 가 `pod install` 단계에서 Xcode 버전을 체크한다. Xcode 15.x 이하면 즉시 오류로 종료. Xcode 16.1 이상 필수.

### Xcode 26 의무화 (App Store 제출 2026-04+)

Apple 이 2026-02-03 에 발표 (https://developer.apple.com/news/?id=ueeok6yw): **신규 앱 및 업데이트 모두 Xcode 26 (iOS 26 SDK) 빌드 IPA 제출 의무**. 2026-04-28 발효. sandbox 가 본 iOS 레포 (lp-mktplatform-ios) 의 host shell 로 흡수되는 경로에서는 처음부터 Xcode 26.5 로 정렬하는 것이 통합 마찰 최소.

### macOS system Ruby 2.6 비호환

macOS Sonoma / Sequoia 까지 `/usr/bin/ruby` 가 2.6.10 으로 남아있다. `ffi` 1.17+ 가 Ruby 3.0+ 를 요구하고 CocoaPods 가 `ffi` 를 transitive 으로 끌어오기 때문에 system Ruby 로는 `bundle install` 자체가 실패한다. **rbenv + Ruby 3.2.11** 이 현재 검증된 환경.

### CocoaPods 1.15.x `unicode_normalize` 버그

CocoaPods 1.15.0 ~ 1.15.2 는 Ruby 3.2 + macOS 에서 `String#unicode_normalize` 가 `Encoding::CompatibilityError` 를 던진다 (`Dir.pwd` 가 ASCII-8BIT 로 반환되는 환경). [Gemfile](Gemfile) 이 `cocoapods >= 1.16` 으로 핀. 단 `LANG=en_US.UTF-8` 설정이 없으면 1.16+ 도 같은 경로를 탄다.

### fmt 11.0.2 ↔ Apple clang 21 (Xcode 26) consteval 충돌

fmt 11.0.2 의 `FMT_STRING` 매크로가 `__cpp_consteval` 을 auto-enable 하는데, Apple clang 21 (Xcode 26) 이 strict consteval 을 적용해 lambda 안 `compile_string` constructor 호출을 거부한다. 5개 컴파일 에러. RN 이 fmt 를 직접 의존하기 때문에 RN 업그레이드 전까진 회피 불가. [ios/Podfile](ios/Podfile) 의 post_install 훅이 `fmt/base.h` 를 자동 패치한다 (D-28). `pod install` 시마다 재적용. RN 0.84+ 에서 fmt 업그레이드가 이루어지면 제거 가능.

### Swift Explicit Modules (Xcode 26 + RN 0.83)

RN 0.83 의 일부 ObjC++ 헤더가 Swift Explicit Modules 빌드 시스템과 충돌한다 (참조: react-native-community/discussions-and-proposals#978). [ios/Podfile](ios/Podfile) 의 post_install 이 모든 pod target 에 `SWIFT_ENABLE_EXPLICIT_MODULES = NO` 를 적용. `pod install` 이후 자동 반영.

### Xcode 26 SDK ↔ simulator runtime 분리

`xcodes install 26.5 --select` 는 **Xcode 앱 + iOS 26.5 SDK** 만 설치. iOS 26.5 simulator runtime 은 별도. 설치 직후 `xcodebuild build -destination 'OS=26.5'` 를 시도하면 `Ineligible destination: iOS 26.5 is not installed` 로 실패한다. `xcodebuild -downloadPlatform iOS` 로 runtime 을 추가 다운로드해야 한다.

### iOS 17 simulator runtime 과 multi-version verify

Xcode 26.5 + iOS 26.5 SDK 로 빌드된 `.app` (deployment target 15.1) 이 iOS 17 시뮬레이터에서도 동작하는 것이 2026-05-15 검증에서 확인됐다. 빌드 destination 과 install destination 은 무관. iOS 17.5 runtime 이 시스템 catalog 에 살아있으면 재빌드 없이 그대로 install 가능.

### RCTInstance ivar reflection 유효 범위

`class_getInstanceVariable([host class], "_instance")` 는 `RCTHostImpl` 의 private ivar 명에 의존한다. RN 업그레이드 시 ivar 명이 바뀌면 `nil` 을 반환하고 `[PageBundleLoader] ❌ RCTHost has no _instance ivar` 로그가 나온다. RN 0.84+ 에서 public API 가 노출되면 reflection 을 제거한다 (D-24, 추후 확인 필요 항목).

### RN 미니앱 화면에서 native NavigationBar 숨김 (2026-05-21)

sandbox 의 `AppDelegate` 가 모든 화면을 `UINavigationController` 위에 push 하는 구조라, `RNContainerViewController` 가 push 되면 iOS 시스템 NavigationBar (제목 + back chevron) 가 자동 표시된다. apps/native 측 미니앱 (현재 card-test) 이 자체 `Header` 컴포넌트로 동일한 영역을 그리므로 시각적으로 중복이 발생.

**조치**: `RNContainerViewController.viewWillAppear` 에서 `navigationController?.setNavigationBarHidden(true, animated:)` 호출, `viewWillDisappear` 에서 다시 `false` 로 복원. RN 화면에 한정해 nav bar 를 끄고, DevTool 등 다른 native 화면으로 돌아갈 때는 정상 노출.

향후 RN 미니앱이 자체 Header 를 안 그리는 케이스 (예: full-bleed 콘텐츠) 가 생기면 `RNContainerViewController` 가 prop / URL query 로 그 분기를 받아 nav bar 노출 여부를 토글하도록 확장. 현재는 모든 RN 화면이 자체 Header 를 그리는 정책이라 무조건 숨김.

---

## 부록: 새 RN 라이브러리 추가 후 재빌드 (2026-05-21 추가)

RN 진영의 native 의존성을 가진 라이브러리 (예: `react-native-svg`, `react-native-safe-area-context`) 를 미니앱에서 쓰려면 sandbox iOS app 에 그 native module / ViewManager 가 link 되어 있어야 한다. **CocoaPods autolinking (`use_native_modules!`) 이 거의 다 처리하므로 Swift / pbxproj 는 거의 안 만진다.**

### 절차 (iOS)

```bash
# 1. life 모노레포 apps/native 와 sandbox 양쪽 package.json 에 같은 버전 dep 추가 (lockstep)
#    (apps/native 측 작업은 RN 개발자가 담당)

# 2. sandbox node_modules 동기화
cd ~/Desktop/sandbox
npm install                                    # 또는 yarn install

# 3. Pod install — Podfile 의 use_native_modules! 가 새 라이브러리 podspec 을 자동 발견
cd ios
bundle exec pod install                        # rbenv ruby 3.2.11 + bundler 4.0.11 활성 상태에서

# 4. Xcode 빌드 + 시뮬레이터 install
xcodebuild -workspace SandboxApp.xcworkspace -scheme SandboxApp \
  -configuration Debug -sdk iphonesimulator \
  -destination "id=<SIM_UUID>" build
xcrun simctl install booted "<DerivedData>/SandboxApp.app"

# 5. RN 개발자가 yarn deploy:ios 로 새 shared/page bundle 을 ios/SandboxApp/ 에 배치한 뒤,
#    Xcode 를 한 번 더 빌드/install 해야 .app 안에 새 bundle 이 들어간다
```

### Swift / pbxproj 변경이 필요한 케이스 (드묾)

- 라이브러리가 autolinking 대상이 아닌 옛 RN 스타일이거나, native module 을 `RCTBridgeModule` 로 직접 등록해야 하는 경우. 현재 sandbox 의 모든 deps 는 autolinking 또는 sandbox 자체 코드 (`LifePlusApp.h/.mm` 같은 NavBridge native module — `ios/add_swift_sources.rb` 로 멱등 등록) 로 처리되어 있다. 새 라이브러리 추가 시 Pod install 만으로 link 가 안 되면 그 podspec 의 README 를 확인.

### 검증

```bash
# Podfile.lock 에 새 pod 이 등록됐는지
grep "<lib-name>" ios/Podfile.lock

# 시뮬레이터 실행 시 RN 측 로그
xcrun simctl spawn booted log stream --predicate \
  'processImagePath contains "SandboxApp"' --style compact
```

- `[PageBundleLoader] loaded local bundle: ...` 로그까지 정상이면 page bundle 평가 성공
- `Class <RNView> was not exported` 류 에러 → autolinking 실패. `rm -rf ios/Pods ios/build && bundle exec pod install` 후 재시도

### 함정

- **`Ld __preview.dylib` Xcode 26 Linker 워닝**: SwiftUI Preview 용 dylib 빌드 실패 메시지. 실제 앱 빌드와 무관하니 무시 가능
- **mono `main.jsbundle` 잔재**: pbxproj 에 `main.jsbundle` resource 참조가 남아있으면 `CpResource ... No such file or directory` 로 build 실패. `bundle exec ruby remove_mono_jsbundle_ref.rb` 로 멱등 제거
- **Ruby 환경**: 시스템 `ruby 2.6.10` 으로 `bundle exec` 하면 `Could not find 'bundler' (4.0.11)` 에러. `eval "$(rbenv init - zsh)"` 또는 `~/.zshrc` 영구 등록 필요

### 사례

| 날짜 | 추가 라이브러리 | sandbox 측 변경 |
|---|---|---|
| 2026-05-21 | `react-native-svg 15.15.5` | `package.json` dep 한 줄, `pod install`, Xcode 빌드. Swift / pbxproj target 변경 0 (단, mono 잔재 정리로 `remove_mono_jsbundle_ref.rb` 한 번 실행) |

---

## 다음 단계 (Phase 2-2 이후)

| 항목 | 상태 | 비고 |
|---|---|---|
| NavBridge NativeModule | TODO | JS → Native pop/replace. 현재는 iOS `popViewController` 으로 임시 |
| NavBar UI 정리 | TODO | `RNContainerViewController` push 패턴에서 iOS NavBar 와 RN 페이지 색 충돌. 본 앱 host shell 통합 시점에 처리 |
| CDN URL fetch | TODO | page bundle 을 원격 URL 에서 fetch + 캐시. APK/IPA 재배포 없이 미니앱 업데이트 |
| `RCTHost._instance` reflection 제거 | 추후 | RN 0.84+ 에서 second-bundle 평가 표준 API 가 나오면 D-22/D-24 reflection 동시 제거 가능 (D-22 — `callFunctionOnBufferedRuntimeExecutor` 로 추가 번들을 JSI Runtime 에 직접 평가하는 패턴, Android `loadBundle` 리플렉션의 iOS 짝) |
| 본 iOS 레포 `develop-cd.yml` Xcode align | 본 레포 PR 대기 | 2026-05-15 조사 완료 (decisions.md). 현재 `XC_VERSION='14.2'` + `macos-12` 가 P0 통합 이슈 → Xcode 26.5 + `macos-26` 으로 점프 필요. sandbox 측 작업 아님 |

### 완료된 항목

- ~~`apps/native` 의 `yarn deploy:ios`~~ — `apps/native/scripts/deploy-ios.ts` 로 구현됨. `yarn deploy:ios [SANDBOX_PATH]` 가 dist/ 산출물을 `ios/SandboxApp/{shared.bundle.js, pages/*.bundle.js}` 로 복사. Android `deploy:android` 의 짝
- ~~본 iOS 레포 Xcode 버전 핀 조회~~ — 2026-05-15. `mise.toml` Xcode 핀 없음, CI 는 `macos-latest` 소프트 가드, CD 는 `XC_VERSION='14.2'` P0 이슈로 식별

---

## 참고 링크

- [aos.md](aos.md) — Android 빌드 가이드
- [decisions.md](decisions.md) — D-20~D-28 iOS 구현 결정 + 환경 회고 (2026-05-14, 2026-05-15)
- [README.md](README.md) — 공통 아키텍처 + Android 빌드 + 진행 상태
- [apps/native README](https://github.com/lp-mktplatform/life/tree/main/apps/native) — 미니앱 번들 빌드 + deploy 파이프라인
- facebook/react-native#55601 — fmt FMT_USE_CONSTEVAL Xcode 26 이슈
- react-native-community/discussions-and-proposals#978 — Swift Explicit Modules 이슈
- callstack/react-native-sandbox — `RCTInstance.callFunctionOnBufferedRuntimeExecutor` 패턴 레퍼런스
