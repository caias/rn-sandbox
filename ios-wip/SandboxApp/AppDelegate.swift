import UIKit
import React

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        let root: UIViewController
        #if DEBUG
        root = DevToolViewController()
        #else
        root = DevToolViewController()
        #endif
        let nav = UINavigationController(rootViewController: root)
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
        let path = comps?.path.isEmpty == false ? comps!.path : "/"
        var params: [String: String] = [:]
        comps?.queryItems?.forEach { item in
            params[item.name] = item.value ?? ""
        }
        NSLog("[sandbox-poc] open url=\(url.absoluteString) appName=\(appName) path=\(path) params=\(params)")

        let vc = RNContainerViewController(
            appName: appName.isEmpty ? "HelloRN" : appName,
            initialPath: path,
            params: params
        )
        nav.pushViewController(vc, animated: true)
        return true
    }
}
