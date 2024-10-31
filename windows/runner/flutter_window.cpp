#include "flutter_window.h"

#include <optional>

#include <windows.h>
#include <memory>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <iostream>
#include <wincodec.h>
#include <Shlwapi.h>
#include <atlbase.h>
#include <atlenc.h>
#include <codecvt>
#include <shlwapi.h>

#pragma comment(lib, "Windowscodecs.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "Crypt32.lib")

// START CUSTOM FUNCTIONS
static int GetBatteryLevel()
{
  SYSTEM_POWER_STATUS status;
  if (GetSystemPowerStatus(&status) == 0 || status.BatteryLifePercent == 255)
  {
    return -1;
  }
  return status.BatteryLifePercent;
}

static std::string GetClipboardText()
{
  if (!OpenClipboard(nullptr))
    return "";
  HANDLE hData = GetClipboardData(CF_TEXT);
  if (hData == nullptr)
  {
    CloseClipboard();
    return "";
  }
  char *pszText = static_cast<char *>(GlobalLock(hData));
  if (pszText == nullptr)
  {
    GlobalUnlock(hData);
    CloseClipboard();
    return "";
  }
  std::string text(pszText);
  GlobalUnlock(hData);
  CloseClipboard();
  return text;
}

static bool SetClipboardText(const std::string &text)
{
  if (!OpenClipboard(nullptr))
    return false;
  EmptyClipboard();
  HGLOBAL hGlob = GlobalAlloc(GMEM_FIXED, text.size() + 1);
  if (!hGlob)
  {
    CloseClipboard();
    return false;
  }
  memcpy(hGlob, text.c_str(), text.size() + 1);
  SetClipboardData(CF_TEXT, hGlob);
  CloseClipboard();
  return true;
}

static std::string GetSelectedText()
{
  // 0. Get current clipboard content and write it to a variable for later
  std::string originalClipboardContent = GetClipboardText();

  // 1. Simulate Ctrl+C
  keybd_event(VK_CONTROL, 0, 0, 0);
  keybd_event('C', 0, 0, 0);
  keybd_event('C', 0, KEYEVENTF_KEYUP, 0);
  keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);

  // 2. Give the system time to process the clipboard event
  Sleep(500); // Adjust timing as necessary

  // 3. Write the content to a new variable
  std::string newCopiedText = GetClipboardText();

  // Check if the clipboard content has changed
  if (newCopiedText == originalClipboardContent)
  {
    // If not, it means no new text was selected and copied
    return "";
  }
  else
  {
    // 4. Rewrite clipboard content with a variable from the step 0 so user should not notice change
    SetClipboardText(originalClipboardContent);

    // 5. Send the selected text (from a variable in step 3) in return
    return newCopiedText;
  }
}

static void ShowOverlay() {}

static void RequestNativePermissions()
{
  // Implementation for requesting native permissions
}

static bool IsAccessibilityGranted()
{
  return true;
}

static void InitAccessibility()
{
  // Implementation for initializing accessibility
}

static std::pair<int, int> GetScreenSize()
{
  int width = GetSystemMetrics(SM_CXSCREEN);
  int height = GetSystemMetrics(SM_CYSCREEN);
  return {width, height};
}

static std::pair<int, int> GetMousePosition()
{
  POINT point;
  if (GetCursorPos(&point))
  {
    return {point.x, point.y};
  }
  return {0, 0}; // Return (0,0) if unable to get position
}

void logError(HRESULT hr, const char* msg) {
    char* errorMsg = nullptr;
    FormatMessageA(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, hr, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPSTR)&errorMsg, 0, NULL);
    std::cerr << msg << ": " << (errorMsg ? errorMsg : "Unknown error") << std::endl;
    if (errorMsg) {
        LocalFree(errorMsg);
    }
}

