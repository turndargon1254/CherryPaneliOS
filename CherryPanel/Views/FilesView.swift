import SwiftUI
import UIKit

struct FilesView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var showUpload = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var editingFile: FileItem?
    @State private var uploadFiles: [URL] = []
    
    private let api = APIService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with breadcrumb
            VStack(spacing: 8) {
                HStack {
                    Text("文件管理")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Breadcrumb
                HStack(spacing: 4) {
                    Button(action: { viewModel.navigateTo(path: "") }) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.cyan)
                    }
                    ForEach(currentPathComponents, id: \.self) { component in
                        Text("/")
                            .foregroundColor(.secondary)
                        if component == currentPathComponents.last {
                            Text(component)
                                .foregroundColor(.primary)
                        } else {
                            Button(action: { navigateToPath(component) }) {
                                Text(component)
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    Spacer()
                }
                .font(.caption)
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            
            // Toolbar
            HStack {
                Button(action: { viewModel.goUp() }) {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.currentPath.isEmpty)
                
                Button(action: { Task { await viewModel.refreshFiles() } }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: { showNewFolder = true }) {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                
                Button(action: { showUpload = true }) {
                    Label("上传", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            // Error
            if let error = viewModel.refreshError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            
            // File Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    if viewModel.files.isEmpty && !viewModel.isRefreshing {
                        FilesEmptyStateView()
                            .frame(maxWidth: .infinity)
                    }
                    
                    ForEach(viewModel.files) { file in
                        FileItemView(file: file, viewModel: viewModel, editingFile: $editingFile)
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.refreshFiles()
            }
        }
        .navigationTitle("文件管理")
        .sheet(isPresented: $showUpload) {
            UploadView(uploadFiles: $uploadFiles, onUpload: { files in
                Task {
                    for url in files {
                        do {
                            _ = try await api.uploadFile(from: url, to: viewModel.currentPath)
                        } catch {
                            viewModel.refreshError = "上传失败: \(error.localizedDescription)"
                        }
                    }
                    uploadFiles = []
                    await viewModel.refreshFiles()
                }
            })
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderView(folderName: $newFolderName, onCreate: { name in
                Task {
                    let path = viewModel.currentPath.isEmpty ? name : "\(viewModel.currentPath)/\(name)"
                    do {
                        _ = try await api.createFolder(path: path)
                        newFolderName = ""
                        await viewModel.refreshFiles()
                    } catch {
                        viewModel.refreshError = "创建失败: \(error.localizedDescription)"
                    }
                }
            })
        }
        .sheet(item: $editingFile) { file in
            FileEditorView(file: file)
        }
        .fileImporter(isPresented: $showUpload, allowedContentTypes: [.item]) { result in
            // 兼容：如果 sheet 未使用 fileImporter，这里也处理
            if case .success(let url) = result {
                Task {
                    do {
                        _ = try await api.uploadFile(from: url, to: viewModel.currentPath)
                        await viewModel.refreshFiles()
                    } catch {
                        viewModel.refreshError = "上传失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private var currentPathComponents: [String] {
        viewModel.currentPath.split(separator: "/").map(String.init)
    }
    
    private func navigateToPath(_ component: String) {
        let index = currentPathComponents.firstIndex(of: component) ?? 0
        let path = currentPathComponents.prefix(index + 1).joined(separator: "/")
        viewModel.navigateTo(path: path)
    }
}

struct FileItemView: View {
    let file: FileItem
    @ObservedObject var viewModel: AppViewModel
    @Binding var editingFile: FileItem?
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: file.iconName)
                .font(.system(size: 32))
                .foregroundColor(iconColor(for: file))
            
            Text(file.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(file.sizeStr)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let modified = file.modified {
                Text(formattedDate(modified))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Actions
            HStack(spacing: 8) {
                if file.isDir {
                    Button(action: { viewModel.navigateTo(path: file.path) }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: { editingFile = file }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { downloadFile(file) }) {
                        Image(systemName: "arrow.down.doc")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive, action: { deleteFile(file) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onTapGesture {
            if file.isDir {
                viewModel.navigateTo(path: file.path)
            }
        }
    }
    
    private func iconColor(for file: FileItem) -> Color {
        if file.isDir { return .orange }
        let ext = (file.path as NSString).pathExtension.lowercased()
        switch ext {
        case "jar": return .purple
        case "json", "yml", "yaml": return .cyan
        case "txt", "log": return .blue
        case "png", "jpg", "jpeg", "gif": return .green
        default: return .secondary
        }
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func downloadFile(_ file: FileItem) {
        Task {
            do {
                let data = try await api.downloadFile(path: file.path)
                // 保存到文件，打开分享面板
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
                try data.write(to: tempURL)
                await MainActor.run {
                    shareFile(url: tempURL)
                }
            } catch {
                await MainActor.run {
                    viewModel.refreshError = "下载失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func deleteFile(_ file: FileItem) {
        Task {
            do {
                _ = try await api.deleteFile(path: file.path)
                await viewModel.refreshFiles()
            } catch {
                await MainActor.run {
                    viewModel.refreshError = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct FilesEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("目录为空")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("拖拽文件上传或点击上传按钮")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct UploadView: View {
    @Binding var uploadFiles: [URL]
    let onUpload: ([URL]) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Select files button
                Button {
                    isImporterPresented = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.cyan)
                        Text("点击选择文件")
                        Text("支持多文件上传")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                if !uploadFiles.isEmpty {
                    List {
                        ForEach(uploadFiles.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: "doc.fill")
                                Text(uploadFiles[index].lastPathComponent)
                                Spacer()
                                Text(fileSizeString(for: uploadFiles[index]))
                                    .foregroundColor(.secondary)
                                Button(role: .destructive) {
                                    uploadFiles.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                        }
                    }
                }
                
                Button("开始上传") {
                    onUpload(uploadFiles)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(uploadFiles.isEmpty)
            }
            .padding()
            .navigationTitle("上传文件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    uploadFiles.append(contentsOf: urls)
                }
            }
        }
    }
    
    @State private var isImporterPresented = false
    
    private func fileSizeString(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = values?.fileSize ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct NewFolderView: View {
    @Binding var folderName: String
    let onCreate: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("文件夹名称", text: $folderName)
                } header: {
                    Text("新建文件夹")
                } footer: {
                    Text("输入文件夹名称，将在当前目录下创建")
                }
            }
            .navigationTitle("新建文件夹")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        onCreate(folderName)
                        dismiss()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct FileEditorView: View {
    let file: FileItem
    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private let api = APIService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationTitle("编辑: \(file.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveFile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(content.isEmpty || isSaving)
                }
            }
            .onAppear {
                loadContent()
            }
        }
    }
    
    private func loadContent() {
        Task {
            do {
                let response = try await api.getFileContent(path: file.path)
                await MainActor.run {
                    content = response.content
                }
            } catch {
                let message = "加载失败: \(error.localizedDescription)"
                await MainActor.run {
                    errorMessage = message
                }
            }
        }
    }
    
    private func saveFile() {
        isSaving = true
        Task {
            do {
                _ = try await api.saveFile(path: file.path, content: content)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
            }
        }
    }
}