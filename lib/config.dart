/// App-wide configuration constants
class AppConfig {
  AppConfig._();

  /// Production URL (Cloudflare Workers)
  static const String appUrl = 'https://driverlog-flutter.kanut-k3.workers.dev';
  static const String websiteShortUrl = 'https://bit.ly/driverlog-th';

  /// Short display label
  static const String appLabel = 'driverLog';

  /// App version — อัปเดตตรงนี้ที่เดียว (ตรงกับ pubspec.yaml)
  static const String appVersion = '1.1.0';
  static const String buildNumber = '2';
}
