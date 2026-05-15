import UIKit
import React
import React_RCTAppDelegate

/// URI 진입 시 모듈명 단위 RN surface 를 마운트하는 컨테이너.
///
/// 동작 (Android `MainActivity.loadPageBundle` 의 iOS 짝):
///   1. shared.bundle 은 부팅 시 RCTReactNativeFactory 가 이미 평가 (AppDelegate.bundleURL → assets/shared.bundle.js)
///   2. 진입 시 page bundle (assets/pages/{appName}.bundle.js) 을 PageBundleLoader 가 평가
///      → `AppRegistry.registerComponent(appName, ...)` 발화
///   3. factory.rootViewFactory.view(withModuleName:...) 로 surface 마운트
///   4. 두번째 진입부터는 loadedPages 캐시로 skip
///
/// decisions.md D-22 의 iOS 짝. Re.Pack ScriptManager.mm 패턴을 PageBundleLoader 로 축소.
final class RNContainerViewController: UIViewController {

    /// 이미 평가된 page bundle 의 moduleName. 두번째 진입부터 re-evaluate 안 함.
    /// AppRegistry.registerComponent 가 idempotent 라 정답은 같지만 evaluate 비용 절약.
    private static var loadedPages = Set<String>()

    private let factory: RCTReactNativeFactory?
    private let appName: String
    private let initialPath: String
    private let params: [String: String]

    init(
        factory: RCTReactNativeFactory?,
        appName: String,
        initialPath: String,
        params: [String: String] = [:]
    ) {
        self.factory = factory
        self.appName = appName
        self.initialPath = initialPath
        self.params = params
        super.init(nibName: nil, bundle: nil)
        self.title = appName
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        guard let factory = factory else {
            mountError("❌ RCTReactNativeFactory 누락")
            return
        }

        // 이미 평가된 page 면 즉시 surface mount. AppRegistry 에 entry 가 살아있어야 함.
        if Self.loadedPages.contains(appName) {
            NSLog("[sandbox-poc] page already loaded, mounting directly: %@", appName)
            mountSurface(factory: factory)
            return
        }

        // bundle URL 찾기. HelloRN.bundle.js / detail.bundle.js / ...
        guard let pageURL = pageBundleURL(for: appName) else {
            // mono 회귀 모드: shared.bundle 평가 시 모든 page 가 이미 AppRegistry 에 들어가 있음.
            // 그 경우 별도 page bundle 평가 없이 바로 surface mount 가 맞음.
            NSLog("[sandbox-poc] no separate page bundle for %@ — assuming mono mode", appName)
            Self.loadedPages.insert(appName)
            mountSurface(factory: factory)
            return
        }

        // RN 0.83 Bridgeless 에서는 RCTBridge 가 deprecated.
        // PageBundleLoader 가 AppDelegate.hostDidStart 시점에 캐치한 RCTInstance 를
        // static 으로 보관하고 있어 별도 인자 없이 호출 가능.
        NSLog("[sandbox-poc] loading page bundle: %@", pageURL.absoluteString)
        PageBundleLoader.evaluatePageBundle(at: pageURL) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.mountError("❌ page bundle eval failed: \(error.localizedDescription)")
                return
            }
            Self.loadedPages.insert(self.appName)
            NSLog("[sandbox-poc] page bundle evaluated: %@", self.appName)
            self.mountSurface(factory: factory)
        }
    }

    private func pageBundleURL(for moduleName: String) -> URL? {
        // pages/{moduleName}.bundle.js — Xcode folder reference 로 .app 안에 디렉토리째 들어감.
        return Bundle.main.url(
            forResource: "\(moduleName).bundle",
            withExtension: "js",
            subdirectory: "pages"
        )
    }

    private func mountSurface(factory: RCTReactNativeFactory) {
        let rnView = factory.rootViewFactory.view(
            withModuleName: appName,
            initialProperties: buildInitialProps(),
            launchOptions: nil
        )
        rnView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rnView)
        NSLayoutConstraint.activate([
            rnView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rnView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rnView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rnView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        NSLog("[sandbox-poc] mounted RN surface moduleName=\(appName) initialPath=\(initialPath) params=\(params)")
    }

    /// MainActivity.buildInitialProps 의 iOS 대응. 시스템 키 + URI query 평탄화.
    private func buildInitialProps() -> [String: Any] {
        let reserved: Set<String> = ["initialPath", "platform", "appVersion"]
        var props: [String: Any] = [
            "initialPath": initialPath,
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        ]
        for (k, v) in params {
            if reserved.contains(k) {
                NSLog("[sandbox-poc] skipping reserved query key=\(k)")
                continue
            }
            props[k] = v
        }
        return props
    }

    private func mountError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        NSLog("[sandbox-poc] %@", message)
    }
}
