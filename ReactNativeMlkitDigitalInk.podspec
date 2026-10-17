require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "ReactNativeMlkitDigitalInk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/goaid/react-native-mlkit-digital-ink.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"

  s.swift_version = "5.9"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    # Forces the Swift half of this pod to compile as a single unit so the
    # generated Objective-C compatibility header (imported by the .mm files
    # below) always reflects every Swift file at once — avoids a real,
    # observed race between Xcode's per-file incremental Swift compilation
    # and the header-merge step.
    "SWIFT_COMPILATION_MODE" => "wholemodule"
  }

  s.dependency "GoogleMLKit/DigitalInkRecognition", "~> 7.0"
  s.dependency "TensorFlowLiteSwift", "~> 2.16"

  install_modules_dependencies(s)
end