std::string captureActiveScreen() {
    // Get handle to active window
    HWND hwnd = GetForegroundWindow();
    // Get monitor handle
    HMONITOR hMonitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);

    MONITORINFO monitorInfo = {};
    monitorInfo.cbSize = sizeof(MONITORINFO);
    if (!GetMonitorInfo(hMonitor, &monitorInfo)) {
        std::cerr << "Failed to get monitor info" << std::endl;
        return "";
    }

    int width = monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left;
    int height = monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top;

    HDC hScreenDC = GetDC(NULL);
    HDC hMemoryDC = CreateCompatibleDC(hScreenDC);
    HBITMAP hBitmap = CreateCompatibleBitmap(hScreenDC, width, height);
    HGDIOBJ hOldBitmap = SelectObject(hMemoryDC, hBitmap);

    BitBlt(hMemoryDC, 0, 0, width, height, hScreenDC,
           monitorInfo.rcMonitor.left, monitorInfo.rcMonitor.top, SRCCOPY);

    // Initialize COM
    HRESULT hr = CoInitialize(NULL);
    if (FAILED(hr)) {
        logError(hr, "CoInitialize failed");
        return "";
    }

    // Create WIC factory
    CComPtr<IWICImagingFactory> pFactory;
    hr = CoCreateInstance(CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER,
                          IID_PPV_ARGS(&pFactory));
    if (FAILED(hr)) {
        logError(hr, "CoCreateInstance failed");
        CoUninitialize();
        return "";
    }

    // Create WIC bitmap from HBITMAP
    CComPtr<IWICBitmap> pBitmap;
    hr = pFactory->CreateBitmapFromHBITMAP(hBitmap, NULL,
                                           WICBitmapIgnoreAlpha, &pBitmap);
    if (FAILED(hr)) {
        logError(hr, "CreateBitmapFromHBITMAP failed");
        CoUninitialize();
        return "";
    }

    // Create stream
    CComPtr<IWICStream> pStream;
    hr = pFactory->CreateStream(&pStream);
    if (FAILED(hr)) {
        logError(hr, "CreateStream failed");
        CoUninitialize();
        return "";
    }

    // Allocate memory for the stream
    const size_t bufferSize = width * height * 4; // Assuming 4 bytes per pixel
    std::vector<BYTE> buffer(bufferSize);

    hr = pStream->InitializeFromMemory(buffer.data(), static_cast<DWORD>(buffer.size()));
    if (FAILED(hr)) {
        logError(hr, "InitializeFromMemory failed");
        CoUninitialize();
        return "";
    }

    // Create encoder for JPEG
    CComPtr<IWICBitmapEncoder> pEncoder;
    hr = pFactory->CreateEncoder(GUID_ContainerFormatJpeg, NULL, &pEncoder);
    if (FAILED(hr)) {
        logError(hr, "CreateEncoder failed");
        CoUninitialize();
        return "";
    }

    hr = pEncoder->Initialize(pStream, WICBitmapEncoderNoCache);
    if (FAILED(hr)) {
        logError(hr, "Encoder Initialize failed");
        CoUninitialize();
        return "";
    }

    // Create frame
    CComPtr<IWICBitmapFrameEncode> pFrame;
    CComPtr<IPropertyBag2> pProps;
    hr = pEncoder->CreateNewFrame(&pFrame, &pProps);
    if (FAILED(hr) || !pFrame) {
        logError(hr, "CreateNewFrame failed");
        CoUninitialize();
        return "";
    }

    // Set JPEG quality (optional)
    PROPBAG2 option = {};
    option.pstrName = L"ImageQuality";
    VARIANT varValue;
    VariantInit(&varValue);
    varValue.vt = VT_R4;       // VT_R4 is float type
    varValue.fltVal = 0.9f;    // Quality level (0.0 - 1.0)
    hr = pProps->Write(1, &option, &varValue);
    VariantClear(&varValue);
    if (FAILED(hr)) {
        logError(hr, "Write ImageQuality failed");
        CoUninitialize();
        return "";
    }

    hr = pFrame->Initialize(pProps);
    if (FAILED(hr)) {
        logError(hr, "Frame Initialize failed");
        CoUninitialize();
        return "";
    }

    hr = pFrame->SetSize(width, height);
    if (FAILED(hr)) {
        logError(hr, "SetSize failed");
        CoUninitialize();
        return "";
    }

    WICPixelFormatGUID formatGUID = GUID_WICPixelFormat24bppBGR;
    hr = pFrame->SetPixelFormat(&formatGUID);
    if (FAILED(hr)) {
        logError(hr, "SetPixelFormat failed");
        CoUninitialize();
        return "";
    }

    // Write to frame
    hr = pFrame->WriteSource(pBitmap, NULL);
    if (FAILED(hr)) {
        logError(hr, "WriteSource failed");
        CoUninitialize();
        return "";
    }

    hr = pFrame->Commit();
    if (FAILED(hr)) {
        logError(hr, "Frame Commit failed");
        CoUninitialize();
        return "";
    }

    hr = pEncoder->Commit();
    if (FAILED(hr)) {
        logError(hr, "Encoder Commit failed");
        CoUninitialize();
        return "";
    }

    // Get the size of the stream
    ULARGE_INTEGER ulnSize;
    IStream* ipStream = (IStream*)pStream.p;
    STATSTG stats;
    hr = ipStream->Stat(&stats, STATFLAG_NONAME);
    if (FAILED(hr)) {
        logError(hr, "Stream Stat failed");
        CoUninitialize();
        return "";
    }
    ulnSize = stats.cbSize;

    // Allocate memory and read the stream
    std::vector<BYTE> bufferRead(static_cast<size_t>(ulnSize.QuadPart));
    LARGE_INTEGER liZero = {};
    hr = ipStream->Seek(liZero, STREAM_SEEK_SET, NULL);
    if (FAILED(hr)) {
        logError(hr, "Stream Seek failed");
        CoUninitialize();
        return "";
    }

    ULONG bytesRead = 0;
    hr = ipStream->Read(bufferRead.data(), static_cast<ULONG>(bufferRead.size()), &bytesRead);
    if (FAILED(hr) || bytesRead != bufferRead.size()) {
        logError(hr, "Stream Read failed");
        CoUninitialize();
        return "";
    }

    // Encode to base64
    DWORD base64Length = 0;
    if (!CryptBinaryToStringA(bufferRead.data(), bytesRead,
                              CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                              NULL, &base64Length)) {
        std::cerr << "CryptBinaryToStringA (length) failed" << std::endl;
        CoUninitialize();
        return "";
    }

    std::string base64String(base64Length, '\0');
    if (!CryptBinaryToStringA(bufferRead.data(), bytesRead,
                              CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                              &base64String[0], &base64Length)) {
        std::cerr << "CryptBinaryToStringA (conversion) failed" << std::endl;
        CoUninitialize();
        return "";
    }

    // Trim the null character from the end of the Base64 string
    if (!base64String.empty() && base64String.back() == '\0') {
        base64String.pop_back();
    }

    // Verify the length of the Base64 string
    if (base64String.length() != base64Length) {
        std::cerr << "Base64 string length mismatch: expected " << base64Length << ", got " << base64String.length() << std::endl;
        CoUninitialize();
        return "";
    }

    // Cleanup
    SelectObject(hMemoryDC, hOldBitmap);
    DeleteObject(hBitmap);
    DeleteDC(hMemoryDC);
    ReleaseDC(NULL, hScreenDC);

    CoUninitialize();

    return base64String;
}

