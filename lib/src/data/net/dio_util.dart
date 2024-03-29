import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/adapter.dart';
import '../protocol/base_resp.dart';

class DioConstant {
  static const int status_success = 1;
  static const int status_fail = 0;
}

/// 请求方法.
class Method {
  static final String get = "GET";
  static final String post = "POST";
  static final String put = "PUT";
  static final String head = "HEAD";
  static final String delete = "DELETE";
  static final String patch = "PATCH";
}

///Http配置.
class HttpConfig {
  /// constructor.
  HttpConfig({
    this.baseUri,
    this.status,
    this.code,
    this.msg,
    this.data,
    this.subData,
    this.options,
    this.pem,
    this.pKCSPath,
    this.pKCSPwd,
  });

  /// api地址.
  String baseUri;

  /// BaseResp [String status]字段 key, 默认：status.
  String status;

  /// BaseResp [int code]字段 key, 默认：errorCode.
  String code;

  /// BaseResp [String msg]字段 key, 默认：errorMsg.
  String msg;

  /// BaseResp [T data]字段 key, 默认：data.
  String data;

  /// BaseResp [T data]字段子 key, items.
  String subData;

  /// Options.
  Options options;

  /// 详细使用请查看dio官网 https://github.com/flutterchina/dio/blob/flutter/README-ZH.md#Https证书校验.
  /// PEM证书内容.
  String pem;

  /// 详细使用请查看dio官网 https://github.com/flutterchina/dio/blob/flutter/README-ZH.md#Https证书校验.
  /// PKCS12 证书路径.
  String pKCSPath;

  /// 详细使用请查看dio官网 https://github.com/flutterchina/dio/blob/flutter/README-ZH.md#Https证书校验.
  /// PKCS12 证书密码.
  String pKCSPwd;
}

/// 单例 DioUtil.
/// debug模式下可以打印请求日志. DioUtil.openDebug().
/// dio详细使用请查看dio官网(https://github.com/flutterchina/dio).
class DioUtil {
  static final DioUtil _singleton = DioUtil._init();
  static Dio _dio;

  /// api地址.
  static String _baseUri;

  /// BaseResp [String status]字段 key, 默认：status.，
  String _statusKey = "status";

  /// BaseResp [int code]字段 key, 默认：errorCode.
  String _codeKey = "errorCode";

  /// BaseResp [String msg]字段 key, 默认：errorMsg.
  String _msgKey = "errorMsg";

  /// BaseResp [T data]字段 key, 默认：data.
  String _dataKey = "data";

  /// Options.
  BaseOptions _options = getDefOptions();

  /// PEM证书内容.
  String _pem;

  /// PKCS12 证书路径.
  String _pKCSPath;

  /// PKCS12 证书密码.
  String _pKCSPwd;

  /// 是否是debug模式.
  static bool _isDebug = false;

  static DioUtil getInstance() {
    return _singleton;
  }

  factory DioUtil() {
    return _singleton;
  }

  DioUtil._init() {
    _dio = new Dio(_options);
  }

  /// 打开debug模式.
  static void openDebug() {
    _isDebug = true;
  }

  void setCookie(String cookie) {
    Map<String, dynamic> _headers = new Map();
    _headers["Cookie"] = cookie;
    _dio.options.headers.addAll(_headers);
  }

  Future<MultipartFile> getFileData(String filePath, {String fileName}) async {
    return await MultipartFile.fromFile(filePath, filename: fileName);
  }

