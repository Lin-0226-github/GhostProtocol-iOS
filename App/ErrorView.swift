import UIKit

/// 加载失败时的兜底页面：图标 + 原因 + 重试
final class ErrorView: UIView {

    var onRetry: (() -> Void)?

    private let stack = UIStackView()
    private let iconView = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = Theme.background
        translatesAutoresizingMaskIntoConstraints = false

        iconView.tintColor = Theme.secondaryText
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "连接失败"
        titleLabel.textColor = Theme.primaryText
        titleLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        titleLabel.textAlignment = .center

        messageLabel.textColor = Theme.secondaryText
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        retryButton.setTitle("重新加载", for: .normal)
        retryButton.setTitleColor(Theme.accent, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(retryButton)
        stack.setCustomSpacing(18, after: iconView)
        stack.setCustomSpacing(22, after: messageLabel)

        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
        ])
    }

    func show(message: String) {
        messageLabel.text = message
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}
