// lib/utils/file_opener.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class FileOpener {
  /// Save [bytes] to a temporary file named [fileName] and open with system viewer.
  static Future<String> saveAndOpenBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(path);
    return result.type.name; // e.g., 'done', 'error', etc.
  }

  /// Open an existing file at [path].
  static Future<String> openPath(String path) async {
    final result = await OpenFilex.open(path);
    return result.type.name;
  }
}
