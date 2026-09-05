import 'package:flutter/foundation.dart';

const String kDefaultIosLoginServerUrl = 'http://192.168.1.100:19922';

String? initialLoginServerUrl({required String? storedServerUrl, required TargetPlatform platform}) {
  if (storedServerUrl != null) {
    return storedServerUrl;
  }

  return platform == TargetPlatform.iOS ? kDefaultIosLoginServerUrl : null;
}
