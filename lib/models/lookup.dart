int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';

class LookupItem {
  LookupItem({required this.id, required this.name, this.isActive = true});
  final int id;
  final String name;
  final bool isActive;

  factory LookupItem.fromYear(Map<String, dynamic> j) => LookupItem(id: _asInt(j['yearId']), name: _asString(j['yearName']), isActive: j['isActive'] != false);
  factory LookupItem.fromClass(Map<String, dynamic> j) => LookupItem(id: _asInt(j['classId']), name: _asString(j['className']), isActive: j['isActive'] != false);
  factory LookupItem.fromSection(Map<String, dynamic> j) => LookupItem(id: _asInt(j['sectionId']), name: _asString(j['sectionName']), isActive: j['isActive'] != false);
  factory LookupItem.fromBatch(Map<String, dynamic> j) => LookupItem(id: _asInt(j['batchId']), name: _asString(j['batchName']), isActive: j['isActive'] != false);
  factory LookupItem.fromFeeType(Map<String, dynamic> j) => LookupItem(id: _asInt(j['feeTypeId']), name: _asString(j['typeName']), isActive: j['isActive'] != false);
  factory LookupItem.fromExpenseCat(Map<String, dynamic> j) => LookupItem(id: _asInt(j['categoryId']), name: _asString(j['categoryName']), isActive: j['isActive'] != false);
}
