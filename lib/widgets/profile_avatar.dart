import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../services/photo_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Round photo with a graceful fallback: the person's photo when the server has one, otherwise their first letter.
/// Never throws on a broken / missing image - the initial just stays.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 44,
    this.background,
    this.foreground = Colors.white,
    this.border,
    this.fontSize,
    this.localFile,
  });

  final String name;
  final String? photoPath;

  /// A photo just picked on this phone (not uploaded yet) - shown instead of [photoPath] as a live preview.
  final String? localFile;
  final double size;
  final Color? background;
  final Color foreground;
  final BoxBorder? border;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.absoluteUrl(photoPath);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final fallback = Center(
      child: Text(initial, style: TextStyle(color: foreground, fontSize: fontSize ?? size * 0.4, fontWeight: FontWeight.w800)),
    );
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: background == null ? AppGradients.primarySheen : null,
        color: background,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: (localFile ?? '').isNotEmpty
          ? Image.file(File(localFile!), fit: BoxFit.cover, width: size, height: size, cacheWidth: px, errorBuilder: (_, _, _) => fallback)
          : url == null
          ? fallback
          : Image.network(
              url,
              key: ValueKey(url),
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: px,
              errorBuilder: (_, _, _) => fallback,
              frameBuilder: (context, child, frame, sync) => (frame == null && !sync) ? fallback : child,
            ),
    );
  }
}

enum _PhotoChoice { camera, gallery, remove }

/// Lets the user pick a new photo (camera / gallery) or remove the current one. Returns the local file path of a
/// newly picked image, `''` when "Remove photo" was chosen, or null when cancelled.
Future<String?> pickProfilePhoto(BuildContext context, {required bool hasPhoto, String title = 'Profile photo'}) async {
  final choice = await showModalBottomSheet<_PhotoChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, _PhotoChoice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, _PhotoChoice.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(ctx, _PhotoChoice.remove),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return null;
  if (choice == _PhotoChoice.remove) return '';
  try {
    // Resized on the phone first: a 12 MP camera shot is ~4 MB, a 1024px one is ~200 KB and looks identical in the app.
    final picked = await ImagePicker().pickImage(
      source: choice == _PhotoChoice.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return picked?.path;
  } catch (_) {
    if (context.mounted) showSnack(context, 'Could not open the camera / gallery.', isError: true);
    return null;
  }
}

/// Runs the whole "change photo" flow for one saved record: choose -> upload or remove -> returns the new path
/// (`''` after a removal), or null when nothing changed. Errors are shown as a snackbar.
Future<String?> changeProfilePhoto(BuildContext context, {required PhotoOwner owner, required int id, required bool hasPhoto}) async {
  final picked = await pickProfilePhoto(context, hasPhoto: hasPhoto);
  if (picked == null || !context.mounted) return null;
  final service = PhotoService();
  try {
    if (picked.isEmpty) {
      await service.remove(owner, id);
      if (context.mounted) showSnack(context, 'Photo removed.');
      return '';
    }
    final path = await service.upload(owner, id, picked);
    if (context.mounted) showSnack(context, 'Photo updated.');
    return path ?? '';
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, isError: true);
    return null;
  }
}

/// Full-screen, pinch-to-zoom view of a photo. [onChange] adds a "Change photo" button (closes the preview first).
Future<void> showPhotoPreview(BuildContext context, {required String name, required String? photoPath, VoidCallback? onChange}) {
  final url = ApiConfig.absoluteUrl(photoPath);
  if (url == null) return Future.value();
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    pageBuilder: (ctx, _, _) => Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Could not load this photo.', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                  Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            if (onChange != null)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onChange();
                    },
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('Change photo'),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  ));
}

/// [ProfileAvatar] with a small camera badge. Tapping the photo opens a full-screen preview (with a "Change photo"
/// button); tapping the badge - or the avatar when there is no photo yet - opens the change-photo sheet.
/// [onChanged] gets the new path (`''` when removed). When [canEdit] is false, tapping only previews.
class EditableAvatar extends StatefulWidget {
  const EditableAvatar({
    super.key,
    required this.name,
    required this.photoPath,
    required this.owner,
    required this.id,
    required this.onChanged,
    this.size = 84,
    this.canEdit = true,
    this.border,
  });

  final String name;
  final String? photoPath;
  final PhotoOwner owner;
  final int id;
  final ValueChanged<String> onChanged;
  final double size;
  final bool canEdit;
  final BoxBorder? border;

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  bool _busy = false;

  bool get _hasPhoto => (widget.photoPath ?? '').isNotEmpty;

  Future<void> _change() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await changeProfilePhoto(context, owner: widget.owner, id: widget.id, hasPhoto: _hasPhoto);
      if (result != null) widget.onChanged(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onAvatarTap() {
    if (_hasPhoto) {
      showPhotoPreview(context, name: widget.name, photoPath: widget.photoPath, onChange: widget.canEdit ? _change : null);
    } else if (widget.canEdit) {
      _change();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ProfileAvatar(name: widget.name, photoPath: widget.photoPath, size: widget.size, border: widget.border);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(onTap: _onAvatarTap, child: avatar),
          if (_busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))),
              ),
            ),
          if (widget.canEdit)
            Positioned(
              right: -4,
              bottom: -4,
              child: GestureDetector(
                onTap: _change,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Photo chooser used inside the create / edit forms. Nothing is uploaded here: the chosen file (or the "remove"
/// decision) is handed back through [onChanged] and the form uploads it after the record itself has been saved,
/// exactly like the website's form does.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.name,
    required this.serverPath,
    required this.pickedFile,
    required this.removed,
    required this.onChanged,
    this.size = 96,
  });

  final String name;
  final String? serverPath;
  final String? pickedFile;
  final bool removed;
  final double size;

  /// (newLocalFile, removeExisting). Both null/false = untouched.
  final void Function(String? pickedFile, bool removed) onChanged;

  bool get _hasPhoto => (pickedFile ?? '').isNotEmpty || (!removed && (serverPath ?? '').isNotEmpty);

  Future<void> _tap(BuildContext context) async {
    final result = await pickProfilePhoto(context, hasPhoto: _hasPhoto);
    if (result == null) return;
    if (result.isEmpty) {
      onChanged(null, (serverPath ?? '').isNotEmpty);
    } else {
      onChanged(result, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _tap(context),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(
                    name: name,
                    size: size,
                    photoPath: removed ? null : serverPath,
                    localFile: pickedFile,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 3),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasPhoto ? 'Tap to change or remove' : 'Tap to add a photo',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
