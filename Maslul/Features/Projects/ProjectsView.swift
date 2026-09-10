import SwiftUI
import SwiftData

/// Projects are created and managed by hand (US-G1). A closed project drops off
/// the pickers and stays in every historical report — nothing is deleted.
struct ProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.createdAt, order: .forward)
    private var projects: [Project]

    @Query(filter: #Predicate<Entry> { $0.trashedAt == nil }) private var entries: [Entry]

    @State private var editing: Project?
    @State private var showLimitAlert = false

    private var active: [Project] { projects.filter { $0.status == .active } }
    private var paused: [Project] { projects.filter { $0.status == .paused } }
    private var closed: [Project] { projects.filter { $0.status == .done } }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "ACTIVE · \(active.count) of \(Project.activeLimit)")
                        .padding(.bottom, 4)

                    if active.isEmpty {
                        Text("No projects yet. The first one only needs a name.")
                            .font(.bodyText(14))
                            .foregroundStyle(Palette.meta)
                            .padding(.vertical, 16)
                    }

                    ForEach(active) { project in
                        row(project)
                    }

                    if !paused.isEmpty {
                        SectionLabel(text: "PAUSED").padding(.top, 20)
                        ForEach(paused) { project in
                            row(project).opacity(0.6)
                        }
                    }

                    if !closed.isEmpty {
                        SectionLabel(text: "DONE").padding(.top, 20)
                        ForEach(closed) { project in
                            row(project).opacity(0.45)
                        }
                    }

                    CardBox {
                        Text("פרויקט סגור יורד ממסכי הבחירה ונשאר בכל הדוחות ההיסטוריים. שום דבר לא נמחק.")
                            .font(.bodyText(13))
                            .foregroundStyle(Palette.ink2)
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, Metrics.hMargin)
                .padding(.bottom, 40)
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { project in
            ProjectEditView(project: project)
        }
        .alert("כבר יש שמונה פרויקטים פעילים", isPresented: $showLimitAlert) {
            Button("הבנתי", role: .cancel) {}
        } message: {
            Text("מעבר לשמונה, ההקצאה השבועית הופכת לטבלה שאף אחד לא ממלא. סגור פרויקט קיים לפני שתוסיף חדש.")
        }
    }

    private var header: some View {
        HStack {
            CircleButton(symbol: "chevron.forward") { dismiss() }
            Spacer()
            Text("Projects")
                .font(.bodyText(16, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Chip(title: "New", isOn: true) { createProject() }
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func row(_ project: Project) -> some View {
        Button { editing = project } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Palette.neutralTile)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Group {
                            if project.isGeneratingEmoji {
                                AIActivityGlyph(size: 16)
                            } else {
                                Text(project.emoji)
                                    .font(.system(size: 18))
                            }
                        }
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.bodyText(15.5))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle(for: project))
                        .font(.bodyText(12.5))
                        .foregroundStyle(Palette.meta)
                }

                Spacer(minLength: 8)

                Text(project.origin.shortTitle)
                    .font(.bodyText(11.5))
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(Capsule().stroke(Palette.line, lineWidth: 1))

                Chevron()
            }
            .padding(.vertical, 15)
            .frame(minHeight: Metrics.rowMinHeight)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.lineSoft).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for project: Project) -> String {
        let count = entries.filter {
            $0.project?.persistentModelID == project.persistentModelID
        }.count

        var parts = ["\(count) רשומות"]
        if project.status == .done, let ended = project.endedAt {
            parts = ["נסגר ב\(Fmt.monthYear(ended))"] + parts
        } else if let started = project.startedAt {
            parts.append("מ\(Fmt.monthYear(started))")
        }
        return parts.joined(separator: " · ")
    }

    private func createProject() {
        guard active.count < Project.activeLimit else {
            showLimitAlert = true
            return
        }
        let project = Project(name: "")
        context.insert(project)
        editing = project
    }
}

// MARK: - Editor

struct ProjectEditView: View {
    @Bindable var project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Chip(title: "Cancel") { cancel() }
                Spacer()
                Text("PROJECT")
                    .font(.utility(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Palette.meta)
                Spacer()
                Chip(title: "Save", isOn: !trimmedName.isEmpty) { save() }
                    .opacity(trimmedName.isEmpty ? 0.45 : 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "NAME & EMOJI")
                HStack(spacing: 10) {
                    TextField("📁", text: $project.emoji)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.center)
                        .frame(width: 54, height: 50)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))

                    ZStack(alignment: .leading) {
                        if project.name.isEmpty {
                            Text("Project name")
                                .font(.bodyText(17))
                                .foregroundStyle(Palette.line)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $project.name)
                            .font(.bodyText(17))
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "DEFAULT ORIGIN")
                Text("ברירת מחדל שרשומות בפרויקט יורשות. ניתן לדריסה ברשומה בודדת.")
                    .font(.bodyText(12.5))
                    .foregroundStyle(Palette.meta)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TaskOrigin.allCases) { candidate in
                            Chip(title: candidate.title, isOn: project.origin == candidate) {
                                project.origin = candidate
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "STATUS")
                HStack(spacing: 8) {
                    ForEach(ProjectStatus.allCases) { candidate in
                        Chip(title: candidate.title, isOn: project.status == candidate) {
                            project.status = candidate
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Metrics.hMargin)
        .padding(.top, 20)
        .screenBackground()
        .environment(\.layoutDirection, .leftToRight)
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        project.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        project.name = trimmedName
        let enteredEmoji = project.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        project.emoji = enteredEmoji.first.map(String.init) ?? "📁"
        if project.mark.isEmpty || project.mark == "•" {
            project.mark = Project.defaultMark(for: trimmedName)
        }
        try? context.save()

        let initialEmoji = project.emoji
        if initialEmoji == "📁" {
            project.isGeneratingEmoji = true
            Task { @MainActor in
                let generated = await LocalMetadataGenerator.emoji(
                    for: project.name,
                    fallback: Project.suggestedEmoji(for: project.name)
                )
                guard project.emoji == initialEmoji else {
                    project.isGeneratingEmoji = false
                    return
                }
                project.emoji = generated
                project.isGeneratingEmoji = false
                try? context.save()
            }
        }
        dismiss()
    }

    /// A project that was never named was never really created.
    private func cancel() {
        if trimmedName.isEmpty {
            context.delete(project)
            try? context.save()
        }
        dismiss()
    }
}
