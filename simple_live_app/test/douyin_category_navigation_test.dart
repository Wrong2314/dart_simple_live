import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/modules/category/category_list_view.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_core/simple_live_core.dart';

void main() {
  final game = LiveSubCategory(
    id: '1010017,1',
    name: '无畏契约',
    parentId: '1,1',
  );
  final shooters = LiveSubCategory(
    id: '1,1',
    name: '射击游戏',
    parentId: '103,4',
    children: [game],
  );

  final competitive = LiveSubCategory(
    id: '2,1',
    name: '竞技游戏',
    parentId: '103,4',
    children: [LiveSubCategory(id: '1010014,1', name: '英雄联盟', parentId: '2,1')],
  );

  Future<void> mount(WidgetTester tester, {double width = 800}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.testMode = true;
    Get.put(CategoryListController(Sites.allSites['douyin']!), tag: 'douyin');
    final category = AppLiveCategory(id: '103,4', name: '游戏', children: [shooters, competitive, game]);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: Builder(
        builder: (context) => const CategoryListView('douyin').buildCategoryContent(context, category),
      ))),
      getPages: [
        GetPage(
          name: RoutePath.kCategoryDetail,
          page: () => Scaffold(body: Text('分区：${(Get.arguments[1] as LiveSubCategory).id}')),
        )
      ],
    ));
    await tester.pumpAndSettle();
  }

  tearDown(() => Get.reset());

  testWidgets('expands inline and opens the selected game partition', (tester) async {
    await mount(tester);
    await tester.tap(find.text('射击游戏'));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.byKey(const ValueKey('expanded-1,1')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('expanded-1,1')), matching: find.text('无畏契约')));
    await tester.pumpAndSettle();
    expect(find.text('分区：1010017,1'), findsOneWidget);
  });

  testWidgets('all opens the parent partition', (tester) async {
    await mount(tester);
    await tester.tap(find.text('射击游戏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('分区：1,1'), findsOneWidget);
  });

  testWidgets('switching groups replaces the expanded games', (tester) async {
    await mount(tester);
    await tester.tap(find.text('射击游戏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('竞技游戏'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expanded-1,1')), findsNothing);
    expect(find.text('英雄联盟'), findsOneWidget);
  });

  testWidgets('tapping the selected group again collapses it', (tester) async {
    await mount(tester);
    await tester.tap(find.text('射击游戏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('射击游戏').first);
    await tester.pumpAndSettle();
    expect(find.text('全部'), findsNothing);
  });

  testWidgets('leaf categories still navigate directly', (tester) async {
    await mount(tester);
    await tester.tap(find.text('无畏契约'));
    await tester.pumpAndSettle();
    expect(find.text('分区：1010017,1'), findsOneWidget);
  });

  testWidgets('phone width supports expansion and explicit collapse without overflow', (tester) async {
    await mount(tester, width: 360);
    await tester.tap(find.text('射击游戏'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('收起'));
    await tester.pumpAndSettle();
    expect(find.text('全部'), findsNothing);
  });
}
