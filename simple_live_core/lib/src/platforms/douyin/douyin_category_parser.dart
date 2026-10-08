import 'dart:convert';

import '../../model/live_category.dart';

/// Reads the complete category tree from Douyin's Next.js flight payload.
class DouyinCategoryParser {
  static List<LiveCategory> parse(String html) {
    final payload =
        RegExp(r'self\.__(?:next|pace)_f\.push\(\[1,("(?:\\.|[^"\\])*")\]\)')
            .allMatches(html)
            .map((match) => jsonDecode(match.group(1)!) as String)
            .join();
    final source = payload.isEmpty ? html : payload;
    final key = RegExp(r'"categoryData"\s*:\s*\[').firstMatch(source);
    if (key == null) {
      throw const FormatException('Douyin categoryData not found');
    }
    final start = key.end - 1;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < source.length; i++) {
      final char = source[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') inString = true;
      if (char == '[') depth++;
      if (char == ']' && --depth == 0) {
        final data = jsonDecode(source.substring(start, i + 1)) as List;
        return data.map((item) {
          final root = _parseNode(item as Map<String, dynamic>, '');
          return LiveCategory(
            id: root.id,
            name: root.name,
            children: [
              LiveSubCategory(
                id: root.id,
                name: root.name,
                parentId: root.id,
                pic: '',
              ),
              ...root.children,
            ],
          );
        }).toList();
      }
    }
    throw const FormatException('Incomplete Douyin categoryData');
  }

  static LiveSubCategory _parseNode(
      Map<String, dynamic> node, String parentId) {
    final partition = node['partition'] as Map<String, dynamic>;
    final id = '${partition['id_str']},${partition['type']}';
    return LiveSubCategory(
      id: id,
      name: partition['title'] as String? ?? '',
      parentId: parentId,
      pic: '',
      children: (node['sub_partition'] as List? ?? [])
          .map((child) => _parseNode(child as Map<String, dynamic>, id))
          .toList(),
    );
  }
}
