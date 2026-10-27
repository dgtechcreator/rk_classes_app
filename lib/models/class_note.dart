import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A study file for a class: notes, or the daily practice paper (GET /api/notes, /api/parent/notes).
class ClassNote {
  ClassNote({
    required this.noteId,
    required this.kind,
    required this.title,
    required this.fileName,
    required this.fileSize,
    required this.paperDate,
    this.description,
    this.subjectName,
    this.className,
    this.sectionName,
    this.batchName,
    this.createdByName,
  });

  final int noteId;
  final String kind;            // Notes | Practice
  final String title;
  final String? description;
  final String? subjectName;
  final String? className;
  final String? sectionName;
  final String? batchName;
  final String fileName;
  final int fileSize;
  final DateTime paperDate;
  final String? createdByName;

  bool get isPractice => kind == 'Practice';
  Color get color => isPractice ? AppColors.warning : AppColors.info;
  Color get soft => isPractice ? AppColors.warningSoft : AppColors.infoSoft;
  IconData get icon => isPractice ? Icons.edit_note_rounded : Icons.description_rounded;

  /// "Class 8 • English • Morning" - the parts that are "all" are left out.
  String get groupLabel => [className, sectionName, batchName].where((s) => (s ?? '').trim().isNotEmpty).map((s) => s!.trim()).join(' • ');

  String get sizeLabel => fileSize >= 1048576 ? '${(fileSize / 1048576).toStringAsFixed(1)} MB' : '${(fileSize / 1024).ceil()} KB';

  factory ClassNote.fromJson(Map<String, dynamic> j) => ClassNote(
        noteId: (j['noteId'] as num?)?.toInt() ?? 0,
        kind: j['kind']?.toString() ?? 'Notes',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString(),
        subjectName: j['subjectName']?.toString(),
        className: j['className']?.toString(),
        sectionName: j['sectionName']?.toString(),
        batchName: j['batchName']?.toString(),
        fileName: j['fileName']?.toString() ?? '',
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        paperDate: DateTime.tryParse(j['paperDate']?.toString() ?? '') ?? DateTime.now(),
        createdByName: j['createdByName']?.toString(),
      );
}
