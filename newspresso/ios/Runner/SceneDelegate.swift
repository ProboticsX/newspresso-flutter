import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Intercept Universal Links (https://) before FlutterSceneDelegate can fall back to Safari.
        // app_links returns false from its application delegate handler, which causes
        // FlutterSceneDelegate to open the URL in Safari as a fallback.
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            AppLinks.shared.handleLink(url: url)
            return
        }
        super.scene(scene, continue: userActivity)
    }
}
