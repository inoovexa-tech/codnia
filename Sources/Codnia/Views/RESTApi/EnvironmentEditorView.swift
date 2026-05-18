import SwiftUI

struct EnvironmentEditorView: View {
    @EnvironmentObject var viewModel: RESTApiViewModel
    @Environment(\.dismiss) var dismiss

    @State private var newEnvironmentName: String = ""
    @State private var editingEnvironment: APIEnvironment?

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 0) {
                environmentList

                Divider()
                    .background(Color.borderDefault)

                environmentDetail
            }
        }
        .frame(width: 600, height: 400)
        .background(Color.bgPrimary)
    }

    private var header: some View {
        HStack {
            Text("Environments")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private var environmentList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.environmentStore.environments) { env in
                environmentRow(env)
            }

            HStack(spacing: 8) {
                TextField("New environment", text: $newEnvironmentName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)

                Button(action: addEnvironment) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newEnvironmentName.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 180)
        .background(Color.bgSecondary)
    }

    private func environmentRow(_ env: APIEnvironment) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(env.isActive ? Color.accentGreen : Color.textTertiary)
                .frame(width: 6, height: 6)

            Text(env.name)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Spacer()

            if !env.isActive {
                Button(action: { viewModel.selectEnvironment(env) }) {
                    Text("Use")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(editingEnvironment?.id == env.id ? Color.bgHover : Color.clear)
        .onTapGesture {
            editingEnvironment = env
        }
        .contextMenu {
            Button("Delete") {
                viewModel.deleteEnvironment(env)
                if editingEnvironment?.id == env.id {
                    editingEnvironment = nil
                }
            }
        }
    }

    @ViewBuilder
    private var environmentDetail: some View {
        if let env = editingEnvironment {
            VStack(spacing: 0) {
                HStack {
                    Text(env.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button("Add Variable") {
                        var updated = env
                        updated.variables.append(EnvironmentVariable(key: "", value: ""))
                        viewModel.environmentStore.updateEnvironment(updated)
                        editingEnvironment = updated
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.bgTertiary)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(env.variables.enumerated()), id: \.element.id) { index, variable in
                            variableRow(env: env, index: index, variable: variable)
                        }
                    }
                    .padding(12)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack {
                Spacer()
                Text("Select an environment to edit")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func variableRow(env: APIEnvironment, index: Int, variable: EnvironmentVariable) -> some View {
        HStack(spacing: 8) {
            TextField("Key", text: Binding(
                get: { env.variables[index].key },
                set: { newValue in
                    var updated = env
                    updated.variables[index].key = newValue
                    viewModel.environmentStore.updateEnvironment(updated)
                    editingEnvironment = updated
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgTertiary)
            .cornerRadius(3)

            TextField("Value", text: Binding(
                get: { env.variables[index].value },
                set: { newValue in
                    var updated = env
                    updated.variables[index].value = newValue
                    viewModel.environmentStore.updateEnvironment(updated)
                    editingEnvironment = updated
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgTertiary)
            .cornerRadius(3)

            Toggle("", isOn: Binding(
                get: { env.variables[index].isSecret },
                set: { newValue in
                    var updated = env
                    updated.variables[index].isSecret = newValue
                    viewModel.environmentStore.updateEnvironment(updated)
                    editingEnvironment = updated
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.6)

            Button(action: {
                var updated = env
                updated.variables.remove(at: index)
                viewModel.environmentStore.updateEnvironment(updated)
                editingEnvironment = updated
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func addEnvironment() {
        guard !newEnvironmentName.isEmpty else { return }
        viewModel.addEnvironment(name: newEnvironmentName)
        newEnvironmentName = ""
    }
}