// END CUSTOM FUNCTIONS

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view())
  {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(), "com.realk.fluent_gpt",
      &flutter::StandardMethodCodec::GetInstance());
 
  channel.SetMethodCallHandler(
      [](const flutter::MethodCall<> &call,
         std::unique_ptr<flutter::MethodResult<>> result)
      {
        if (call.method_name() == "testResultFromSwift")
        {
          std::cout << "[C++] testResultFromSwift called" << std::endl;
          int battery_level = GetBatteryLevel();
          if (battery_level != -1)
          {
            result->Success(battery_level);
          }
          else
          {
            result->Error("UNAVAILABLE", "Battery level not available.");
          }
        }
        else if (call.method_name() == "getSelectedText")
        {
          std::cout << "[C++] getSelectedText called" << std::endl;
          result->Success(flutter::EncodableValue(GetSelectedText()));
        }
        else if (call.method_name() == "showOverlay")
        {
          std::cout << "[C++] showOverlay called" << std::endl;
          ShowOverlay();
          result->Success();
        }
        else if (call.method_name() == "requestNativePermissions")
        {
          std::cout << "[C++] requestNativePermissions called" << std::endl;
          RequestNativePermissions();
          result->Success();
        }
        else if (call.method_name() == "isAccessabilityGranted")
        {
          std::cout << "[C++] isAccessabilityGranted called" << std::endl;
          result->Success(flutter::EncodableValue(IsAccessibilityGranted()));
        }
        else if (call.method_name() == "initAccessibility")
        {
          std::cout << "[C++] initAccessibility called" << std::endl;
          InitAccessibility();
          result->Success();
        }
        else if (call.method_name() == "getScreenSize")
        {
          std::cout << "[C++] getScreenSize called" << std::endl;
          auto size = GetScreenSize();
          flutter::EncodableMap map;
          map[flutter::EncodableValue("width")] = flutter::EncodableValue(size.first);
          map[flutter::EncodableValue("height")] = flutter::EncodableValue(size.second);
          result->Success(flutter::EncodableValue(map));
        }
        else if (call.method_name() == "getMousePosition")
        {
          std::cout << "[C++] getMousePosition called" << std::endl;
          auto position = GetMousePosition();
          flutter::EncodableMap map;
          map[flutter::EncodableValue("positionX")] = flutter::EncodableValue(position.first);
          map[flutter::EncodableValue("positionY")] = flutter::EncodableValue(position.second);
          result->Success(flutter::EncodableValue(map));
        }
        else if (call.method_name() == "captureActiveScreen")
        {
          std::cout << "[C++] captureActiveScreen called" << std::endl;
          std::string base64String = captureActiveScreen();
          result->Success(flutter::EncodableValue(base64String));
        }
        else
        {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]()
                                                      { this->Show(); });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  

  return true;
}

void FlutterWindow::OnDestroy()
{
  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept
{
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result)
    {
      return *result;
    }
  }

  switch (message)
  {
  case WM_FONTCHANGE:
    flutter_controller_->engine()->ReloadSystemFonts();
    break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}