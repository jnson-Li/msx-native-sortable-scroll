Pod::Spec.new do |s|
  s.name         = "MSXNativeSortableScroll"
  s.version      = "0.0.1"
  s.summary      = "Native drag sortable scroll container for React Native"
  s.homepage     = "https://example.invalid/msx-native-sortable-scroll"
  s.license      = { :type => "MIT" }
  s.authors      = { "OpenAI" => "support@openai.com" }
  s.platforms    = { :ios => "15.1" }
  s.source       = { :path => "." }
  s.source_files = "ios/**/*.{h,m,mm}"
  s.requires_arc = true

  s.dependency "React-Core"
  s.dependency "React-RCTImage"
  s.dependency "React-Codegen"
end
