#!/usr/bin/env ruby
# mono 회귀용으로 등록했던 main.jsbundle 의 file reference + build phase 항목을 제거.
# multi-bundle 모드 정식 전환 후 더 이상 .app 에 박을 필요 없음.
# 멱등.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('SandboxApp.xcodeproj', __dir__)
TARGET_NAME = 'SandboxApp'

TARGET_PATHS = ['SandboxApp/main.jsbundle']

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } or abort "target #{TARGET_NAME} not found"

removed = false
project.files.dup.each do |f|
  if TARGET_PATHS.include?(f.path)
    # 모든 build phase 에서 reference 제거
    target.build_phases.each do |phase|
      next unless phase.respond_to?(:files)
      phase.files.dup.each do |bf|
        if bf.file_ref == f
          phase.remove_build_file(bf)
          puts "removed from #{phase.display_name}: #{f.path}"
        end
      end
    end
    f.remove_from_project
    puts "removed file ref: #{f.path}"
    removed = true
  end
end

unless removed
  puts "no matching refs (already clean)"
end

project.save
puts "saved: #{PROJECT_PATH}"
