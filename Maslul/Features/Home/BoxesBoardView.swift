import SwiftUI
import SwiftData
import UIKit

struct BoxesBoardView: View {
    let boxes: [EntryBox]
    let entries: [Entry]
    let openBox: (EntryBox) -> Void
    let openEntry: (Entry) -> Void

    @Environment(\.modelContext) private var context
    @State private var editMode: EditMode = .inactive

    var body: some View {
        if boxes.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                sortControl

                List {
                    ForEach(boxes) { box in
                        boxShelf(box)
                            .padding(.vertical, 12)
                            .journalListRow()
                    }
                    .onMove(perform: moveBoxes)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.editMode, $editMode)
            }
        }
    }

    private var sortControl: some View {
        HStack {
            Spacer()

            Button {
                withAnimation(Motion.spring) {
                    editMode = editMode.isEditing ? .inactive : .active
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(editMode.isEditing ? "Done" : "Sort")
                }
                .font(.bodyText(12.5, weight: .semibold))
                .foregroundStyle(editMode.isEditing ? Color.white : Palette.ink2)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(editMode.isEditing ? Palette.control : Palette.neutralTile))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 14)
    }

    private func entries(in box: EntryBox) -> [Entry] {
        entries
            .filter { $0.box?.persistentModelID == box.persistentModelID }
            .sorted { lhs, rhs in
                if lhs.boxSortIndex == rhs.boxSortIndex {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.boxSortIndex < rhs.boxSortIndex
            }
    }

    private func boxShelf(_ box: EntryBox) -> some View {
        let boxEntries = entries(in: box)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Button { openBox(box) } label: {
                    HStack(spacing: 10) {
                        EntryBoxTile(box: box, size: 40)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(box.name)
                                .font(.bodyText(17, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("\(boxEntries.count) \(boxEntries.count == 1 ? "entry" : "entries")")
                                .font(.bodyText(11.5))
                                .foregroundStyle(Palette.meta)
                        }

                        Spacer()

                        if !editMode.isEditing {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(editMode.isEditing)
            }
            .padding(.horizontal, Metrics.hMargin)

            if !editMode.isEditing {
                if boxEntries.isEmpty {
                    Text("Nothing in this box yet")
                        .font(.bodyText(13.5))
                        .foregroundStyle(Palette.meta)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Palette.neutralTile.opacity(0.72))
                        )
                        .padding(.horizontal, Metrics.hMargin)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(boxEntries) { entry in
                                Button { openEntry(entry) } label: {
                                    BoxEntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Metrics.hMargin)
                    }
                }
            }
        }
        .animation(Motion.spring, value: editMode.isEditing)
    }

    private func moveBoxes(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = boxes
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, box) in reordered.enumerated() {
            box.sortIndex = index
        }
        try? context.save()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No boxes yet")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            Text("Choose a box while writing to start your board.")
                .font(.bodyText(13))
                .foregroundStyle(Palette.meta)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.hMargin)
    }
}

