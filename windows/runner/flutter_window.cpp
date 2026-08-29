#include "flutter_window.h"

#include <cstdint>
#include <optional>

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {
const std::string* StringArgument(const flutter::EncodableMap& arguments,
                                  const char* name) {
  const auto found = arguments.find(flutter::EncodableValue(name));
  if (found == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&found->second);
}

std::optional<uint32_t> ColorArgument(
    const flutter::EncodableMap& arguments,
    const char* name) {
  const auto found = arguments.find(flutter::EncodableValue(name));
  if (found == arguments.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<int32_t>(&found->second)) {
    return static_cast<uint32_t>(*value);
  }
  if (const auto* value = std::get_if<int64_t>(&found->second)) {
    return static_cast<uint32_t>(*value);
  }
  return std::nullopt;
}

COLORREF ColorRefFromArgb(uint32_t color) {
  return RGB((color >> 16) & 0xff, (color >> 8) & 0xff, color & 0xff);
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
  command_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "updateWindowChrome" || !call.arguments()) {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("argument", "Window chrome colours are required.");
          return;
        }
        const auto background = ColorArgument(*arguments, "background");
        const auto foreground = ColorArgument(*arguments, "foreground");
        if (!background || !foreground) {
          result->Error("argument", "Window chrome colours are required.");
          return;
        }
        const COLORREF caption = ColorRefFromArgb(*background);
        const COLORREF text = ColorRefFromArgb(*foreground);
        // These attributes are supported from Windows 11 build 22000. An
        // older host simply keeps its system colours when DWM rejects them.
        ::DwmSetWindowAttribute(GetHandle(), DWMWA_CAPTION_COLOR, &caption,
                                sizeof(caption));
        ::DwmSetWindowAttribute(GetHandle(), DWMWA_TEXT_COLOR, &text,
                                sizeof(text));
        result->Success();
      });
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
