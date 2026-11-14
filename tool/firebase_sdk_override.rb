# Firebase iOS SDK 12.19.3 is not yet published to the CocoaPods CDN.
# firebase_core 5.1.0 exposes the $FirebaseSDKVersion global so the pinned
# version can be overridden at pod evaluation time. 12.19.0 is the latest
# version available from trunk, so use it for the CocoaPods build.
$FirebaseSDKVersion = '12.19.0'
