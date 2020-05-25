import 'dart:async' show Future, Stream;
import 'dart:convert' show jsonEncode, jsonDecode, utf8;
import 'dart:io' show HttpClientResponse, ContentType;

import 'package:html/dom.dart' show Document;
import 'package:html/parser.dart' as parser show parse;

enum RequestMethod {
  get,
  post,
  put,
  delete,
  patch
}

class RequestBody {
  static _JsonRequest json(Map<String, dynamic> data) => new _JsonRequest(data);
  static _FormDataRequest formData(Map<String, dynamic> data) => new _FormDataRequest(data);
}

class ResponseBody {
  static _JsonResponse json() => new _JsonResponse();
  static _DocumentResponse document() => new _DocumentResponse();
}

class Config {
  const Config({
    RequestMethod method,
    this.uri,
    this.body,
    this.responseType,
    this.headers = const <String, dynamic>{},
    this.cookies = const <String, dynamic>{},
  }) : _method = method;

  final RequestMethod _method;
  final Uri uri;
  final _RequestBodyType body;
  final _ResponseBodyType responseType;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> cookies;

  void addHeader(String name, Object value) =>
    headers['$name'] = value;

  void addCookie(String name, Object value) =>
    cookies['$name'] = value;

  String get method => _getMethod();
  bool get hasResponse => responseType != null;
  bool get hasBody => body != null;
  bool get hasHeader => headers?.isNotEmpty == true;

  String _getMethod(){
    switch(_method){
      case RequestMethod.post:
        return 'POST';
      case RequestMethod.put:
        return 'PUT';
      case RequestMethod.get:
        return 'GET';
      case RequestMethod.delete:
        return 'DELETE';
      case RequestMethod.patch:
        return 'PATCH';
      default:
        return 'UNKNOWN';
    }
  }
}

abstract class _RequestBodyType {
  ContentType getContentType() =>
    new ContentType('application', _type(), charset: 'utf-8');
  String getBody();
  String _type();
}

class _JsonRequest extends _RequestBodyType {
  final Map<String, dynamic> json;

  _JsonRequest(this.json);
  @override
  String _type() => 'json';

  @override
  String getBody() => jsonEncode(json);
}

class _FormDataRequest extends _RequestBodyType {
  final Map<String, dynamic> formData;

  _FormDataRequest(this.formData);

  @override
  String _type() => 'x-www-form-urlencoded';

  @override
  String getBody() =>
    formData.keys.map((dynamic key) => '$key=${formData[key]}').join('&');
}

abstract class _ResponseBodyType {
  String getAcceptHeader() => 'Accept';
  String getAcceptValue();
  dynamic parse(HttpClientResponse response);
}

class _JsonResponse extends _ResponseBodyType {
  @override
  String getAcceptValue() => 'application/json';

  @override
  Future<Map<String, dynamic>> parse(HttpClientResponse response) async =>
    jsonDecode(await utf8.decodeStream(response));//response.transform(utf8.decoder).join());
}

class _DocumentResponse extends _ResponseBodyType {
  @override
  String getAcceptValue() => 'text/html';

  @override
  Future<Document> parse(HttpClientResponse response) async =>
    parser.parse(await response.asyncExpand((List<int> bytes) => new Stream<int>.fromIterable(bytes)).toList());
}