  /// set Config.
  void setConfig(HttpConfig config) {
    _baseUri = config.baseUri ?? _baseUri;
    _statusKey = config.status ?? _statusKey;
    _codeKey = config.code ?? _codeKey;
    _msgKey = config.msg ?? _msgKey;
    _dataKey = config.data ?? _dataKey;
    _mergeOption(config.options);
    _pem = config.pem ?? _pem;
    if (_dio != null) {
      _dio.options = _options;
      if (_pem != null) {
        (_dio.httpClientAdapter as DefaultHttpClientAdapter)
            .onHttpClientCreate = (client) {
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            if (cert.pem == _pem) {
              // 证书一致，则放行
              return true;
            }
            return false;
          };
        };
      }
      if (_pKCSPath != null) {
        (_dio.httpClientAdapter as DefaultHttpClientAdapter)
            .onHttpClientCreate = (client) {
          SecurityContext sc = new SecurityContext();
          //file为证书路径
          sc.setTrustedCertificates(_pKCSPath, password: _pKCSPwd);
          HttpClient httpClient = new HttpClient(context: sc);
          return httpClient;
        };
      }
    }
  }

  /// Make http request with options.
  /// [method] The request method.
  /// [path] The url path.
  /// [data] The request data
  /// [options] The request options.
  /// <BaseResp<T> 返回 status code msg data .
  Future<BaseResp<T>> request<T>(String method, String path,
      {data, Options options, CancelToken cancelToken}) async {
    Response response = new Response();
    if (method.toLowerCase() == "get") {
      response = await _dio.request(path,
          queryParameters: data,
          options: _checkOptions(method, options),
          cancelToken: cancelToken);
    } else {
      response = await _dio.request(path,
          data: data,
          options: _checkOptions(method, options),
          cancelToken: cancelToken);
    }
    _printHttpLog(response);
    String _status;
    int _code;
    String _msg;
    T _data;
    if (response.statusCode == HttpStatus.ok ||
        response.statusCode == HttpStatus.created) {
      try {
        if (response.data is Map) {
          // _status = (response.data[_statusKey] is int)
          //     ? response.data[_statusKey].toString()
          //     : response.data[_statusKey];
          _status = response.data[_statusKey].toString();
          // _code = (response.data[_codeKey] is String)
          //     ? int.tryParse(response.data[_codeKey])
          //     : response.data[_codeKey];
          _code = response.data[_statusKey]
              ? DioConstant.status_success
              : DioConstant.status_fail;
          _msg = response.data[_msgKey];
          // _data = response.data[_dataKey] is Map
          //     ? <String, dynamic>{
          //         _subDataKey: response.data[_dataKey][_subDataKey]
          //       }
          //     : response.data[_dataKey];
          _data = response.data[_dataKey];
        } else {
          Map<String, dynamic> _dataMap = _decodeData(response);
          // _status = (_dataMap[_statusKey] is int)
          //     ? _dataMap[_statusKey].toString()
          //     : _dataMap[_statusKey];
          _status = _dataMap[_statusKey].toString();
          // _code = (_dataMap[_codeKey] is String)
          //     ? int.tryParse(_dataMap[_codeKey])
          //     : _dataMap[_codeKey];
          _code = _dataMap[_statusKey]
              ? DioConstant.status_success
              : DioConstant.status_fail;
          _msg = _dataMap[_msgKey];
          _data = _dataMap[_dataKey];
        }
        return new BaseResp(_status, _code, _msg, _data);
      } catch (e) {
        return new Future.error(new DioError(
          response: response,
          error: "data parsing exception...",
          type: DioErrorType.RESPONSE,
        ));
      }
    }
    return new Future.error(new DioError(
      response: response,
      error: "statusCode: $response.statusCode, service error",
      type: DioErrorType.RESPONSE,
    ));
  }

  /// Make http request with options.
  /// [method] The request method.
  /// [path] The url path.
  /// [data] The request data
  /// [options] The request options.
  /// <BaseRespR<T> 返回 status code msg data  Response.
  Future<BaseRespR<T>> requestR<T>(String method, String path,
      {data, Options options, CancelToken cancelToken}) async {
    Response response = new Response();
    if (method.toLowerCase() == "get") {
      response = await _dio.request(path,
          queryParameters: data,
          options: _checkOptions(method, options),
          cancelToken: cancelToken);
    } else {
      response = await _dio.request(path,
          data: data,
          options: _checkOptions(method, options),
          cancelToken: cancelToken);
    }
    _printHttpLog(response);
    String _status;
    int _code;
    String _msg;
    T _data;
    if (response.statusCode == HttpStatus.ok ||
        response.statusCode == HttpStatus.created) {
      try {
        if (response.data is Map) {
          // _status = (response.data[_statusKey] is int)
          //     ? response.data[_statusKey].toString()
          //     : response.data[_statusKey];
          _status = response.data[_statusKey].toString();
          // _code = (response.data[_codeKey] is String)
          //     ? int.tryParse(response.data[_codeKey])
          //     : response.data[_codeKey];
          _code = response.data[_statusKey]
              ? DioConstant.status_success
              : DioConstant.status_fail;
          _msg = response.data[_msgKey];
          _data = response.data[_dataKey];
        } else {
          Map<String, dynamic> _dataMap = _decodeData(response);
          // _status = (_dataMap[_statusKey] is int)
          //     ? _dataMap[_statusKey].toString()
          //     : _dataMap[_statusKey];
          _status = _dataMap[_statusKey].toString();
          // _code = (_dataMap[_codeKey] is String)
          //     ? int.tryParse(_dataMap[_codeKey])
          //     : _dataMap[_codeKey];
          _code = _dataMap[_statusKey]
              ? DioConstant.status_success
              : DioConstant.status_fail;
          _msg = _dataMap[_msgKey];
          _data = _dataMap[_dataKey];
        }
        return new BaseRespR(_status, _code, _msg, _data, response);
      } catch (e) {
        return new Future.error(new DioError(
          response: response,
          error: "data parsing exception...$e",
          type: DioErrorType.RESPONSE,
        ));
      }
    }
    return new Future.error(new DioError(
      response: response,
      error: "statusCode: $response.statusCode, service error",
      type: DioErrorType.RESPONSE,
    ));
  }

  /// Download the file and save it in local. The default http method is "GET",you can custom it by [Options.method].
  /// [urlPath]: The file url.
  /// [savePath]: The path to save the downloading file later.
  /// [onProgress]: The callback to listen downloading progress.please refer to [OnDownloadProgress].
  Future<Response> download(
    String urlPath,
    savePath, {
    onProgress,
    CancelToken cancelToken,
    data,
    Options options,
  }) {
    return _dio.download(urlPath, savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        data: data,
        options: options);
  }

  /// decode response data.
  Map<String, dynamic> _decodeData(Response response) {
    if (response == null ||
        response.data == null ||
        response.data.toString().isEmpty) {
      return new Map();
    }
    return json.decode(response.data.toString());
  }

  /// check Options.
  Options _checkOptions(method, options) {
    if (options == null) {
      options = new Options();
    }
    options.method = method;
    return options;
  }

  /// merge Option.
  void _mergeOption(Options opt) {
    _options.baseUrl = _baseUri;
    _options.method = opt.method ?? _options.method;
    _options.headers = (new Map.from(_options.headers))..addAll(opt.headers);
    _options.baseUrl = _options.baseUrl;
    _options.connectTimeout = opt.sendTimeout ?? _options.connectTimeout;
    _options.receiveTimeout = opt.receiveTimeout ?? _options.receiveTimeout;
    _options.responseType = opt.responseType ?? _options.responseType;
    //_options.data = opt.data ?? _options.data;
    _options.extra = (new Map.from(_options.extra))..addAll(opt.extra);
    _options.contentType = opt.contentType ?? _options.contentType;
    _options.validateStatus = opt.validateStatus ?? _options.validateStatus;
    _options.followRedirects = opt.followRedirects ?? _options.followRedirects;
  }

  /// print Http Log.
  void _printHttpLog(Response response) {
    if (!_isDebug) {
      return;
    }
    try {
      print("----------------Http Log----------------" +
          "\n[statusCode]:   " +
          response.statusCode.toString() +
          "\n[request   ]:   " +
          _getOptionsStr(response.request));
      _printDataStr("reqdata ", response.request.data);
      _printDataStr("response", response.data);
    } catch (ex) {
      print("Http Log" + " error......");
    }
  }

  /// get Options Str.
  String _getOptionsStr(RequestOptions request) {
    return "method: " +
        request.method +
        "  baseUrl: " +
        request.baseUrl +
        "  path: " +
        request.path;
  }

  /// print Data Str.
  void _printDataStr(String tag, Object value) {
    String da = value.toString();
    while (da.isNotEmpty) {
      if (da.length > 512) {
        print("[$tag  ]:   " + da.substring(0, 512));
        da = da.substring(512, da.length);
      } else {
        print("[$tag  ]:   " + da);
        da = "";
      }
    }
  }

  /// get dio.
  Dio getDio() {
    return _dio;
  }

  /// create new dio.
  static Dio createNewDio([BaseOptions options]) {
    options = options ?? getDefOptions();
    Dio dio = new Dio(options);
    return dio;
  }

  /// get Def Options.
  static BaseOptions getDefOptions() {
    BaseOptions options = new BaseOptions();
    // options.contentType =
    // ContentType.parse("application/x-www-form-urlencoded");
    options.contentType = "application/x-www-form-urlencoded";
    options.connectTimeout = 1000 * 30;
    options.receiveTimeout = 1000 * 30;
    return options;
  }
}