struct BoxDetailView: View {
    let box: EntryBox

    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }, sort: \Entry.createdAt, order: .reverse)
    private var entries: [Entry]

    @State private var isReordering = false

    private var boxEntries: [Entry] {
        entries
            .filter { $0.box?.persistentModelID == box.persistentModelID }
            .sorted { lhs, rhs in
                if lhs.boxSortIndex == rhs.boxSortIndex {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.boxSortIndex < rhs.boxSortIndex
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if boxEntries.isEmpty {
                emptyState
            } else if isReordering {
                NativeReorderableEntryGrid(
                    entries: boxEntries,
                    persistOrder: persistBoxEntryOrder
                )
                .transition(.opacity)
            } else {
                entryGrid
                    .transition(.opacity)
            }
        }
        .screenBackground()
        .withDock()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "chevron.forward") { dismiss() }

            EntryBoxTile(box: box, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(box.name)
                    .font(.display(28))
                    .displayTracking(28)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text("\(boxEntries.count) \(boxEntries.count == 1 ? "entry" : "entries")")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
            }

            Spacer(minLength: 8)

            boxSortControl
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var boxSortControl: some View {
        if isReordering {
            Button {
                withAnimation(Motion.spring) {
                    isReordering = false
                }
            } label: {
                boxSortLabel(title: "Done", symbol: "checkmark", isActive: true)
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                Button {
                    withAnimation(Motion.spring) {
                        isReordering = true
                    }
                } label: {
                    Label("Manual order", systemImage: "line.3.horizontal")
                }

                Divider()

                Button {
                    applyBoxEntrySort(newestFirst: true)
                } label: {
                    Label("Newest first", systemImage: "arrow.down")
                }

                Button {
                    applyBoxEntrySort(newestFirst: false)
                } label: {
                    Label("Oldest first", systemImage: "arrow.up")
                }
            } label: {
                boxSortLabel(title: "Sort", symbol: "arrow.up.arrow.down", isActive: false)
            }
        }
    }

    private func boxSortLabel(title: String, symbol: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
            Text(title)
        }
        .font(.bodyText(12, weight: .semibold))
        .foregroundStyle(isActive ? Color.white : Palette.ink2)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Capsule().fill(isActive ? Palette.control : Palette.neutralTile))
    }

    private var entryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(boxEntries) { entry in
                    Button { router.open(entry) } label: {
                        FocusedBoxEntryCard(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.hMargin)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Nothing in this box yet")
                .font(.bodyText(15, weight: .semibold))
                .foregroundStyle(Palette.ink2)
            Text("Entries moved here will appear on this board.")
                .font(.bodyText(13))
                .foregroundStyle(Palette.meta)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.hMargin)
    }

    private func persistBoxEntryOrder(_ reordered: [Entry]) {
        for (index, entry) in reordered.enumerated() {
            entry.boxSortIndex = index
        }
        try? context.save()
    }

    private func applyBoxEntrySort(newestFirst: Bool) {
        let ordered = boxEntries.sorted {
            newestFirst ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt
        }
        for (index, entry) in ordered.enumerated() {
            entry.boxSortIndex = index
        }
        try? context.save()
    }

}

