import 'dart:convert';
import 'dart:io';

import 'package:simple_live_core/src/platforms/douyin/douyin_category_parser.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      File('test/fixtures/douyin_categories.json').readAsStringSync();

  for (final runtime in ['pace', 'next']) {
    test('$runtime flight payload preserves three levels and room IDs', () {
      final html =
          '<script>self.__${runtime}_f.push([1,${jsonEncode(fixture)}])</script>';
      final categories = DouyinCategoryParser.parse(html);
      final games = categories.singleWhere((item) => item.name == '游戏');
      expect(games.id, '103,4');
      expect(games.children.first.id, games.id);
      expect(games.children.first.children, isEmpty);
      expect(games.children.length, 8);
      final shooters =
          games.children.singleWhere((item) => item.name == '射击游戏');
      expect(shooters.id, '1,1');
      expect(shooters.parentId, games.id);
      final valorant =
          shooters.children.singleWhere((item) => item.name == '无畏契约');
      expect(valorant.id, '1010017,1');
      expect(valorant.parentId, shooters.id);
      expect(valorant.children, isEmpty);
      final chat = categories.singleWhere((item) => item.name == '聊天');
      expect(chat.children.single.id, chat.id);
    });
  }

  test('handles split flight chunks and escaped quotes/brackets in titles', () {
    const title = '游戏 "] , \\ 测试';
    final payload = jsonEncode({
      'categoryData': [
        {
          'partition': {'id_str': '103', 'type': 4, 'title': title}
        },
      ],
    });
    final split = payload.length ~/ 2;
    final html =
        'self.__pace_f.push([1,${jsonEncode(payload.substring(0, split))}])'
        'self.__pace_f.push([1,${jsonEncode(payload.substring(split))}])';
    expect(DouyinCategoryParser.parse(html).single.name, title);
  });

  test('reports missing and truncated category data', () {
    expect(() => DouyinCategoryParser.parse('<html></html>'),
        throwsFormatException);
    expect(() => DouyinCategoryParser.parse('{"categoryData":[{}'),
        throwsFormatException);
  });
}
