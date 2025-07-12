import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

final log = Logger('ShopyAppLogger');

void setupLogger() {
  Logger.root.level =
      Level.ALL; // You can change to WARNING or INFO in production
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
    );
  });
}
