#!/usr/bin/env ruby
# shared.bundle.js (단일 파일) + pages/ (folder reference) 를 SandboxApp.xcodeproj 의
# Resources build phase 에 등록.
#
# 멱등: 이미 등록된 항목은 skip.
#
# folder reference 로 pages/ 를 박으면 디렉토리 안의 새 page bundle 이 자동으로
# Copy Bundle Resources 에 포함됨 → page 추가/제거 시 pbxproj 재수정 불필요.
# 런타임에 Bundle.main.url(forResource: "pages/HelloRN.bundle", withExtension: "js") 로 lookup 가능.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('SandboxApp.xcodeproj', __dir__)
TARGET_NAME = 'SandboxApp'
GROUP_NAME = 'SandboxApp'

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } or abort "target #{TARGET_NAME} not found"
group = project.main_group.find_subpath(GROUP_NAME, false) or abort "group #{GROUP_NAME} not found"

resources_phase = target.resources_build_phase

def already_registered?(group, rel, filename)
  group.files.any? { |f| f.path == rel || f.path == filename }
end

# 1) shared.bundle.js (단일 파일)
shared_rel = 'SandboxApp/shared.bundle.js'
shared_filename = File.basename(shared_rel)
if already_registered?(group, shared_rel, shared_filename)
  puts "skip (already registered): #{shared_rel}"
else
  file_ref = group.new_reference(shared_rel)
  file_ref.name = shared_filename
  file_ref.path = shared_rel
  file_ref.last_known_file_type = 'text'
  resources_phase.add_file_reference(file_ref, true)
  puts "added: #{shared_rel}"
end

# 2) pages/ (folder reference — 디렉토리 통째로)
#    new_reference 가 디렉토리 경로를 받으면 group child 로 추가되긴 하지만 file_ref
#    가 디렉토리를 가리키려면 last_known_file_type='folder' + sourceTree 설정 필요.
#    Xcodeproj 의 PBXFileReference 로 직접 만들고 path / lastKnownFileType / sourceTree 를
#    명시한다.
pages_rel = 'SandboxApp/pages'
pages_filename = File.basename(pages_rel)
if already_registered?(group, pages_rel, pages_filename)
  puts "skip (already registered): #{pages_rel}"
else
  folder_ref = group.new_reference(pages_rel)
  folder_ref.name = pages_filename
  folder_ref.path = pages_rel
  folder_ref.last_known_file_type = 'folder'
  # Xcode 가 디렉토리를 통째로 .app/pages 로 복사 (Copy Bundle Resources).
  resources_phase.add_file_reference(folder_ref, true)
  puts "added (folder reference): #{pages_rel}"
end

project.save
puts "saved: #{PROJECT_PATH}"
