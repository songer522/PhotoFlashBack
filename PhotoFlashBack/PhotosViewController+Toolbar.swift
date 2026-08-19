import UIKit

extension PhotosViewController {
    func setupOverflowAndFilterButtons() {
        view.addSubview(dimmerView)
        dimmerView.translatesAutoresizingMaskIntoConstraints = false
        dimmerView.addTarget(self, action: #selector(dimmerTapped), for: .touchUpInside)

        view.addSubview(overflowButton)
        overflowButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(filterButton)
        filterButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(overflowDropdown)
        overflowDropdown.translatesAutoresizingMaskIntoConstraints = false
        overflowDropdown.embed(buttons: [sortingButton, layoutButton])

        view.addSubview(filterDropdown)
        filterDropdown.translatesAutoresizingMaskIntoConstraints = false
        filterDropdown.onChange = { filter in
            MediaFilterStore.save(filter)
        }

        NSLayoutConstraint.activate([
            dimmerView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            overflowButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            overflowButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -10),
            overflowButton.widthAnchor.constraint(equalToConstant: 31),
            overflowButton.heightAnchor.constraint(equalToConstant: 31),

            filterButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            filterButton.trailingAnchor.constraint(equalTo: overflowButton.leadingAnchor, constant: -10),
            filterButton.widthAnchor.constraint(equalToConstant: 31),
            filterButton.heightAnchor.constraint(equalToConstant: 31),

            overflowDropdown.topAnchor.constraint(equalTo: overflowButton.bottomAnchor, constant: 8),
            overflowDropdown.trailingAnchor.constraint(equalTo: overflowButton.trailingAnchor),

            filterDropdown.topAnchor.constraint(equalTo: filterButton.bottomAnchor, constant: 8),
            filterDropdown.trailingAnchor.constraint(equalTo: filterButton.trailingAnchor)
        ])

        view.bringSubviewToFront(dimmerView)
        view.bringSubviewToFront(overflowDropdown)
        view.bringSubviewToFront(filterDropdown)
        view.bringSubviewToFront(settingsButton)
        view.bringSubviewToFront(overflowButton)
        view.bringSubviewToFront(filterButton)
        view.bringSubviewToFront(editButton)
    }

    @objc func overflowButtonTapped() {
        if !overflowDropdown.isHidden {
            dismissDropdowns()
            return
        }
        let shouldApplyFilter = !filterDropdown.isHidden
        showOverflowDropdown()
        if shouldApplyFilter {
            applyMediaFilterIfNeeded()
        }
    }

    @objc func filterButtonTapped() {
        if !filterDropdown.isHidden {
            dimmerTapped()
            return
        }
        showFilterDropdown()
    }

    @objc func dimmerTapped() {
        let shouldApplyFilter = !filterDropdown.isHidden
        dismissDropdowns()
        if shouldApplyFilter {
            applyMediaFilterIfNeeded()
        }
    }

    func dismissDropdowns() {
        overflowDropdown.isHidden = true
        filterDropdown.isHidden = true
        dimmerView.isHidden = true
    }

    private func showOverflowDropdown() {
        filterDropdown.isHidden = true
        overflowDropdown.isHidden = false
        dimmerView.isHidden = false
        view.bringSubviewToFront(dimmerView)
        view.bringSubviewToFront(overflowDropdown)
        view.bringSubviewToFront(overflowButton)
        view.bringSubviewToFront(filterButton)
        view.bringSubviewToFront(settingsButton)
        view.bringSubviewToFront(editButton)
    }

    private func showFilterDropdown() {
        overflowDropdown.isHidden = true
        filterDropdown.reload(from: MediaFilterStore.load())
        filterDropdown.isHidden = false
        dimmerView.isHidden = false
        view.bringSubviewToFront(dimmerView)
        view.bringSubviewToFront(filterDropdown)
        view.bringSubviewToFront(overflowButton)
        view.bringSubviewToFront(filterButton)
        view.bringSubviewToFront(settingsButton)
        view.bringSubviewToFront(editButton)
    }

    func applyMediaFilterIfNeeded() {
        let current = MediaFilterStore.load().normalizedForFetch()
        if current != viewModel.lastAppliedFilter {
            fetchPhotos()
        }
    }

    func emptyStateForCurrentResults() -> EmptyStateView.EmptyStateType {
        if MediaFilterStore.load().isEffectivelyUnfiltered {
            return .noPhotosForDate(viewModel.displayDate())
        }
        return .noItemsForFilters(viewModel.displayDate())
    }
}
