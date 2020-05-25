import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:flutter_openvidu_demo/utils/RequestConfig.dart';

class ApiClient{
  final HttpClient client = HttpClient();

  Map<String, String> get getDefaultHeaders{
    final Map<String, String> defaultHeaders = <String, String>{};
    return defaultHeaders;
  }

  /// Use this instead of [getAction], [postAction] and [putAction]
  Future<T> request<T>(Config config, {bool autoLogin = false}) async {
    print('[${config.method}] Sending request: ${config.uri.toString()}');

    final HttpClientRequest _request = await client.openUrl(config.method, config.uri)
      .then((HttpClientRequest request) => _addHeaders(request, config))
      .then((HttpClientRequest request) => _addCookies(request, config))
      .then((HttpClientRequest request) => _addBody(request, config));

    final HttpClientResponse _response = await _request.close();

    print('[${config.method}] Received: ${_response.reasonPhrase} [${_response.statusCode}] - ${config.uri.toString()}');

    if(_response.statusCode == HttpStatus.ok){
      return config.hasResponse ? Future<T>.value(config.responseType.parse(_response)) : Future<HttpClientResponse>.value(_response);
    }

    return await _processError(_response, config, onAutoLoginSuccess: () => request<T>(config));
  }

  HttpClientRequest _addBody(HttpClientRequest request, Config config) {
    if (config.hasBody) {
      request.headers.contentType = config.body.getContentType();
      request.contentLength = const Utf8Encoder().convert(config.body.getBody()).length;
      request.write(config.body.getBody());
    }

    return request;
  }

  HttpClientRequest _addCookies(HttpClientRequest request, Config config) {
    config.cookies.forEach((String key, dynamic value) =>
    value is Cookie ? request.cookies.add(value) : request.cookies.add(new Cookie(key, value)));

    return request;
  }

  HttpClientRequest _addHeaders(HttpClientRequest request, Config config) {
    // Add default headers
    getDefaultHeaders.forEach((String key, dynamic value) => request.headers.add(key, value));

    // Add config headers
    config.headers.forEach((String key, dynamic value)=> request.headers.add(key, value));

    return request;
  }

  Future<dynamic> _processError(HttpClientResponse response, Config config, {Future<dynamic> Function() onAutoLoginSuccess}) async {
    final PenkalaError penkalaError = await PenkalaError.parseError(response, config);

    return Future<dynamic>.error(penkalaError);
  }
}

class PenkalaError{
  final HttpClientResponse response;
  final Config config;

  bool shouldShow = true;
  ErrorType errorType;
  final StringBuffer _presentableError = StringBuffer();

  PenkalaError(this.response, this.config, {this.errorType});

  String get errorString => _presentableError.isEmpty ? null : _presentableError.toString();

  @override
  String toString(){
    return 'PenkalaError :: $errorString';
  }

  /// Get more info about Request error
  /// Will set up error type and string for specific error
  /// Toggles [shouldShow] flag to false if error dialog is not needed to pop up for this error
  Future<Null> _processError() async {
    print('Processing error : [${response.statusCode}] - ${response.reasonPhrase}');
    final String _responseData = await utf8.decodeStream(response);
    final Map<dynamic, dynamic> errorJson = jsonDecode(_responseData);

    switch(response.statusCode){
    /// Start auto-login procedure if we receive status code 498
    /// 498 Invalid Token (Esri)
    /// Returned by ArcGIS for Server. Code 498 indicates an expired or otherwise invalid token.
      case 498:
        continue unknown;

    /// Error 401 is thrown when user is unauthorized to access this endpoint.
    /// App should never call endpoint that will receive '401' if user is logged in
      case 401:
        errorType = ErrorType.unauthorized;
        break;

    /// Error 409 is thrown when an already openVidu named session is alive.
      case 409:
        errorType = ErrorType.sessionAlready;
        break;

    /// Bad gateway. Usually means there is server fix/deploy on the way.
      case 502:
        errorType = ErrorType.badGateway;
        break;

    /// Bad request. Get error code from response data JSON saved in field
    /// 'error_code'. This will give us detailed info about error defined by server for this app.
    ///
    /// Codes are defined here: https://docs.hot-soup.com/penkala-api/index.html#response-codes
      case 400:
        switch(errorJson['error_code'] ?? -1){
          case 186:
            errorType = ErrorType.missingSignatureImages;
            break;
          case 187:
            errorType = ErrorType.signatureApprovalNeeded;
            break;
          default:
            errorType = ErrorType.badRequest;
            break;
        }
        break;
      unknown:
      default:
        errorType = ErrorType.unknown;

        print('UNKNOWN ERROR! ${response.statusCode} - [${response.reasonPhrase}]');
        print('URL: ${config.uri.toString()}');
        print('Headers: ${config.headers.toString()}');
        print('Body: ${config.body?.getBody()}');
        print('Data: ${_responseData ?? ''}');
        break;
    }

    if(errorType == ErrorType.sessionAlready){
      _presentableError.writeln('409 - Session already created. Join in..');
      print(_presentableError);
    }
    else if(errorType == ErrorType.badGateway){
      _presentableError.writeln('502 - Bad Gateway (deploy is on the way?)');
    }else{
      try{
        if(errorJson.containsKey('errors')){
          final List<dynamic> errors = errorJson['errors'];
        }else{
          _presentableError.writeln(errorJson['error_msg'] ?? 'Something went wrong!');
        }

        print('Error: ${errorType.toString()}');
      }catch(exception){
        print('Exception proccessing error: $exception');
      }
    }
  }

  static Future<PenkalaError> parseError(HttpClientResponse response, Config config) async {
    final PenkalaError error = PenkalaError(response, config);
    await error._processError();
    return Future<PenkalaError>.value(error);
  }
}

enum ErrorType{
  tokenExpired,
  badGateway,
  badRequest,
  unauthorized,
  unknown,
  noConnection,
  signatureApprovalNeeded,
  missingSignatureImages,
  sessionAlready
}
