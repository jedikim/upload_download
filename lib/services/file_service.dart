import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:tuple/tuple.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as fileUtil;
import 'package:path_provider/path_provider.dart';
import 'package:upload_download/models/file.dart' as model;
import 'package:http_parser/http_parser.dart';
import 'package:random_string/random_string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
typedef void OnDownloadProgressCallback(int receivedBytes, int totalBytes);
typedef void OnUploadProgressCallback(int sentBytes, int totalBytes);
String encryptAESCryptoJS(String plainText, String passphrase) {
  try {
    final salt = genRandomWithNonZero(8);
    var keyndIV = deriveKeyAndIV(passphrase, salt);
    final key = encrypt.Key(keyndIV.item1);
    final iv = encrypt.IV(keyndIV.item2);

    final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: "PKCS7"));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    Uint8List encryptedBytesWithSalt = Uint8List.fromList(
        createUint8ListFromString("Salted__") + salt + encrypted.bytes);
    return base64.encode(encryptedBytesWithSalt);
  } catch (error) {
    throw error;
  }
}

String decryptAESCryptoJS(String encrypted, String passphrase) {
  try {
    Uint8List encryptedBytesWithSalt = base64.decode(encrypted);

    Uint8List encryptedBytes =
    encryptedBytesWithSalt.sublist(16, encryptedBytesWithSalt.length);
    final salt = encryptedBytesWithSalt.sublist(8, 16);
    var keyndIV = deriveKeyAndIV(passphrase, salt);
    final key = encrypt.Key(keyndIV.item1);
    final iv = encrypt.IV(keyndIV.item2);

    final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: "PKCS7"));
    final decrypted =
    encrypter.decrypt64(base64.encode(encryptedBytes), iv: iv);
    return decrypted;
  } catch (error) {
    throw error;
  }
}

Tuple2<Uint8List, Uint8List> deriveKeyAndIV(String passphrase, Uint8List salt) {
  var password = createUint8ListFromString(passphrase);
  Uint8List concatenatedHashes = Uint8List(0);
  Uint8List currentHash = Uint8List(0);
  bool enoughBytesForKey = false;
  Uint8List preHash = Uint8List(0);

  while (!enoughBytesForKey) {
    int preHashLength = currentHash.length + password.length + salt.length;
    if (currentHash.length > 0)
      preHash = Uint8List.fromList(
          currentHash + password + salt);
    else
      preHash = Uint8List.fromList(
          password + salt);

    currentHash = md5.convert(preHash).bytes;
    concatenatedHashes = Uint8List.fromList(concatenatedHashes + currentHash);
    if (concatenatedHashes.length >= 48) enoughBytesForKey = true;
  }

  var keyBtyes = concatenatedHashes.sublist(0, 32);
  var ivBtyes = concatenatedHashes.sublist(32, 48);
  return new Tuple2(keyBtyes, ivBtyes);
}

Uint8List createUint8ListFromString(String s) {
  var ret = new Uint8List(s.length);
  for (var i = 0; i < s.length; i++) {
    ret[i] = s.codeUnitAt(i);
  }
  return ret;
}

Uint8List genRandomWithNonZero(int seedLength) {
  final random = Random.secure();
  const int randomMax = 245;
  final Uint8List uint8list = Uint8List(seedLength);
  for (int i=0; i < seedLength; i++) {
    uint8list[i] = random.nextInt(randomMax)+1;
  }
  return uint8list;
}

class FileService {
  static bool trustSelfSigned = true;

  static HttpClient getHttpClient() {
    HttpClient httpClient = new HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => trustSelfSigned);

