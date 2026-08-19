import UIKit

final class DropdownDimmerView: UIControl {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.12)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class OverflowDropdownView: UIView {
    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.12, alpha: 0.95)
        layer.cornerRadius = 12
        clipsToBounds = true
        isHidden = true
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embed(buttons: [UIButton]) {
        buttons.forEach { button in
            button.removeFromSuperview()
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 31),
                button.heightAnchor.constraint(equalToConstant: 31)
            ])
            stack.addArrangedSubview(button)
        }
    }
}

final class FilterDropdownView: UIView {
    var onChange: ((MediaFilter) -> Void)?

    private var filter = MediaFilterStore.load()
    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var rows: [FilterRow] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.12, alpha: 0.95)
        layer.cornerRadius = 12
        clipsToBounds = true
        isHidden = true
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            widthAnchor.constraint(equalToConstant: 220)
        ])
        addRow(title: "Photos", keyPath: \.photos)
        addRow(title: "Videos", keyPath: \.videos)
        addRow(title: "Screenshots", keyPath: \.screenshots)
        reload(from: filter)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload(from filter: MediaFilter) {
        self.filter = filter
        rows[0].isChecked = filter.photos
        rows[1].isChecked = filter.videos
        rows[2].isChecked = filter.screenshots
    }

    private func addRow(title: String, keyPath: WritableKeyPath<MediaFilter, Bool>) {
        let row = FilterRow(title: title)
        row.onTap = { [weak self] in
            guard let self else { return }
            self.filter[keyPath: keyPath].toggle()
            self.reload(from: self.filter)
            self.onChange?(self.filter)
        }
        rows.append(row)
        stack.addArrangedSubview(row)
    }
}

private final class FilterRow: UIControl {
    var onTap: (() -> Void)?

    var isChecked: Bool = true {
        didSet { checkImageView.image = UIImage(systemName: isChecked ? "checkmark.circle.fill" : "circle") }
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkImageView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        view.tintColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        addSubview(titleLabel)
        addSubview(checkImageView)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            checkImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            checkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkImageView.widthAnchor.constraint(equalToConstant: 22),
            checkImageView.heightAnchor.constraint(equalToConstant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: checkImageView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }
}
