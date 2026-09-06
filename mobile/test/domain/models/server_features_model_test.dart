import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/models/server_info/server_features.model.dart';
import 'package:openapi/api.dart';

void main() {
  test('maps duplicate detection capability from the server DTO', () {
    final dto = ServerFeaturesDto(
      configFile: false,
      duplicateDetection: true,
      email: false,
      facialRecognition: true,
      importFaces: false,
      map: false,
      oauth: false,
      oauthAutoLaunch: false,
      ocr: true,
      passwordLogin: true,
      realtimeTranscoding: false,
      reverseGeocoding: false,
      search: true,
      sidecar: false,
      smartSearch: true,
      trash: true,
    );

    expect(ServerFeatures.fromDto(dto).duplicateDetection, isTrue);
  });
}
