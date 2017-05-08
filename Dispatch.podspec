#
# Be sure to run `pod lib lint Render.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Dispatch"
  s.version          = "0.1"
  s.summary          = "Multi-store Flux implementation in Swift."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  A lightweight, operation based, multi-store Flux implementation in Swift.
                       DESC

  s.homepage         = "https://github.com/alexdrone/Dispatch"
  s.screenshots      = "https://github.com/alexdrone/Dispatch/raw/master/doc/logo.png"
  s.license          = 'MIT'
  s.author           = { "Alex Usbergo" => "alexakadrone@gmail.com" }
  s.source           = { :git => "https://github.com/alexdrone/Dispatch.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/alexdrone'

  s.ios.deployment_target = '10.0'
  s.source_files = 'src/**/*'

  # s.public_header_files = 'Pod/Classes/**/*.h'
 	s.frameworks = 'Foundation', 'UIKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end