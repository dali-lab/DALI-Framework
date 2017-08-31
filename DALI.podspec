#
# Be sure to run `pod lib lint DALI.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DALI'
  s.version          = '0.2.963'
  s.summary          = 'A framework for iOS and tvOS that will handle all the needs of a DALI member working on an internal project'

  s.description      = <<-DESC
As a DALI member, have you ever wondered if you could make an app that does all the things that the DALI Lab app can do and more?!
  Well you can! With this framework you can access all sorts of information from the DALI API database, and get access
  to many other features!
                       DESC

  s.homepage         = 'https://dali-lab.github.io/DALI-Framework/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'John Kotz' => 'john.kotz@dali.dartmouth.edu' }
  s.source           = { :git => 'https://github.com/dali-lab/DALI-Framework.git', :tag => 'v0.2.963' }

  s.ios.deployment_target = '8.3'
  s.tvos.deployment_target = '10.0'

  s.source_files = 'DALI/Classes/**/*'

  s.frameworks = 'Foundation'
  s.dependency 'SwiftyJSON'
  s.source_files = 'DALI/Classes/*.{swift}'

  s.documentation_url = 'https://dali-lab.github.io/DALI-Framework/'
end
