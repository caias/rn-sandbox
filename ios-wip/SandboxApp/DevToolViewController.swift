import UIKit

final class DevToolViewController: UIViewController, UITextFieldDelegate {

    private let schemeField = UITextField()
    private let runButton = UIButton(type: .system)
    private let recentLabel = UILabel()

    private let recentKey = "sandbox.recentSchemes"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "DevTool"

        let titleLabel = UILabel()
        titleLabel.text = "Sandbox PoC — DevTool"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        schemeField.placeholder = "lifeplus-sandbox://HelloRN"
        schemeField.text = "lifeplus-sandbox://HelloRN"
        schemeField.borderStyle = .roundedRect
        schemeField.autocapitalizationType = .none
        schemeField.autocorrectionType = .no
        schemeField.delegate = self
        schemeField.translatesAutoresizingMaskIntoConstraints = false

        runButton.setTitle("실행", for: .normal)
        runButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        runButton.translatesAutoresizingMaskIntoConstraints = false

        recentLabel.numberOfLines = 0
        recentLabel.font = .preferredFont(forTextStyle: .footnote)
        recentLabel.textColor = .secondaryLabel
        recentLabel.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, schemeField, runButton, recentLabel].forEach(view.addSubview)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            schemeField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            schemeField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            schemeField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            schemeField.heightAnchor.constraint(equalToConstant: 44),

            runButton.topAnchor.constraint(equalTo: schemeField.bottomAnchor, constant: 12),
            runButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            recentLabel.topAnchor.constraint(equalTo: runButton.bottomAnchor, constant: 24),
            recentLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            recentLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        refreshRecent()
    }

    @objc private func runTapped() {
        guard let raw = schemeField.text, let url = URL(string: raw) else {
            NSLog("[sandbox-poc] invalid URL: \(schemeField.text ?? "")")
            return
        }
        saveRecent(raw)
        refreshRecent()
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        runTapped()
        return true
    }

    private func saveRecent(_ scheme: String) {
        var arr = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        arr.removeAll { $0 == scheme }
        arr.insert(scheme, at: 0)
        if arr.count > 10 { arr = Array(arr.prefix(10)) }
        UserDefaults.standard.set(arr, forKey: recentKey)
    }

    private func refreshRecent() {
        let arr = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        if arr.isEmpty {
            recentLabel.text = "최근 실행 기록 없음"
        } else {
            recentLabel.text = "최근:\n" + arr.map { "• \($0)" }.joined(separator: "\n")
        }
    }
}
