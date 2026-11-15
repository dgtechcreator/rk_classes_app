double? _pDoubleN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
double _pDouble(dynamic v) => _pDoubleN(v) ?? 0;
int _pInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _pIntN(dynamic v) => v == null ? null : _pInt(v);
String _pString(dynamic v) => v?.toString() ?? '';

/// One student in the Top 5 of a paper. Only name and marks (no admission / roll numbers).
class PaperTop {
  PaperTop({required this.rank, required this.fullName, this.marks, required this.percentage, required this.isMe});
  final int rank;
  final String fullName;
  final double? marks;
  final double percentage;
  final bool isMe;

  factory PaperTop.fromJson(Map<String, dynamic> j) => PaperTop(
        rank: _pInt(j['rank']),
        fullName: _pString(j['fullName']).trim(),
        marks: _pDoubleN(j['marks']),
        percentage: _pDouble(j['percentage']),
        isMe: j['isMe'] == true,
      );
}

/// One paper = one exam (chapter / test) of one subject, with the child's own result and the Top 5 of that paper.
class ExamPaper {
  ExamPaper({
    required this.examId,
    required this.subjectId,
    required this.subjectName,
    required this.examName,
    this.testDate,
    required this.maxMarks,
    required this.classSize,
    this.myMarks,
    this.myAbsent = false,
    this.myPercentage,
    this.myRank,
    required this.top,
  });

  final int examId;
  final int subjectId;
  final String subjectName;
  final String examName;
  final DateTime? testDate;
  final int maxMarks;
  /// How many students of the class sat this paper (absent ones are not counted).
  final int classSize;
  final double? myMarks;
  final bool myAbsent;
  final double? myPercentage;
  final int? myRank;
  final List<PaperTop> top;

  /// True when the child has a mark for this paper (not absent, not blank).
  bool get hasMarks => myMarks != null;

  factory ExamPaper.fromJson(Map<String, dynamic> j, String subjectName) {
    final my = (j['my'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ExamPaper(
      examId: _pInt(j['examId']),
      subjectId: _pInt(j['subjectId']),
      subjectName: subjectName,
      examName: _pString(j['examName']).trim().isEmpty ? 'Test' : _pString(j['examName']).trim(),
      testDate: j['testDate'] == null ? null : DateTime.tryParse(_pString(j['testDate']))?.toLocal(),
      maxMarks: _pInt(j['maxMarks']),
      classSize: _pInt(j['classSize']),
      myMarks: _pDoubleN(my['marks']),
      myAbsent: my['absent'] == true,
      myPercentage: _pDoubleN(my['percentage']),
      myRank: _pIntN(my['rank']),
      top: (j['top'] as List? ?? []).map((e) => PaperTop.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PaperSubject {
  PaperSubject({required this.name, required this.papers});
  final String name;
  final List<ExamPaper> papers;
}

/// GET /api/parent/papers — "All paper list" of the child's class and medium, grouped by subject (newest first).
class PapersData {
  PapersData({this.className, this.sectionName, this.yearName, required this.subjects});
  final String? className;
  final String? sectionName;
  final String? yearName;
  final List<PaperSubject> subjects;

  bool get isEmpty => subjects.every((s) => s.papers.isEmpty);

  factory PapersData.fromJson(Map<String, dynamic> j) => PapersData(
        className: j['className']?.toString(),
        sectionName: j['sectionName']?.toString(),
        yearName: j['yearName']?.toString(),
        subjects: (j['subjects'] as List? ?? []).map((s) {
          final m = s as Map<String, dynamic>;
          final name = _pString(m['subjectName']).trim();
          return PaperSubject(
            name: name,
            papers: (m['papers'] as List? ?? []).map((p) => ExamPaper.fromJson(p as Map<String, dynamic>, name)).toList(),
          );
        }).toList(),
      );
}
