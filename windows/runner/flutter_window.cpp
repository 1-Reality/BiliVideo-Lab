#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "flutter/standard_method_codec.h"
#include "network_traffic_meter.h"

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

  network_traffic_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "org.brotech.piliplus/network_traffic",
          &flutter::StandardMethodCodec::GetInstance());
  network_traffic_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "installMediaHook") {
          result->Success(flutter::EncodableValue(InstallMediaWinsockMeter()));
          return;
        }
        if (call.method_name() == "trafficCounters") {
          InstallMediaWinsockMeter();
          const NetworkByteCounters media = GetMediaWinsockCounters();
          const NetworkByteCounters network = GetActiveInterfaceCounters();
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("media"),
               flutter::EncodableValue(flutter::EncodableMap{
                   {flutter::EncodableValue("received"),
                    flutter::EncodableValue(
                        static_cast<int64_t>(media.received))},
                   {flutter::EncodableValue("sent"),
                    flutter::EncodableValue(static_cast<int64_t>(media.sent))},
                   {flutter::EncodableValue("available"),
                    flutter::EncodableValue(media.available)},
                   {flutter::EncodableValue("sourceId"),
                    flutter::EncodableValue(
                        static_cast<int64_t>(media.source_id))},
               })},
              {flutter::EncodableValue("interface"),
               flutter::EncodableValue(flutter::EncodableMap{
                   {flutter::EncodableValue("received"),
                    flutter::EncodableValue(
                        static_cast<int64_t>(network.received))},
                   {flutter::EncodableValue("sent"),
                    flutter::EncodableValue(
                        static_cast<int64_t>(network.sent))},
                   {flutter::EncodableValue("available"),
                    flutter::EncodableValue(network.available)},
                   {flutter::EncodableValue("sourceId"),
                    flutter::EncodableValue(
                        static_cast<int64_t>(network.source_id))},
               })},
          }));
          return;
        }
        NetworkByteCounters counters{};
        if (call.method_name() == "mediaCounters") {
          InstallMediaWinsockMeter();
          counters = GetMediaWinsockCounters();
        } else if (call.method_name() == "interfaceCounters") {
          counters = GetActiveInterfaceCounters();
        } else {
          result->NotImplemented();
          return;
        }
        result->Success(flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("received"),
             flutter::EncodableValue(static_cast<int64_t>(counters.received))},
            {flutter::EncodableValue("sent"),
             flutter::EncodableValue(static_cast<int64_t>(counters.sent))},
            {flutter::EncodableValue("available"),
             flutter::EncodableValue(counters.available)},
            {flutter::EncodableValue("sourceId"),
             flutter::EncodableValue(static_cast<int64_t>(counters.source_id))},
        }));
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // flutter_controller_->engine()->SetNextFrameCallback([&]() {
  //   this->Show();
  // });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    network_traffic_channel_.reset();
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
