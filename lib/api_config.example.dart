/// TEMPLATE — Copy this file to api_config.dart and fill in your values.
/// api_config.dart is git-ignored; this template is committed for reference.

class ApiConfig {
  ApiConfig._();

  // AWS Region
  static const String region = 'YOUR_AWS_REGION';

  // Cognito Identity Pool ID (unauthenticated access)
  static const String identityPoolId = 'YOUR_COGNITO_IDENTITY_POOL_ID';

  // Corner extraction (static perspective)
  static const String staticApiUrl = 'YOUR_STATIC_API_URL';

  // Corner extraction (dynamic perspective)
  static const String dynamicApiUrl = 'YOUR_DYNAMIC_API_URL';

  // Piece detection
  static const String pieceDetectionApiUrl = 'YOUR_PIECE_DETECTION_API_URL';
}
