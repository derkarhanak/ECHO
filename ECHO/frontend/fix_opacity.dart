// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('lib');
  int totalChanges = 0;
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      bool changed = false;

      while (content.contains('.withOpacity(')) {
        int start = content.indexOf('.withOpacity(');
        int parenCount = 1;
        int argStart = start + '.withOpacity('.length;
        int end = argStart;

        while (parenCount > 0 && end < content.length) {
          if (content[end] == '(') parenCount++;
          if (content[end] == ')') parenCount--;
          end++;
        }

        String before = content.substring(0, start);
        String arg = content.substring(argStart, end - 1);
        String after = content.substring(end);

        content = '$before.withValues(alpha: $arg)$after';
        changed = true;
        totalChanges++;
      }

      if (changed) {
        file.writeAsStringSync(content);
        print('Fixed ${file.path}');
      }
    }
  }
  print('Total overrides: $totalChanges');
}
