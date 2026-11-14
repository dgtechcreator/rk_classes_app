import '../core/api_client.dart';

int _i(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _iN(dynamic v) => v == null ? null : _i(v);
String? _sN(dynamic v) => v?.toString();

/// A room lectures are held in.
class Classroom {
  Classroom.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = (j['name'] ?? '').toString(),
        capacity = _iN(j['capacity']),
        location = _sN(j['location']),
        isActive = j['isActive'] != false;
  final int id;
  final String name;
  final int? capacity;
  final String? location;
  final bool isActive;
}

/// One lecture as the classroom board / history shows it. [phase]: done | ended | ongoing | upcoming | cancelled.
class RoomLecture {
  RoomLecture.fromJson(Map<String, dynamic> j)
      : lectureId = _i(j['lectureId']),
        date = DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
        startTime = (j['startTime'] ?? '').toString(),
        endTime = (j['endTime'] ?? '').toString(),
        classroom = _sN(j['classroom']),
        subject = (j['subject'] ?? '').toString(),
        teacher = _sN(j['teacher']),
        groupLabel = (j['groupLabel'] ?? '').toString(),
        topic = _sN(j['topic']),
        status = (j['status'] ?? '').toString(),
        statusNote = _sN(j['statusNote']),
        phase = (j['phase'] ?? '').toString();
  final int lectureId;
  final DateTime date;
  final String startTime, endTime;
  final String? classroom;
  final String subject;
  final String? teacher;
  final String groupLabel;
  final String? topic;
  final String status;
  final String? statusNote;
  final String phase;
}

class RoomState {
  RoomState.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = (j['name'] ?? '').toString(),
        capacity = _iN(j['capacity']),
        location = _sN(j['location']),
        busy = j['state'] == 'busy',
        busyUntil = _sN(j['busyUntil']),
        current = j['current'] == null ? null : RoomLecture.fromJson(j['current'] as Map<String, dynamic>),
        next = j['next'] == null ? null : RoomLecture.fromJson(j['next'] as Map<String, dynamic>),
        day = ((j['day'] as List?) ?? const []).map((e) => RoomLecture.fromJson(e as Map<String, dynamic>)).toList();
  final int id;
  final String name;
  final int? capacity;
  final String? location;
  final bool busy;
  final String? busyUntil;
  final RoomLecture? current, next;
  final List<RoomLecture> day;
}

class BoardData {
  BoardData.fromJson(Map<String, dynamic> j)
      : date = DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
        isToday = j['isToday'] == true,
        now = (j['now'] ?? '').toString(),
        busy = _i(j['busy']),
        free = _i(j['free']),
        total = _i(j['total']),
        rooms = ((j['rooms'] as List?) ?? const []).map((e) => RoomState.fromJson(e as Map<String, dynamic>)).toList();
  final DateTime date;
  final bool isToday;
  final String now;
  final int busy, free, total;
  final List<RoomState> rooms;
}

class RoomHistory {
  RoomHistory.fromJson(Map<String, dynamic> j)
      : count = _i(j['count']),
        hours = (j['hours'] is num) ? (j['hours'] as num).toDouble() : 0,
        lectures = ((j['lectures'] as List?) ?? const []).map((e) => RoomLecture.fromJson(e as Map<String, dynamic>)).toList();
  final int count;
  final double hours;
  final List<RoomLecture> lectures;
}

/// Wraps api/classrooms: the master list, the live board and the room history.
class ClassroomService {
  final _client = ApiClient.instance;
  static String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Classroom>> list({bool all = false}) async {
    final res = await _client.get('/api/classrooms', query: {if (all) 'all': 'true'});
    return ((res.data as Map<String, dynamic>)['classrooms'] as List? ?? []).map((e) => Classroom.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save({int id = 0, required String name, int? capacity, String? location, bool isActive = true}) async {
    await _client.post('/api/classrooms/save', data: {'classroomId': id, 'name': name, 'capacity': capacity, 'location': location, 'isActive': isActive});
  }

  Future<void> delete(int id) async => _client.post('/api/classrooms/$id/delete');

  Future<BoardData> board({DateTime? date}) async {
    final res = await _client.get('/api/classrooms/board', query: {if (date != null) 'date': _d(date)});
    return BoardData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomHistory> history({int? classroomId, DateTime? from, DateTime? to, String? q}) async {
    final res = await _client.get('/api/classrooms/history', query: {
      if (classroomId != null) 'classroomId': classroomId,
      if (from != null) 'from': _d(from),
      if (to != null) 'to': _d(to),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    });
    return RoomHistory.fromJson(res.data as Map<String, dynamic>);
  }
}
