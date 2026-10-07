int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _asDoubleN(dynamic v) => v == null ? null : _asDouble(v);
String _asString(dynamic v) => v?.toString() ?? '';

/// One line of a class-toppers list — only a name, marks and percentage (parents never see other
/// students' admission/roll numbers). Mirrors ParentToppersHelper on the server.
class TopperRow {
  TopperRow({required this.rank, required this.fullName, required this.percentage, required this.totalObtained, required this.totalMax, required this.isMe});
  final int rank;
  final String fullName;
  final double percentage;
  final double totalObtained;
  final double totalMax;

  /// True for the parent's own child, so the row can be highlighted.
  final bool isMe;

  factory TopperRow.fromJson(Map<String, dynamic> j) => TopperRow(
        rank: _asInt(j['rank']),
        fullName: _asString(j['fullName']).trim(),
        percentage: _asDouble(j['percentage']),
        totalObtained: _asDouble(j['totalObtained']),
        totalMax: _asDouble(j['totalMax']),
        isMe: j['isMe'] == true,
      );
}

/// Top 5 plus where the child stands (overall, or inside one subject).
class TopperSection {
  TopperSection({required this.ranked, this.myRank, this.myPercentage, required this.top});
  final int ranked;
  final int? myRank;
  final double? myPercentage;
  final List<TopperRow> top;

  bool get isEmpty => top.isEmpty;
  bool get meInTop => top.any((t) => t.isMe);

  factory TopperSection.fromJson(Map<String, dynamic> j) => TopperSection(
        ranked: _asInt(j['ranked']),
        myRank: _asIntN(j['myRank']),
        myPercentage: _asDoubleN(j['myPercentage']),
        top: (j['top'] as List? ?? []).map((e) => TopperRow.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// GET /api/parent/toppers — the child's own class and medium.
class ClassToppers {
  ClassToppers({this.className, this.sectionName, this.yearName, required this.overall, required this.subjects});
  final String? className;
  final String? sectionName;
  final String? yearName;
  final TopperSection overall;
  final Map<String, TopperSection> subjects;

  String get classLabel =>
      [className, sectionName].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).join(' • ');

  factory ClassToppers.fromJson(Map<String, dynamic> j) {
    final subs = <String, TopperSection>{};
    for (final s in (j['subjects'] as List? ?? [])) {
      final m = s as Map<String, dynamic>;
      subs[_asString(m['subjectName']).trim()] = TopperSection.fromJson(m['top'] as Map<String, dynamic>);
    }
    return ClassToppers(
      className: j['className']?.toString(),
      sectionName: j['sectionName']?.toString(),
      yearName: j['yearName']?.toString(),
      overall: TopperSection.fromJson(j['overall'] as Map<String, dynamic>),
      subjects: subs,
    );
  }
}
