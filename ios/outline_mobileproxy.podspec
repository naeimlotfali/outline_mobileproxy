#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint outline_mobileproxy.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'outline_mobileproxy'
  s.version          = '0.0.1'
  s.summary          = 'Outline SDK Mobileproxy bindings for Flutter.'
  s.description      = <<-DESC
Flutter plugin wrapping the Outline SDK's Mobileproxy Go Mobile library
(golang.getoutline.org/sdk/x/mobileproxy) to run a local proxy on iOS.
                       DESC
  s.homepage         = 'https://github.com/OutlineFoundation/outline-sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Go Mobile bindings for golang.getoutline.org/sdk/x/mobileproxy, built with:
  #   gomobile bind -target=ios -iosversion=13.0 -o Mobileproxy.xcframework golang.getoutline.org/sdk/x/mobileproxy
  # See tool/build_native.sh at the repo root to rebuild it.
  s.vendored_frameworks = 'Frameworks/Mobileproxy.xcframework'
  s.preserve_paths = 'Frameworks/Mobileproxy.xcframework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'outline_mobileproxy_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
