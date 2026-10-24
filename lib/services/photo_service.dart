import '../core/api_client.dart';

/// Whose photo it is. The server keeps one file + one DB column per record, shared with the web app, so a photo
/// set here shows on the website immediately and the other way round.
enum PhotoOwner { student, faculty, user }

class PhotoService {
  final _client = ApiClient.instance;

  String _base(PhotoOwner owner, int id) {
    switch (owner) {
      case PhotoOwner.student:
        return '/api/students/$id/photo';
      case PhotoOwner.faculty:
        return '/api/faculty/$id/photo';
      case PhotoOwner.user:
        return '/api/users/$id/photo';
    }
  }

  /// Uploads [filePath] and returns the new site-relative photo path.
  Future<String?> upload(PhotoOwner owner, int id, String filePath) async {
    try {
      final res = await _client.uploadFile(_base(owner, id), filePath: filePath);
      final data = res.data;
      return data is Map ? data['profilePicPath']?.toString() : null;
    } on ApiException catch (e) {
      throw _friendly(e);
    }
  }

  Future<void> remove(PhotoOwner owner, int id) async {
    try {
      await _client.delete(_base(owner, id));
    } on ApiException catch (e) {
      throw _friendly(e);
    }
  }

  /// A 404 with no message means the server has no photo endpoint yet (website not updated) - say that instead of
  /// the generic "Something went wrong."
  ApiException _friendly(ApiException e) => e.statusCode == 404 && e.message == 'Something went wrong.'
      ? ApiException('Photo upload is not available on the server yet. Please update the website/server first.', statusCode: 404)
      : e;
}
