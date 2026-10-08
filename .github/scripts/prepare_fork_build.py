"""CI-only preparation: use CocoaPods and omit upstream Android telemetry."""
from pathlib import Path
import sys


def replace_once(path, before, after):
    text = path.read_text(encoding="utf-8")
    if text.count(before) != 1:
        raise RuntimeError(f'Upstream structure changed; review CI preparation: {path}')
    with path.open("w", encoding="utf-8", newline="\n") as output:
        output.write(text.replace(before, after, 1))


def main():
    app = Path('simple_live_app')
    replace_once(app / 'pubspec.yaml', '\nflutter: \n',
                 '\nflutter: \n  config:\n    enable-swift-package-manager: false\n')
    if sys.argv[1] != 'android':
        return
    gradle = app / 'android/app/build.gradle.kts'
    for plugin in ('com.google.gms.google-services', 'com.google.firebase.crashlytics'):
        replace_once(gradle, f'    id("{plugin}")', f'    // {plugin} disabled for fork test builds')
    replace_once(app / 'lib/main.dart', '  if (Platform.isAndroid) {\n    await Firebase.initializeApp(',
                 '  if (false) {\n    await Firebase.initializeApp(')
    replace_once(app / 'lib/services/firebase_service.dart',
                 '  static Future<void> setCrashlytics(bool enable) async {',
                 '  static Future<void> setCrashlytics(bool enable) async {\n    return; // No Firebase configuration in fork test builds.')
    observer = app / 'lib/routes/app_analytics_observer.dart'
    # Guard the only telemetry call, leaving navigation lifecycle intact.
    replace_once(observer, '    FirebaseAnalytics.instance.logScreenView(',
                 '    if (false) FirebaseAnalytics.instance.logScreenView(')


if __name__ == '__main__':
    main()
