import UIKit
import React

final class RNContainerViewController: UIViewController {

    private let appName: String
    private let initialPath: String
    private let params: [String: String]

    init(appName: String, initialPath: String, params: [String: String] = [:]) {
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

        guard let bundleURL = Bundle.main.url(forResource: "main", withExtension: "jsbundle") else {
            let label = UILabel()
            label.text = "❌ main.jsbundle 누락"
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
            NSLog("[sandbox-poc] main.jsbundle missing from app bundle")
            return
        }

        let rootView = RCTRootView(
            bundleURL: bundleURL,
            moduleName: appName,
            initialProperties: nil,
            launchOptions: nil
        )
        rootView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootView)
        NSLayoutConstraint.activate([
            rootView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}
