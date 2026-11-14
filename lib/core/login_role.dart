import '../models/student.dart';

/// "+91 81082 94501" -> "8108294501" (the same rule the server uses to match a login number with the numbers in the student records).
String phoneKey(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length < 7) return '';
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

/// Who this login is, from the number it was made with. A login belongs to a PHONE NUMBER, and the number is matched with the
/// father's, the mother's and the student's own number in the student records:
///  - father's / mother's number  -> a parent login (sees all the children with that number)
///  - the student's own number    -> a student login (sees that student)
/// When a number is both (a student using the parent's phone) it is shown as a parent.
/// True when the student himself signed in (his own number, not the father's / mother's).
bool isStudentLogin(String loginPhone, List<Student> kids) => portalRoleLabel(loginPhone, kids) == 'Student';

/// First word of a name ("Vivek Rajesh Pal" -> "Vivek").
String firstWord(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return p.isEmpty ? '' : p.first;
}

String portalRoleLabel(String loginPhone, List<Student> kids) {
  final k = phoneKey(loginPhone);
  if (k.isEmpty) return 'Parent / Student';
  final parent = kids.any((s) => phoneKey(s.fatherPhone) == k || phoneKey(s.motherPhone) == k);
  if (parent) return 'Parent';
  final student = kids.any((s) => phoneKey(s.phone) == k);
  return student ? 'Student' : 'Parent / Student';
}
