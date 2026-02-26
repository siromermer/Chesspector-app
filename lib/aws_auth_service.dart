import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'api_config.dart';

const _region = ApiConfig.region;
const _identityPoolId = ApiConfig.identityPoolId;

const _unsignedPayload = BaseServiceConfiguration(signBody: false);

class AwsAuthService {
  static final AwsAuthService _instance = AwsAuthService._();
  factory AwsAuthService() => _instance;
  AwsAuthService._();

  AWSCredentials? _credentials;
  DateTime? _expiration;
  Future<AWSCredentials>? _pendingFetch;

  /// Pre-fetch credentials so they're ready when the first API call happens.
  void warmUp() {
    if (_credentials == null || _expiration == null ||
        !_expiration!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      _pendingFetch ??= _fetchCredentials();
    }
  }

  Future<AWSCredentials> _getCredentials() async {
    if (_credentials != null &&
        _expiration != null &&
        _expiration!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return _credentials!;
    }
    _pendingFetch ??= _fetchCredentials();
    return _pendingFetch!;
  }

  static const _timeout = Duration(seconds: 15);
  static const _apiTimeout = Duration(seconds: 30);

  Future<AWSCredentials> _fetchCredentials() async {
    try {
      final identityResponse = await http.post(
        Uri.parse('https://cognito-identity.$_region.amazonaws.com/'),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target': 'AWSCognitoIdentityService.GetId',
        },
        body: jsonEncode({'IdentityPoolId': _identityPoolId}),
      ).timeout(_timeout);

      if (identityResponse.statusCode != 200) {
        throw Exception('Cognito GetId failed (${identityResponse.statusCode})');
      }

      final identityId =
          jsonDecode(identityResponse.body)['IdentityId'] as String;

      final credsResponse = await http.post(
        Uri.parse('https://cognito-identity.$_region.amazonaws.com/'),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target':
              'AWSCognitoIdentityService.GetCredentialsForIdentity',
        },
        body: jsonEncode({'IdentityId': identityId}),
      ).timeout(_timeout);

      if (credsResponse.statusCode != 200) {
        throw Exception(
            'Cognito GetCredentials failed (${credsResponse.statusCode})');
      }

      final credsJson = jsonDecode(credsResponse.body)['Credentials'];
      _expiration = DateTime.fromMillisecondsSinceEpoch(
        ((credsJson['Expiration'] as num) * 1000).toInt(),
      );
      _credentials = AWSCredentials(
        credsJson['AccessKeyId'] as String,
        credsJson['SecretKey'] as String,
        credsJson['SessionToken'] as String,
        _expiration,
      );
      return _credentials!;
    } finally {
      _pendingFetch = null;
    }
  }

  /// Send a SigV4-signed POST to an API Gateway endpoint.
  Future<http.Response> signedPost(String url, String body) async {
    final credentials = await _getCredentials();
    final uri = Uri.parse(url);

    final signer = AWSSigV4Signer(
      credentialsProvider: AWSCredentialsProvider(credentials),
    );

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: uri,
      headers: {
        AWSHeaders.host: uri.host,
        AWSHeaders.contentType: 'application/json',
      },
      body: utf8.encode(body),
    );

    final scope = AWSCredentialScope(
      region: _region,
      service: AWSService('execute-api'),
    );

    final signedRequest = await signer.sign(
      request,
      credentialScope: scope,
      serviceConfiguration: _unsignedPayload,
    );

    final response = await http.post(
      uri,
      headers: Map<String, String>.from(signedRequest.headers),
      body: body,
    ).timeout(_apiTimeout);

    return response;
  }
}
