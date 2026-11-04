# iOS eklentilerini Xcode projesine hedef olarak ekler:
#   - ShareExtension: TikTok → Paylaş → Buzdolabı Şefi
#   - HomeWidget:     iPhone ana ekran aracı (WidgetKit)
# ve her hedefe Apple gizlilik bildirimini (PrivacyInfo.xcprivacy) koyar.
#
# Mac'te Xcode ile elle yapılacak işi GitHub Actions'ta otomatik yapar:
#   ruby ios/scripts/add_share_extension.rb
# Tekrar çalıştırmak güvenlidir; var olan hedeflere dokunmaz.
# CocoaPods ile gelen "xcodeproj" gem'ini kullanır.

require 'xcodeproj'

ios_dir = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(ios_dir, 'Runner.xcodeproj'))

runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner hedefi yok'
bundle_id = runner.build_configurations
                  .map { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
                  .compact.first or abort 'Runner paket kimliği bulunamadı'
app_group = "group.#{bundle_id}"

flutter_group = project.main_group.find_subpath('Flutter', false) or abort 'Flutter grubu yok'
runner_group = project.main_group.find_subpath('Runner', false) or abort 'Runner grubu yok'

def file_in(group, name)
  group.files.find { |f| f.path == name || f.display_name == name }
end

# --- Uygulama: ortak kutu yetkisi ve gizlilik bildirimi
runner.build_configurations.each do |c|
  c.build_settings['APP_GROUP_ID'] = app_group
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
file_in(runner_group, 'Runner.entitlements') || runner_group.new_reference('Runner.entitlements')
unless file_in(runner_group, 'PrivacyInfo.xcprivacy')
  runner.add_resources([runner_group.new_reference('PrivacyInfo.xcprivacy')])
end

xcconfig = file_in(flutter_group, 'ShareExtension.xcconfig') ||
           file_in(flutter_group, 'Flutter/ShareExtension.xcconfig')
unless xcconfig
  xcconfig = flutter_group.new_reference('ShareExtension.xcconfig')
  xcconfig.set_path('Flutter/ShareExtension.xcconfig') if flutter_group.path.nil?
end

embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  # Flutter'ın "Thin Binary" betiğinden önce gömülmezse Xcode
  # "Cycle inside Runner" hatası verir.
  phases = runner.build_phases
  phases.delete(embed)
  thin = phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
  phases.insert(thin || phases.length, embed)
end

EXTENSIONS = [
  { name: 'ShareExtension', sources: ['ShareViewController.swift'] },
  { name: 'HomeWidget', sources: ['HomeWidget.swift'] },
].freeze

EXTENSIONS.each do |ext_def|
  name = ext_def[:name]
  if project.targets.any? { |t| t.name == name }
    puts "#{name} hedefi zaten var."
    next
  end

  group = project.main_group.find_subpath(name, true)
  group.set_source_tree('<group>')
  group.set_path(name)
  sources = ext_def[:sources].map { |s| group.new_reference(s) }
  group.new_reference('Info.plist')
  group.new_reference("#{name}.entitlements")
  privacy = group.new_reference('PrivacyInfo.xcprivacy')

  ext = project.new_target(:app_extension, name, :ios, '15.0', nil, :swift)
  ext.add_file_references(sources)
  ext.add_resources([privacy])
  ext.build_configurations.each do |c|
    c.base_configuration_reference = xcconfig
    s = c.build_settings
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.#{name}"
    s['APP_GROUP_ID'] = app_group
    s['INFOPLIST_FILE'] = "#{name}/Info.plist"
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['SWIFT_VERSION'] = '5.0'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    s['TARGETED_DEVICE_FAMILY'] = '1'
    s['SKIP_INSTALL'] = 'YES'
    s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks',
                                    '@executable_path/../../Frameworks']
  end

  runner.add_dependency(ext)
  embed.add_file_reference(ext.product_reference, true)
       .settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  puts "#{name} eklendi (#{bundle_id}.#{name})."
end

project.save
puts "Uygulama grubu: #{app_group}"
