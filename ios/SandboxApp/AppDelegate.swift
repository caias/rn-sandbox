import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()
    delegate.dependencyProvider = RCTAppDependencyProvider()
    let factory = RCTReactNativeFactory(delegate: delegate)

    // shared.bundle 을 미리 평가해 RCTHost / RCTInstance 가 살아있게 prewarm.
    // 그래야 URI 진입 시점에 PageBundleLoader 가 즉시 callFunctionOnBufferedRuntimeExecutor 사용 가능.
    // moduleName 은 dummy. surface 를 window 에 mount 안 해도 RN runtime 은 start 됨.
    // (rootViewFactory.view(...) 첫 호출이 RCTHost.start 를 트리거)
    _ = factory.rootViewFactory.view(
      withModuleName: "__prewarm",
      initialProperties: nil,
      launchOptions: launchOptions
    )

    reactNativeDelegate = delegate
    reactNativeFactory = factory

    let window = UIWindow(frame: UIScreen.main.bounds)
    let nav = UINavigationController(rootViewController: DevToolViewController())
    nav.interactivePopGestureRecognizer?.isEnabled = true
    window.rootViewController = nav
    window.makeKeyAndVisible()
    self.window = window

    if let url = launchOptions?[.url] as? URL {
      handle(url: url, in: nav)
    }
    return true
  }

  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard let nav = window?.rootViewController as? UINavigationController else { return false }
    return handle(url: url, in: nav)
  }

  @discardableResult
  private func handle(url: URL, in nav: UINavigationController) -> Bool {
    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let appName = comps?.host ?? ""
    let path = (comps?.path.isEmpty == false) ? comps!.path : "/"
    var params: [String: String] = [:]
    comps?.queryItems?.forEach { item in
      params[item.name] = item.value ?? ""
    }
    NSLog("[sandbox-poc] open url=\(url.absoluteString) appName=\(appName) path=\(path) params=\(params)")

    let vc = RNContainerViewController(
      factory: reactNativeFactory,
      appName: appName.isEmpty ? "HelloRN" : appName,
      initialPath: path,
      params: params
    )
    nav.pushViewController(vc, animated: true)
    return true
  }
}

// SandboxReactNativeDelegate (Obj-C++) 가 hostDidStart 를 가로채 PageBundleLoader 에
// RCTInstance 를 캡처시킨다. Swift 측은 base class 만 교체하고 평소대로 bundleURL 등 override.
class ReactNativeDelegate: SandboxReactNativeDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
    // 진입 우선순위:
    //   1) shared.bundle.js  ← apps/native deploy:ios 의 정식 산출물 (multi-bundle 모드)
    //                          PageBundleLoader 가 진입 시 page bundle 을 동적 평가.
    //   2) main.jsbundle     ← bundle:mono 회귀 검증용. shared+pages concat.
    //   3) Metro             ← DEBUG 빌드 + 1/2 둘 다 없을 때 마지막 fallback.
    if let shared = Bundle.main.url(forResource: "shared.bundle", withExtension: "js") {
      return shared
    }
    if let mono = Bundle.main.url(forResource: "main", withExtension: "jsbundle") {
      return mono
    }
#if DEBUG
    return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    return nil
#endif
  }
}