    return httpClient;
  }

  static String baseUrl = 'https://api.winklink.net';

  static fileGetAllMock() {
    return List.generate(
      20,
          (i) => model.File(
          fileName: 'filename $i.jpg',
          dateModified: DateTime.now().add(Duration(minutes: i)),
          size: i * 1000),
    );
  }

  static Future<List<model.File>> fileGetAll() async {
    var httpClient = getHttpClient();

    final url = '$baseUrl/api/file';

    var httpRequest = await httpClient.getUrl(Uri.parse(url));

    var httpResponse = await httpRequest.close();

    var jsonString = await readResponseAsString(httpResponse);

    return model.fileFromJson(jsonString);
  }

  static Future<String> fileDelete(String fileName) async {
    var httpClient = getHttpClient();

    final url = Uri.encodeFull('$baseUrl/api/file/$fileName');

    var httpRequest = await httpClient.deleteUrl(Uri.parse(url));

    var httpResponse = await httpRequest.close();

    var response = await readResponseAsString(httpResponse);

    return response;
  }

  static Future<String> fileUpload({File file, OnUploadProgressCallback onUploadProgress}) async {
    assert(file != null);

    final tempUrl = '$baseUrl/upload';
    //Map<String, String> headers = {"Host": "ow14hagrt7.execute-api.us-west-2.amazonaws.com"};
    Response response;
    final fileName = 'jedikimimage5';
    final password = '12345678904';
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path + '/temp.json';
    File tempFile = await File(tempPath).create(recursive: true);



    try {
      response = await Dio().post(tempUrl, data: {'filename': fileName, 'password': password});
      //print(response.data.toString().length);
    } catch (e) {
      print(e);
    }
    //var response = await http.get(tempUrl);
    //var response = await http.post(tempUrl, headers: headers, body: {'imagefile': 'jedikimimage', 'password': '1234567890'});
    //print(response.data);

    final temp = json.decode(response.data);
    //print(temp['filename']);
    //print(temp['signedURL']);
    final url = temp['signedURL'];
    //final t = json.decode(temp.signedURL);
    //Map<String, dynamic>  tUrl = jsonDecode(url);
    print("SignedURL is :" + url['url']);
    //print(temp.filename);
    // final fileStream = file.openRead();
    //
    // int totalByteLength = file.lengthSync();
    //
    // final httpClient = getHttpClient();
    //
    // final request = await httpClient.postUrl(Uri.parse(url));
    //
    // request.headers.set(HttpHeaders.contentTypeHeader, ContentType.binary);
    // //request.headers.add("password", "JEDI1234");
    // request.headers.add("filename", fileUtil.basename(file.path));
    //
    // request.contentLength = totalByteLength;
    //
    // int byteCount = 0;
    // Stream<List<int>> streamUpload = fileStream.transform(
    //   new StreamTransformer.fromHandlers(
    //     handleData: (data, sink) {
    //       byteCount += data.length;
    //
    //       if (onUploadProgress != null) {
    //         onUploadProgress(byteCount, totalByteLength);
    //         // CALL STATUS CALLBACK;
    //       }
    //
    //       sink.add(data);
    //     },
    //     handleError: (error, stack, sink) {
    //       print(error.toString());
    //     },
    //     handleDone: (sink) {
    //       sink.close();
    //       // UPLOAD DONE;
    //     },
    //   ),
    // );
    //
    // await request.addStream(streamUpload);
    //
    // final httpResponse = await request.close();
    Response httpResponse;
    try {
      //   httpResponse = await Dio().put(
      //   url,
      //   data: file.openRead(),
      //   options: Options(
      //     contentType: "image/jpeg",
      //     headers: {
      //       "Content-Length": file.lengthSync(),
      //     },
      //   ),
      //   onSendProgress: (int sentBytes, int totalBytes) {
      //     onUploadProgress(sentBytes, totalBytes);
      //     double progressPercent = sentBytes / totalBytes * 100;
      //     print("$progressPercent %");
      //   },
      // );
      Dio dio = new Dio();
      ///dio.options.headers["Content-Type"] = "multipart/form-data";
      //var fields = {"Content-Type":"image/jpeg",...url['fields']};
      print('ok add fields');
      Map<String, dynamic> tfields = url['fields'];
      var fields = {"Content-Type":"application/json",...tfields};
      print('ok add fields done :');
      final bytes = await File(file.path).readAsBytes();
      String img64 = base64Encode(bytes);
      String pw = randomAlphaNumeric(12);

      //String tempPath = 'temp.json';
      print('tempPath :' + tempPath);
      //String iv = randomAlphaNumeric(8);
      print('pw :' + pw);
      print('img64 :' + img64);
      String img = encryptAESCryptoJS(img64, pw);
      //DES3 des3CBC = DES3(key: pw.codeUnits, mode: DESMode.CBC, iv: iv.codeUnits);
      //encrypted = des3CBC.encrypt(bytes);
      //String img = base64.encode(des3CBC.encrypt('jedi kim'.codeUnits));
      //String img = base64.encode(des3CBC.encrypt(bytes));
      print('img :'+img);
      Map<String, dynamic> tempjson = { "name":"jedi kim" };
      tempjson["image"] = img;
      String stringjson = json.encode(tempjson);
      //stringjson = '{ "name":"jedi kim test" }';
      print('tempjson :'+ stringjson);
      //fields['file'] = await MultipartFile.fromFile(file.path, filename: fileName);
      await tempFile.writeAsString(stringjson, flush: true);
      //await temp.;
      print(fields);
      var formData =  FormData.fromMap(fields);
      //formData = FormData();
      //formData.fields.add(MapEntry("Content-Type","image/jpeg"));
      //formData.fields.a
      formData.files.add(MapEntry('file',await  MultipartFile.fromFile(tempPath, filename: fileName+'.json', contentType:  MediaType('application', 'json'))));

      //formData.finalize();
      //MultipartFile.
      //formData.files.add(MapEntry('file', MultipartFile.fromBytes(stringjson.codeUnits,filename: fileName+'.json', contentType:  MediaType('image', 'jpeg'))));
      //formData.files.
      //print(String.fromCharCodes(await formData.readAsBytes()));
      //print(formData.files.last.toString());
      //formData.files.add(MapEntry('file',await MultipartFile.fromFile(tempPath,filename: fileName+'.json', contentType:  MediaType('image', 'jpeg'))));
      //formData.files.add  add("file", new UploadFileInfo(_image, basename(_image.path)));
      //print(formData.);


      httpResponse = await dio.post(url['url'], data: formData,         onSendProgress: (int sentBytes, int totalBytes) {
        onUploadProgress(sentBytes, totalBytes);
        double progressPercent = sentBytes / totalBytes * 100;
        print("$progressPercent %");
      });

      print(httpResponse.statusMessage);
    } catch(e){
      print(e);
      print(httpResponse.data);
    }
    await tempFile.delete();
    print('response is done');
    if ((httpResponse.statusCode != 200) && (httpResponse.statusCode != 204)) {
      print(httpResponse.statusCode.toString() + '|' + httpResponse.data+ '|' + httpResponse.statusMessage);
      throw Exception('Error uploading file');
    } else {
      print(httpResponse.toString());
      return httpResponse.toString();
    }
  }

  static Future<String> fileUploadMultipart(
      {File file, OnUploadProgressCallback onUploadProgress}) async {
    assert(file != null);

    final url = '$baseUrl/api/file';

    final httpClient = getHttpClient();

    final request = await httpClient.postUrl(Uri.parse(url));

    int byteCount = 0;

    var multipart = await http.MultipartFile.fromPath(fileUtil.basename(file.path), file.path);

    // final fileStreamFile = file.openRead();

    // var multipart = MultipartFile("file", fileStreamFile, file.lengthSync(),
    //     filename: fileUtil.basename(file.path));

    var requestMultipart = http.MultipartRequest("", Uri.parse("uri"));

    requestMultipart.files.add(multipart);

    var msStream = requestMultipart.finalize();

    var totalByteLength = requestMultipart.contentLength;

    request.contentLength = totalByteLength;

    request.headers.set(
        HttpHeaders.contentTypeHeader, requestMultipart.headers[HttpHeaders.contentTypeHeader]);

    Stream<List<int>> streamUpload = msStream.transform(
      new StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);

          byteCount += data.length;

          if (onUploadProgress != null) {
            onUploadProgress(byteCount, totalByteLength);
            // CALL STATUS CALLBACK;
          }
        },
        handleError: (error, stack, sink) {
          throw error;
        },
        handleDone: (sink) {
          sink.close();
          // UPLOAD DONE;
        },
      ),
    );

    await request.addStream(streamUpload);

    final httpResponse = await request.close();
