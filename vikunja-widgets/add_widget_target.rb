#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'vikunja.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'vikunja' } or abort 'no app target'

PKG_PATH = 'Packages/VikuWidgetKit'
PRODUCT  = 'VikuWidgetKit'
WIDGET_NAME = 'vikunja-widgets'

# --- 1. Local Swift package reference -----------------------------------------
pkg_ref = project.root_object.package_references.find do |r|
  r.isa == 'XCLocalSwiftPackageReference' && r.relative_path == PKG_PATH
end
unless pkg_ref
  pkg_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  pkg_ref.relative_path = PKG_PATH
  project.root_object.package_references << pkg_ref
  puts "+ XCLocalSwiftPackageReference #{PKG_PATH}"
end

def new_product_dep(project, pkg_ref, name)
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = pkg_ref
  dep.product_name = name
  dep
end

def link_product(project, target, dep)
  target.package_product_dependencies << dep
  bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  target.frameworks_build_phase.files << bf
end

# --- 2. Widget extension target ---------------------------------------------
widget_target = project.targets.find { |t| t.name == WIDGET_NAME }
if widget_target
  puts "= target #{WIDGET_NAME} already exists"
else
  widget_target = project.new_target(
    :app_extension, WIDGET_NAME, :ios, '26.2', nil, :swift
  )
  puts "+ target #{WIDGET_NAME}"
end

# Product type must be the widgetkit extension flavor.
widget_target.product_type = 'com.apple.product-type.app-extension'

# --- 3. File-system-synchronized group for vikunja-widgets/ -----------------
fss = project.main_group.children.find do |c|
  c.isa == 'PBXFileSystemSynchronizedRootGroup' && c.path == WIDGET_NAME
end
unless fss
  fss = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
  fss.source_tree = '<group>'
  fss.path = WIDGET_NAME
  project.main_group.children << fss
  puts "+ PBXFileSystemSynchronizedRootGroup #{WIDGET_NAME}"
end
unless widget_target.file_system_synchronized_groups.include?(fss)
  widget_target.file_system_synchronized_groups << fss
end

# Info.plist / entitlements / docs are referenced via build settings, not as
# bundle resources — exclude them from the synchronized target membership so
# Xcode doesn't also copy Info.plist into the appex (which collides with
# ProcessInfoPlistFile).
fss.exceptions ||= []
already = fss.exceptions.any? { |e| e.target == widget_target }
unless already
  ex = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedBuildFileExceptionSet)
  ex.target = widget_target
  ex.membership_exceptions = ['Info.plist', 'vikunja-widgets.entitlements', 'WIDGET_SETUP.md', 'add_widget_target.rb']
  fss.exceptions << ex
  puts '+ FSS membership exceptions (Info.plist, entitlements, docs)'
end

# --- 4. Link VikuWidgetKit into the widget target and the app -----------
unless widget_target.package_product_dependencies.any? { |d| d.product_name == PRODUCT }
  link_product(project, widget_target, new_product_dep(project, pkg_ref, PRODUCT))
  puts "+ #{PRODUCT} -> #{WIDGET_NAME}"
end
unless app_target.package_product_dependencies.any? { |d| d.product_name == PRODUCT }
  link_product(project, app_target, new_product_dep(project, pkg_ref, PRODUCT))
  puts "+ #{PRODUCT} -> vikunja (app)"
end

# --- 5. Build settings for the widget target -------------------------------
common = {
  'CODE_SIGN_ENTITLEMENTS'        => 'vikunja-widgets/vikunja-widgets.entitlements',
  'CODE_SIGN_STYLE'               => 'Automatic',
  'CURRENT_PROJECT_VERSION'       => '1',
  'DEVELOPMENT_TEAM'              => '5CM24MBKSG',
  'ENABLE_PREVIEWS'              => 'YES',
  'GENERATE_INFOPLIST_FILE'      => 'YES',
  'INFOPLIST_FILE'               => 'vikunja-widgets/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Vikunja',
  'INFOPLIST_KEY_NSHumanReadableCopyright' => '',
  'IPHONEOS_DEPLOYMENT_TARGET'   => '26.2',
  'LD_RUNPATH_SEARCH_PATHS'      => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
  'MARKETING_VERSION'           => '1.0',
  'PRODUCT_NAME'                => '$(TARGET_NAME)',
  'SKIP_INSTALL'                => 'YES',
  'SWIFT_APPROACHABLE_CONCURRENCY' => 'YES',
  'SWIFT_DEFAULT_ACTOR_ISOLATION'  => 'MainActor',
  'SWIFT_EMIT_LOC_STRINGS'      => 'YES',
  'SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY' => 'YES',
  'SWIFT_VERSION'              => '5.0',
  'TARGETED_DEVICE_FAMILY'     => '1,2',
}

widget_target.build_configurations.each do |config|
  config.build_settings.merge!(common)
  if config.name == 'Debug'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.sergiosuarez.vikunja.dev.widgets'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  else
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.sergiosuarez.vikunja.widgets'
    config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
  end
end

# --- 6. Embed the extension into the app -----------------------------------
embed = app_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  embed = app_target.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ''
  puts '+ Embed Foundation Extensions phase'
end
unless embed.files_references.include?(widget_target.product_reference)
  bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.file_ref = widget_target.product_reference
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  embed.files << bf
  puts '+ embed vikunja-widgets.appex'
end

# Make sure the app builds the extension first.
unless app_target.dependencies.any? { |d| d.target == widget_target }
  app_target.add_dependency(widget_target)
  puts '+ app depends on widget target'
end

# --- 7. App target entitlements ------------------------------------------
app_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'vikunja/vikunja.entitlements'
end
puts '= app CODE_SIGN_ENTITLEMENTS -> vikunja/vikunja.entitlements'

# --- 8. Per-config identifiers (project level, inherited by both targets) --
# App Group / keychain group / URL scheme are split dev vs prod so a Debug and
# a Release install on the same device don't share storage. The .entitlements
# and Info.plist expand $(VIKUNJA_ID_PREFIX) / $(VIKUNJA_URL_SCHEME);
# VikunjaWidgetConfig mirrors the prefix with #if DEBUG.
project.build_configurations.each do |config|
  if config.name == 'Debug'
    config.build_settings['VIKUNJA_ID_PREFIX'] = 'dev.sergiosuarez.vikunja.dev'
    config.build_settings['VIKUNJA_URL_SCHEME'] = 'vikunja-dev'
  else
    config.build_settings['VIKUNJA_ID_PREFIX'] = 'dev.sergiosuarez.vikunja'
    config.build_settings['VIKUNJA_URL_SCHEME'] = 'vikunja'
  end
end
puts '= project VIKUNJA_ID_PREFIX / VIKUNJA_URL_SCHEME (per config)'

project.save
puts 'saved.'
