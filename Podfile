# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'BookReader' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Firebase pods
  pod 'Firebase/Analytics'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Crashlytics'
  
  # Firebase UI (optional but helpful for auth)
  pod 'FirebaseUI/Auth'
  pod 'FirebaseUI/Email'
  pod 'FirebaseUI/OAuth' # For Sign in with Apple
  
  # Offline support
  pod 'FirebaseFirestoreSwift'

  target 'BookReaderTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'BookReaderUITests' do
    # Pods for testing
  end
end

# Post install hook to fix any build issues
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end