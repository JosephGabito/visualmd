#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {
constexpr UINT kNewWorkspace = 1001;
constexpr UINT kOpenWorkspace = 1002;
constexpr UINT kSaveWorkspace = 1003;
constexpr UINT kSaveWorkspaceAs = 1004;
constexpr UINT kAddFolder = 1005;
constexpr UINT kAddMarkdown = 1006;

void AppendCommand(HMENU menu, UINT id, const wchar_t* label) {
  ::AppendMenuW(menu, MF_STRING, id, label);
}

const std::string* StringArgument(const flutter::EncodableMap& arguments,
                                  const char* name) {
  const auto found = arguments.find(flutter::EncodableValue(name));
  if (found == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&found->second);
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  command_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.visualmd.visualmd/commands",
          &flutter::StandardMethodCodec::GetInstance());
  atomic_files_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.visualmd.visualmd/atomic-files",
          &flutter::StandardMethodCodec::GetInstance());
  atomic_files_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() != "replace" || !call.arguments()) {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("argument", "File paths are required.");
          return;
        }
        const auto* target = StringArgument(*arguments, "target");
        const auto* temporary = StringArgument(*arguments, "temporary");
        const auto* backup = StringArgument(*arguments, "backup");
        if (!target || !temporary || !backup) {
          result->Error("argument", "File paths are required.");
          return;
        }
        const auto target_path = Utf16FromUtf8(*target);
        const auto temporary_path = Utf16FromUtf8(*temporary);
        const auto backup_path = Utf16FromUtf8(*backup);
        if (target_path.empty() || temporary_path.empty() ||
            backup_path.empty()) {
          result->Error("argument", "File paths must be valid UTF-8.");
          return;
        }
        BOOL replaced;
        if (::GetFileAttributesW(target_path.c_str()) !=
            INVALID_FILE_ATTRIBUTES) {
          ::DeleteFileW(backup_path.c_str());
          replaced = ::ReplaceFileW(target_path.c_str(),
                                    temporary_path.c_str(),
                                    backup_path.c_str(),
                                    REPLACEFILE_WRITE_THROUGH, nullptr,
                                    nullptr);
        } else {
          replaced = ::MoveFileExW(temporary_path.c_str(), target_path.c_str(),
                                   MOVEFILE_REPLACE_EXISTING |
                                       MOVEFILE_WRITE_THROUGH);
        }
        if (!replaced) {
          result->Error("atomic-replace", "Windows could not replace the file.",
                        flutter::EncodableValue(
                            static_cast<int>(::GetLastError())));
          return;
        }
        result->Success();
      });

  application_menu_ = ::CreateMenu();
  HMENU file_menu = ::CreatePopupMenu();
  AppendCommand(file_menu, kNewWorkspace, L"New Workspace\tCtrl+N");
  AppendCommand(file_menu, kOpenWorkspace, L"Open Workspace...\tCtrl+O");
  ::AppendMenuW(file_menu, MF_SEPARATOR, 0, nullptr);
  AppendCommand(file_menu, kSaveWorkspace, L"Save Workspace\tCtrl+S");
  AppendCommand(file_menu, kSaveWorkspaceAs,
                L"Save Workspace As...\tCtrl+Shift+S");
  ::AppendMenuW(file_menu, MF_SEPARATOR, 0, nullptr);
  AppendCommand(file_menu, kAddFolder, L"Add Folder...");
  AppendCommand(file_menu, kAddMarkdown, L"Add Markdown...");
  ::AppendMenuW(application_menu_, MF_POPUP,
                reinterpret_cast<UINT_PTR>(file_menu), L"File");
  ::SetMenu(GetHandle(), application_menu_);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  atomic_files_channel_.reset();
  command_channel_.reset();
  if (application_menu_) {
    ::SetMenu(GetHandle(), nullptr);
    ::DestroyMenu(application_menu_);
    application_menu_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COMMAND:
      if (command_channel_) {
        const char* command = nullptr;
        switch (LOWORD(wparam)) {
          case kNewWorkspace:
            command = "newWorkspace";
            break;
          case kOpenWorkspace:
            command = "openWorkspace";
            break;
          case kSaveWorkspace:
            command = "saveWorkspace";
            break;
          case kSaveWorkspaceAs:
            command = "saveWorkspaceAs";
            break;
          case kAddFolder:
            command = "addFolder";
            break;
          case kAddMarkdown:
            command = "addMarkdown";
            break;
        }
        if (command) {
          command_channel_->InvokeMethod(command, nullptr);
          return 0;
        }
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
