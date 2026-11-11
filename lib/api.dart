import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Normalisasi nomor: terima 08xx, 62xx, +62xx. Hasil selalu 62xx, atau null kalau tidak valid.
String? normalizeNumber(String input) {
  var n = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('0')) n = '62${n.substring(1)}';
  if (!RegExp(r'^62\d{8,13}$').hasMatch(n)) return null;
  return n;
}

class ApiException implements Exception {
  final String message;
  final String? code;
  ApiException(this.message, {this.code});

  bool get offline => code == 'offline';

  @override
  String toString() => message;
}

class SenderInfo {
  final String number;
  final String status; // starting | pairing | connecting | connected | disconnected | error
  final String? code;
  final int? expiresAt; // epoch ms
  final int ttlMs;
  final String? error;

  const SenderInfo({
    required this.number,
    required this.status,
    this.code,
    this.expiresAt,
    this.ttlMs = 60000,
    this.error,
  });

  factory SenderInfo.fromJson(Map<String, dynamic> j) => SenderInfo(
        number: j['number']?.toString() ?? '',
        status: j['status']?.toString() ?? 'unknown',
        code: j['code']?.toString(),
        expiresAt: (j['expiresAt'] as num?)?.toInt(),
        ttlMs: (j['ttlMs'] as num?)?.toInt() ?? 60000,
        error: j['error']?.toString(),
      );

  bool get connected => status == 'connected';
}

class JobInfo {
  final String id;
  final String status; // running | done | error
  final int total;
  final int done;
  final int failed;
  final String current;
  final String? error;
  final List<String> log;

  const JobInfo({
    required this.id,
    required this.status,
    required this.total,
    required this.done,
    required this.failed,
    required this.current,
    this.error,
    this.log = const [],
  });

  factory JobInfo.fromJson(Map<String, dynamic> j) => JobInfo(
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? 'running',
        total: (j['total'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        current: j['current']?.toString() ?? '',
        error: j['error']?.toString(),
        log: (j['log'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  bool get running => status == 'running';
  int get processed => done + failed;
}

class FilesInfo {
  final String? folder;
  final bool exists;
  final int count;
  const FilesInfo({this.folder, required this.exists, required this.count});
}

class FileEntry {
  final String name;
  final int size;
  const FileEntry({required this.name, required this.size});

  factory FileEntry.fromJson(Map<String, dynamic> j) => FileEntry(
        name: j['name']?.toString() ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

class FilesListInfo {
  final String? folder;
  final List<FileEntry> files;
  const FilesListInfo({this.folder, required this.files});
}

class JobSummary {
  final String id;
  final String status;
  final int total;
  final int done;
  final int failed;
  final String target;
  final String sender;
  final int startedAt;

  const JobSummary({
    required this.id,
    required this.status,
    required this.total,
    required this.done,
    required this.failed,
    required this.target,
    required this.sender,
    required this.startedAt,
  });

  factory JobSummary.fromJson(Map<String, dynamic> j) => JobSummary(
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        total: (j['total'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        target: j['target']?.toString() ?? '',
        sender: j['sender']?.toString() ?? '',
        startedAt: (j['startedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Klien HTTP ke backend.js yang berjalan di Termux (HP yang sama).
/// Hanya satu server lokal — tidak ada pengaturan alamat di app.
class Api {
  Api._();
  static final Api instance = Api._();

  static const String baseUrl = 'http://127.0.0.1:8787';

  Future<Map<String, dynamic>> _req(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(timeout);
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(timeout);
      }
    } on TimeoutException {
      throw ApiException('Server tidak merespons.', code: 'offline');
    } catch (_) {
      throw ApiException('Server sedang mati.', code: 'offline');
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 400) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Server error ${res.statusCode}';
      final code = (data is Map) ? data['code']?.toString() : null;
      throw ApiException(msg, code: code);
    }
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<void> ping() async {
    await _req('GET', '/api/ping', timeout: const Duration(seconds: 3));
  }

  Future<List<SenderInfo>> senders() async {
    final d = await _req('GET', '/api/senders', timeout: const Duration(seconds: 4));
    final list = (d['senders'] as List?) ?? const [];
    return list
        .map((e) => SenderInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SenderInfo> addSender(String number) async {
    final d = await _req('POST', '/api/senders', body: {'number': number});
    return SenderInfo.fromJson(Map<String, dynamic>.from(d['sender'] as Map));
  }

  Future<SenderInfo> sender(String number) async {
    final d = await _req('GET', '/api/senders/$number', timeout: const Duration(seconds: 4));
    return SenderInfo.fromJson(Map<String, dynamic>.from(d['sender'] as Map));
  }

  Future<void> removeSender(String number) async {
    await _req('DELETE', '/api/senders/$number', timeout: const Duration(seconds: 15));
  }

  Future<FilesInfo> files() async {
    final d = await _req('GET', '/api/files', timeout: const Duration(seconds: 6));
    return FilesInfo(
      folder: d['folder']?.toString(),
      exists: d['exists'] == true,
      count: (d['count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<String> send({required String sender, required String target}) async {
    final d = await _req('POST', '/api/send', body: {'sender': sender, 'target': target});
    return d['jobId'].toString();
  }

  Future<JobInfo> job(String id) async {
    final d = await _req('GET', '/api/jobs/$id', timeout: const Duration(seconds: 4));
    return JobInfo.fromJson(Map<String, dynamic>.from(d['job'] as Map));
  }

  Future<FilesListInfo> filesList() async {
    final d = await _req('GET', '/api/files/list', timeout: const Duration(seconds: 6));
    final list = (d['files'] as List?) ?? const [];
    return FilesListInfo(
      folder: d['folder']?.toString(),
      files: list
          .map((e) => FileEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Future<FileEntry> addFile({required String name, required int bytes}) async {
    final d = await _req(
      'POST',
      '/api/files',
      body: {'name': name, 'bytes': bytes},
      timeout: const Duration(seconds: 20),
    );
    return FileEntry.fromJson(Map<String, dynamic>.from(d['file'] as Map));
  }

  Future<void> deleteFile(String name) async {
    await _req('DELETE', '/api/files/${Uri.encodeComponent(name)}', timeout: const Duration(seconds: 8));
  }

  Future<List<JobSummary>> jobHistory() async {
    final d = await _req('GET', '/api/jobs', timeout: const Duration(seconds: 6));
    final list = (d['jobs'] as List?) ?? const [];
    return list
        .map((e) => JobSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> checkNumber(String number) async {
    final d = await _req('POST', '/api/check-number', body: {'number': number}, timeout: const Duration(seconds: 15));
    return d['exists'] == true;
  }
}
