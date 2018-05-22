
Pod::Spec.new do |s|
  s.name             = "react-native-stripe"
  s.version          = "1.0.0"
  s.summary          = "A React Native wrapper for Stripe payment methods"
  s.requires_arc = true
  s.author       = { 'Guido Lodetti' => 'guido.lode@gmail.com' }
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/naoufal/react-native-safari-view'
  s.source       = { :git => "https://github.com/naoufal/react-native-safari-view.git" }
  s.platform     = :ios, "7.0"
  s.dependency 'React'
  s.dependency 'Stripe'
  s.source_files     = "ios/*.{h,m}"
  s.preserve_paths   = "ios/*.js"
  s.resources = "card-icons/*.png"
end
