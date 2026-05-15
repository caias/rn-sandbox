source 'https://rubygems.org'

# You may use http://rbenv.org/ or https://rvm.io/ to install and use this version
ruby ">= 2.6.10"

# Exclude problematic versions of cocoapods and activesupport that causes build failures.
# cocoapods 1.15.0~1.15.2 + Ruby 3.2 조합에서 String#unicode_normalize 에 ASCII-8BIT 호환 버그.
# 1.16+ 에서 fix. (https://github.com/CocoaPods/CocoaPods/pull/12387)
gem 'cocoapods', '>= 1.16'
gem 'activesupport', '>= 6.1.7.5', '!= 7.1.0'
gem 'xcodeproj'
gem 'concurrent-ruby', '< 1.3.4'

# Ruby 3.4.0 has removed some libraries from the standard library.
gem 'bigdecimal'
gem 'logger'
gem 'benchmark'
gem 'mutex_m'
