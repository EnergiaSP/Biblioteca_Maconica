#!/usr/bin/env ruby
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'BibliotecaMaconica_Dev', 'BreviarioMaconicoXXI.xcodeproj')
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |target| target.name == 'BreviarioMaconicoXXI' }
abort 'Target principal não encontrado.' unless app

tests = project.targets.find { |target| target.name == 'BreviarioMaconicoXXITests' }
unless tests
  tests = project.new_target(:unit_test_bundle, 'BreviarioMaconicoXXITests', :ios, '17.0')
  tests.add_dependency(app)
end
tests.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.renatocamargo.BreviarioMaconicoSeculoXXIPrivado.tests'
  config.build_settings['PRODUCT_NAME'] = 'BreviarioMaconicoXXITests'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/BreviarioMaconicoXXI.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/BreviarioMaconicoXXI'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['SWIFT_VERSION'] = '6.0'
end

group = project.main_group.find_subpath('Tests', true)
group.set_source_tree('<group>')
group.set_path('Tests')
test_path = File.join(root, 'BibliotecaMaconica_Dev', 'Tests', 'BreviarioMaconicoXXITests.swift')
file = group.files.find { |candidate| candidate.path == 'BreviarioMaconicoXXITests.swift' }
file ||= group.new_file(test_path)
tests.source_build_phase.add_file_reference(file, true) unless tests.source_build_phase.files_references.include?(file)
project.save

scheme_path = File.join(project_path, 'xcshareddata', 'xcschemes', 'BreviarioMaconicoXXI.xcscheme')
scheme = Xcodeproj::XCScheme.new(scheme_path)
unless scheme.test_action.testables.any? { |testable| testable.buildable_references.first&.target_name == tests.name }
  scheme.test_action.add_testable(Xcodeproj::XCScheme::TestAction::TestableReference.new(tests))
end
unless scheme.build_action.entries.any? { |entry| entry.buildable_references.first&.target_name == tests.name }
  scheme.build_action.add_entry(Xcodeproj::XCScheme::BuildAction::Entry.new(tests))
end
scheme.save_as(project_path, 'BreviarioMaconicoXXI', true)