private struct NativeReorderableEntryGrid: UIViewRepresentable {
    let entries: [Entry]
    let persistOrder: ([Entry]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: Metrics.hMargin,
            bottom: 24,
            right: Metrics.hMargin
        )
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.reuseIdentifier)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.18
        collectionView.addGestureRecognizer(longPress)
        context.coordinator.collectionView = collectionView
        context.coordinator.installInsertionIndicator(in: collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        guard !context.coordinator.isMoving else { return }

        let currentIDs = context.coordinator.orderedEntries.map(\.persistentModelID)
        let incomingIDs = entries.map(\.persistentModelID)
        if currentIDs != incomingIDs {
            context.coordinator.orderedEntries = entries
            collectionView.reloadData()
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        static let reuseIdentifier = "NativeReorderableEntryCell"

        var parent: NativeReorderableEntryGrid
        var orderedEntries: [Entry]
        weak var collectionView: UICollectionView?
        var isMoving = false

        private let selectionFeedback = UISelectionFeedbackGenerator()
        private let liftFeedback = UIImpactFeedbackGenerator(style: .light)
        private let insertionIndicator = UIView()
        private var lastProposedIndexPath: IndexPath?

        init(parent: NativeReorderableEntryGrid) {
            self.parent = parent
            orderedEntries = parent.entries
        }

        func installInsertionIndicator(in collectionView: UICollectionView) {
            insertionIndicator.backgroundColor = UIColor(Palette.accent)
            insertionIndicator.layer.cornerRadius = 1.5
            insertionIndicator.layer.shadowColor = UIColor(Palette.accent).cgColor
            insertionIndicator.layer.shadowOpacity = 0.35
            insertionIndicator.layer.shadowRadius = 3
            insertionIndicator.isHidden = true
            collectionView.addSubview(insertionIndicator)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            orderedEntries.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.reuseIdentifier,
                for: indexPath
            )
            let entry = orderedEntries[indexPath.item]
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                ZStack(alignment: .topTrailing) {
                    FocusedBoxEntryCard(entry: entry)

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Palette.neutralTile.opacity(0.94)))
                        .padding(5)
                }
            }
            .margins(.all, 0)
            return cell
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let availableWidth = collectionView.bounds.width
                - collectionView.contentInset.left
                - collectionView.contentInset.right
                - 10
            let width = floor(availableWidth / 2)
            return CGSize(width: width, height: width / (226 / 126))
        }

        func collectionView(
            _ collectionView: UICollectionView,
            canMoveItemAt indexPath: IndexPath
        ) -> Bool {
            true
        }

        func collectionView(
            _ collectionView: UICollectionView,
            moveItemAt sourceIndexPath: IndexPath,
            to destinationIndexPath: IndexPath
        ) {
            let movedEntry = orderedEntries.remove(at: sourceIndexPath.item)
            orderedEntries.insert(movedEntry, at: destinationIndexPath.item)
            parent.persistOrder(orderedEntries)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath,
            toProposedIndexPath proposedIndexPath: IndexPath
        ) -> IndexPath {
            if proposedIndexPath != lastProposedIndexPath {
                lastProposedIndexPath = proposedIndexPath
                selectionFeedback.selectionChanged()
            }
            updateInsertionIndicator(for: proposedIndexPath, in: collectionView)
            return proposedIndexPath
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView else { return }
            let location = gesture.location(in: collectionView)

            switch gesture.state {
            case .began:
                guard let indexPath = collectionView.indexPathForItem(at: location),
                      collectionView.beginInteractiveMovementForItem(at: indexPath) else { return }
                isMoving = true
                lastProposedIndexPath = indexPath
                selectionFeedback.prepare()
                liftFeedback.impactOccurred()
                updateInsertionIndicator(for: indexPath, in: collectionView)
            case .changed:
                guard isMoving else { return }
                collectionView.updateInteractiveMovementTargetPosition(location)
            case .ended:
                guard isMoving else { return }
                collectionView.endInteractiveMovement()
                finishMovement()
            default:
                guard isMoving else { return }
                collectionView.cancelInteractiveMovement()
                finishMovement()
            }
        }

        private func updateInsertionIndicator(
            for indexPath: IndexPath,
            in collectionView: UICollectionView
        ) {
            guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
                insertionIndicator.isHidden = true
                return
            }
            insertionIndicator.frame = CGRect(
                x: attributes.frame.minX - 5,
                y: attributes.frame.minY + 6,
                width: 3,
                height: max(0, attributes.frame.height - 12)
            )
            insertionIndicator.isHidden = false
            collectionView.bringSubviewToFront(insertionIndicator)
        }

        private func finishMovement() {
            isMoving = false
            lastProposedIndexPath = nil
            insertionIndicator.isHidden = true
        }
    }
}

private struct FocusedBoxEntryCard: View {
    let entry: Entry

    private let cardAspectRatio: CGFloat = 226 / 126

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                if entry.isGeneratingTitle {
                    AIActivityIndicator(messages: ["Naming", "Summarizing"], compact: true)
                } else {
                    Text(entry.title)
                        .font(.bodyText(14.5, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if entry.isSensitive {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.meta)
                        .padding(.top, 3)
                }
            }

            if entry.title != entry.body {
                InlineMentionText(
                    text: entry.body,
                    tags: entry.tags,
                    fontSize: 11.5,
                    maximumNumberOfLines: 1,
                    mentionAppearance: .compact
                )
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(Fmt.dayDot(entry.createdAt))
                    .font(.utility(10))
                    .foregroundStyle(Palette.meta)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if !entry.attachmentNames.isEmpty {
                    Label("\(entry.attachmentNames.count)", systemImage: "paperclip")
                        .font(.utility(10))
                        .foregroundStyle(Palette.meta)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .aspectRatio(cardAspectRatio, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.lineSoft, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BoxEntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.bodyText(15.5, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if entry.title != entry.body {
                InlineMentionText(
                    text: entry.body,
                    tags: entry.tags,
                    fontSize: 12.5,
                    maximumNumberOfLines: 2,
                    mentionAppearance: .compact
                )
            }

            Spacer(minLength: 2)

            Text(Fmt.longDate(entry.createdAt))
                .font(.utility(10))
                .foregroundStyle(Palette.meta)
        }
        .padding(14)
        .frame(width: 226, height: 126, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.lineSoft, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