//
    var statusCode = httpResponse.statusCode;

    if (statusCode ~/ 100 != 2) {
      throw Exception('Error uploading file, Status code: ${httpResponse.statusCode}');
    } else {
      return await readResponseAsString(httpResponse);
    }
  }

  static Future<String> fileDownload(
      {String fileName, OnUploadProgressCallback onDownloadProgress}) async {
    assert(fileName != null);

    final url = Uri.encodeFull('$baseUrl/api/file/$fileName');

    final httpClient = getHttpClient();

    final request = await httpClient.getUrl(Uri.parse(url));

    request.headers.add(HttpHeaders.contentTypeHeader, "application/octet-stream");

    var httpResponse = await request.close();

    int byteCount = 0;
    int totalBytes = httpResponse.contentLength;

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    //appDocPath = "/storage/emulated/0/Download";

    File file = new File(appDocPath + "/" + fileName);

    var raf = file.openSync(mode: FileMode.write);

    Completer completer = new Completer<String>();

    httpResponse.listen(
          (data) {
        byteCount += data.length;

        raf.writeFromSync(data);

        if (onDownloadProgress != null) {
          onDownloadProgress(byteCount, totalBytes);
        }
      },
      onDone: () {
        raf.closeSync();

        completer.complete(file.path);
      },
      onError: (e) {
        raf.closeSync();
        file.deleteSync();
        completer.completeError(e);
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  static Future<String> readResponseAsString(HttpClientResponse response) {
    var completer = new Completer<String>();
    var contents = new StringBuffer();
    response.transform(utf8.decoder).listen((String data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
  }
}
