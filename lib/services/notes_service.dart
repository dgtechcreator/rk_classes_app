import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../models/class_note.dart';

class NotesService {
  final _client = ApiClient.instance;

  /// Staff list (module right "class_notes").
  Future<List<ClassNote>> getAll({int? classId, int? sectionId, int? batchId, String? kind}) async {
    final res = await _client.get('/api/notes', query: {'classId': ?classId, 'sectionId': ?sectionId, 'batchId': ?batchId, 'kind': ?kind});
    return (res.data as List).map((e) => ClassNote.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// What a parent / student sees: the notes of the child's own class, medium and batch.
  Future<List<ClassNote>> getForChild(int studentId, {String? kind}) async {
    final res = await _client.get('/api/parent/notes', query: {'studentId': studentId, 'kind': ?kind});
    final data = res.data;
    return data is List ? data.map((e) => ClassNote.fromJson(e as Map<String, dynamic>)).toList() : <ClassNote>[];
  }

  Future<void> upload({
    required String kind,
    required String title,
    String? description,
    required int classId,
    int? sectionId,
    int? batchId,
    String? subjectName,
    required DateTime paperDate,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final form = FormData.fromMap({
      'kind': kind,
      'title': title,
      if ((description ?? '').trim().isNotEmpty) 'description': description!.trim(),
      'classId': classId,
      'sectionId': ?sectionId,
      'batchId': ?batchId,
      if ((subjectName ?? '').trim().isNotEmpty) 'subjectName': subjectName!.trim(),
      'paperDate': DateFormat('yyyy-MM-dd').format(paperDate),
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _client.postForm('/api/notes/upload', form);
  }

  Future<void> delete(int id) async => _client.post('/api/notes/$id/delete');

  /// Opens the file in the phone's own viewer / browser. The browser cannot send the Authorization header, so the token
  /// travels as ?token= (the server accepts that for /api paths - same as the PDF receipts).
  Future<bool> open(int noteId) {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/notes/$noteId/file?token=${_client.token ?? ''}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
