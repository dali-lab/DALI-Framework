#
# Be sure to run `pod lib lint DALI.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DALI'
  s.version          = '0.1.0'
  s.summary          = 'A framework for iOS and tvOS that will handle all the needs of a DALI member working on an internal project'

  s.description      = <<-DESC
As a DALI member, have you ever wondered if you could make an app that does all the things that the DALI Lab app can do and more?!
                       DESC

  s.homepage         = 'https://dali-lab.github.io/API-iOS-Framework/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'johnlev' => 'john.lyme@mac.com' }
  s.source           = { :git => 'https://github.com/dali-lab/DALI-Framework.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.watchos.deployment_target = '3.1'
  s.tvos.deployment_target = '10.0'

  s.source_files = 'DALI/Classes/**/*'

  s.frameworks = 'Foundation'
  s.dependency 'SwiftyJSON'
  s.source_files = 'DALI/Classes/*.{swift}'
end
