#!/usr/bin/env ruby
# 새 Swift 파일을 SandboxApp.xcodeproj 에 등록.
# 멱등: 이미 등록된 파일은 skip.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('SandboxApp.xcodeproj', __dir__)
TARGET_NAME = 'SandboxApp'
GROUP_NAME = 'SandboxApp'

# .swift / .mm / .h / .m 모두 같은 멱등 라우트. 확장자별로 last_known_file_type 만 다름.
FILES = [
  'SandboxApp/DevToolViewController.swift',
  'SandboxApp/RNContainerViewController.swift',
  'SandboxApp/LifePlusApp.h',
  'SandboxApp/LifePlusApp.mm',
]

FILE_TYPES = {
  '.swift' => 'sourcecode.swift',
  '.mm'    => 'sourcecode.cpp.objcpp',
  '.m'     => 'sourcecode.c.objc',
  '.h'     => 'sourcecode.c.h',
}

# build phase 에 들어가야 할 source 확장자만 (header 는 register only).
COMPILE_EXTS = ['.swift', '.mm', '.m'].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } or abort "target #{TARGET_NAME} not found"
group = project.main_group.find_subpath(GROUP_NAME, false) or abort "group #{GROUP_NAME} not found"

FILES.each do |rel|
  filename = File.basename(rel)
  ext = File.extname(filename)
  file_type = FILE_TYPES[ext] or abort "unsupported file extension: #{ext}"

  if group.files.any? { |f| f.path == rel || f.path == filename }
    puts "skip (already registered): #{rel}"
    next
  end
  # SandboxApp group 이 path 속성을 안 가지므로, file_ref.path 에 SandboxApp/{filename} 으로 박는다.
  # group.new_reference(rel) 만 쓰면 path=rel 이 되지만 name 은 비어서 Xcode UI 가 SandboxApp/X.swift 로 표시.
  # 다른 멤버들(Info.plist, Images.xcassets 등)과 동일한 형태로 name=filename, path=rel 을 명시.
  file_ref = group.new_reference(rel)
  file_ref.name = filename
  file_ref.path = rel
  file_ref.last_known_file_type = file_type
  if COMPILE_EXTS.include?(ext)
    target.source_build_phase.add_file_reference(file_ref, true)
  end
  puts "added: #{rel}"
end

project.save
puts "saved: #{PROJECT_PATH}"
