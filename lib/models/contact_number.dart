String _digitsOnly(String v) => v.replaceAll(RegExp(r'\D'), '');

/// One reachable phone number for a student (father / mother / the student's own).
class ContactNumber {
  ContactNumber(this.label, this.number) : digits = _digitsOnly(number);
  final String label;
  final String number;
  final String digits;

  /// International form for wa.me — bare 10-digit Indian numbers get the 91 prefix.
  String get whatsappNumber {
    var d = digits;
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 10) d = '91$d';
    return d;
  }
}

/// Distinct, plausible (>= 10 digits) numbers in call priority order: father → mother → student.
/// Junk like "0" or a 4-digit stub is dropped so WhatsApp/dialer never get a broken link.
List<ContactNumber> buildContacts({String? father, String? mother, String? student}) {
  final out = <ContactNumber>[];
  void add(String label, String? raw) {
    final n = (raw ?? '').trim();
    if (n.isEmpty) return;
    final c = ContactNumber(label, n);
    if (c.digits.length < 10) return;
    if (out.any((o) => o.whatsappNumber == c.whatsappNumber)) return;
    out.add(c);
  }
  add('Father', father);
  add('Mother', mother);
  add('Student', student);
  return out;
}
