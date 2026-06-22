#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "winrt_ext.h"

namespace {

constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\timppyy.localsend-chat.single-instance";
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"LocalSend";

bool ShouldForwardToRunningInstance(const std::vector<std::string>& args) {
  for (const std::string& arg : args) {
    if (arg == "--share" || arg == "--text" || arg == "-t") {
      return true;
    }
    if (!arg.empty() && arg[0] != '-') {
      return true;
    }
  }
  return false;
}

void ShowRunningInstance() {
  HWND existing_window = ::FindWindowW(kWindowClassName, kWindowTitle);
  if (existing_window == nullptr) {
    return;
  }

  if (::IsIconic(existing_window)) {
    ::ShowWindow(existing_window, SW_RESTORE);
  } else {
    ::ShowWindow(existing_window, SW_SHOWNORMAL);
  }
  ::SetWindowPos(existing_window, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  ::SetForegroundWindow(existing_window);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  if (IsRunningWithIdentity()) {
    winrt::hstring share_arg = GetSharedMedia();
    if (!share_arg.empty()) {
      printf("share: %ls\n", share_arg.c_str());
      command_line_arguments.push_back("--share");
      command_line_arguments.push_back(Utf8FromUtf16(share_arg.c_str()));
    }
  }

  HANDLE single_instance_mutex = nullptr;
  if (!ShouldForwardToRunningInstance(command_line_arguments)) {
    single_instance_mutex =
        ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
    if (single_instance_mutex != nullptr &&
        ::GetLastError() == ERROR_ALREADY_EXISTS) {
      ShowRunningInstance();
      ::CloseHandle(single_instance_mutex);
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(500, 600);
  if (!window.Create(kWindowTitle, origin, size)) {
    if (single_instance_mutex != nullptr) {
      ::ReleaseMutex(single_instance_mutex);
      ::CloseHandle(single_instance_mutex);
    }
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
