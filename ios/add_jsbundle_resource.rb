#!/usr/bin/env ruby
# main.jsbundle 을 SandboxApp.xcodeproj 의 Resources build phase 에 등록.
# 멱등: 이미 등록된 파일은 skip.
#
# 파일 자체는 ios/SandboxApp/main.jsbundle 위치에 두고, Xcode 가 Copy Bundle Resources
# 단계에서 .app 번들로 복사한다 → 런타임에 Bundle.main.url(forResource: "main", withExtension: "jsbundle")
# 로 찾을 수 있다.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('SandboxApp.xcodeproj', __dir__)
TARGET_NAME = 'SandboxApp'
GROUP_NAME = 'SandboxApp'
FILES = ['SandboxApp/main.jsbundle']

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } or abort "target #{TARGET_NAME} not found"
group = project.main_group.find_subpath(GROUP_NAME, false) or abort "group #{GROUP_NAME} not found"

FILES.each do |rel|
  filename = File.basename(rel)
  if group.files.any? { |f| f.path == rel || f.path == filename }
    puts "skip (already registered): #{rel}"
    next
  end
  file_ref = group.new_reference(rel)
  file_ref.name = filename
  file_ref.path = rel
  file_ref.last_known_file_type = 'text'
  target.resources_build_phase.add_file_reference(file_ref, true)
  puts "added: #{rel}"
end

project.save
puts "saved: #{PROJECT_PATH}"
