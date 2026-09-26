import 'package:flutter/foundation.dart';

// Local prototype server. The launch script overrides this if the Mac's IP
// changes. A normal IDE debug launch also works without additional arguments.
// Release/profile builds must supply their own endpoint explicitly.
const faceAnalysisBaseUrl = String.fromEnvironment(
  'FACE_ANALYSIS_URL',
  defaultValue: kDebugMode ? 'http://192.168.1.11:8000' : '',
);
