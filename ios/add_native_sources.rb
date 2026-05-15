#!/usr/bin/env ruby
# PageBundleLoader.h/.mm + SandboxApp-Bridging-Header.h 를 SandboxApp.xcodeproj 에 등록.
# 멱등.
#
# 그리고 SWIFT_OBJC_BRIDGING_HEADER build setting 을 SandboxApp/SandboxApp-Bridging-Header.h 로.
# CLANG_ENABLE_OBJC_ARC 는 .mm 가 자동으로 따라감.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('SandboxApp.xcodeproj', __dir__)
TARGET_NAME = 'SandboxApp'
GROUP_NAME = 'SandboxApp'

# (rel_path, file_type, build_phase) tuples
FILES = [
  ['SandboxApp/PageBundleLoader.h',           'sourcecode.c.h',         :resources],
  ['SandboxApp/PageBundleLoader.mm',          'sourcecode.cpp.objcpp',  :source],
  ['SandboxApp/SandboxApp-Bridging-Header.h', 'sourcecode.c.h',         :resources],
]

BRIDGING_HEADER_PATH = 'SandboxApp/SandboxApp-Bridging-Header.h'

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } or abort "target #{TARGET_NAME} not found"
group = project.main_group.find_subpath(GROUP_NAME, false) or abort "group #{GROUP_NAME} not found"

FILES.each do |rel, type, phase|
  filename = File.basename(rel)
  if group.files.any? { |f| f.path == rel || f.path == filename }
    puts "skip (already registered): #{rel}"
    next
  end
  file_ref = group.new_reference(rel)
  file_ref.name = filename
  file_ref.path = rel
  file_ref.last_known_file_type = type

  # .mm 만 Compile Sources, .h 들은 build phase 추가 불필요 (header 는 #import 만 되면 됨)
  if phase == :source
    target.source_build_phase.add_file_reference(file_ref, true)
  end
  puts "added: #{rel}"
end

# SWIFT_OBJC_BRIDGING_HEADER 를 Debug / Release 모두에 박는다.
target.build_configurations.each do |config|
  current = config.build_settings['SWIFT_OBJC_BRIDGING_HEADER']
  if current == BRIDGING_HEADER_PATH
    puts "skip (bridging header already set in #{config.name}): #{BRIDGING_HEADER_PATH}"
  else
    config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = BRIDGING_HEADER_PATH
    puts "set SWIFT_OBJC_BRIDGING_HEADER in #{config.name}: #{BRIDGING_HEADER_PATH}"
  end

  # CLANG_CXX_LANGUAGE_STANDARD 가 c++20 미설정이면 박는다. RN 0.83 의 jsi.h 는 c++20 요구.
  cxx_std = config.build_settings['CLANG_CXX_LANGUAGE_STANDARD']
  if cxx_std.nil? || cxx_std == ''
    config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++20'
    puts "set CLANG_CXX_LANGUAGE_STANDARD in #{config.name}: c++20"
  end
end

project.save
puts "saved: #{PROJECT_PATH}"
