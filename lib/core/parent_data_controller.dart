import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/parent_service.dart';
import 'api_client.dart';

/// Shared across the parent shell's Home/Attendance/Grades tabs so switching tabs doesn't re-fetch
/// and child selection stays in sync everywhere — provided once at [ParentShell], not per-screen.
class ParentDataController extends ChangeNotifier {
  final _service = ParentService();

  bool loading = true;
  String? error;
  List<Student> children = [];
  Student? selected;
  ParentDashboardData? data;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final kids = await _service.getChildren();
      final sel = selected != null && kids.any((c) => c.studentId == selected!.studentId)
          ? kids.firstWhere((c) => c.studentId == selected!.studentId)
          : (kids.isNotEmpty ? kids.first : null);
      final d = sel != null ? await _service.getDashboard(sel.studentId) : null;
      children = kids;
      selected = sel;
      data = d;
      loading = false;
    } on ApiException catch (e) {
      error = e.message;
      loading = false;
    }
    notifyListeners();
  }

  Future<void> selectChild(Student s) async {
    if (s.studentId == selected?.studentId) return;
    selected = s;
    loading = true;
    notifyListeners();
    try {
      data = await _service.getDashboard(s.studentId);
      loading = false;
    } on ApiException catch (e) {
      error = e.message;
      loading = false;
    }
    notifyListeners();
  }
}
