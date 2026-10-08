import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';

import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/category/category_list_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/shadow_card.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:sticky_headers/sticky_headers.dart';

class CategoryListView extends StatelessWidget {
  final String tag;
  const CategoryListView(this.tag, {super.key});
  CategoryListController get controller => Get.find<CategoryListController>(tag: tag);
  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Obx(
        () => EasyRefresh(
          refreshOnStart: true,
          controller: controller.easyRefreshController,
          onRefresh: controller.refreshData,
          header: MaterialHeader(
            processedDuration: const Duration(milliseconds: 400),
          ),
          child: ListView.builder(
            padding: AppStyle.edgeInsetsA12,
            itemCount: controller.list.length,
            controller: controller.scrollController,
            itemBuilder: (_, i) {
              var item = controller.list[i];
              return Column(
                children: [
                  StickyHeader(
                    header: Container(
                      padding: AppStyle.edgeInsetsV8.copyWith(left: 4),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    content: buildCategoryContent(context, item),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildCategoryContent(BuildContext context, AppLiveCategory category) {
    return Obx(() {
      final expanded = category.expandedCategory.value;
      final visible = category.showAll.value ? category.children : category.take15;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildCategoryGrid([
            ...visible.map((item) => buildSubCategory(context, category, item)),
            if (!category.showAll.value) buildShowMore(category),
          ]),
          if (expanded != null)
            Container(
              key: ValueKey('expanded-${expanded.id}'),
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(expanded.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(
                      tooltip: '收起',
                      onPressed: () => category.expandedCategory.value = null,
                      icon: const Icon(Icons.expand_less),
                    ),
                  ]),
                  buildCategoryGrid([
                    buildGameTile(context, expanded, '全部', icon: Icons.apps_rounded),
                    ...expanded.children.map((game) => buildGameTile(context, game, game.name)),
                  ]),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget buildCategoryGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        shrinkWrap: true,
        padding: AppStyle.edgeInsetsV8,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: (constraints.maxWidth / 80).floor().clamp(1, 100),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: children,
      ),
    );
  }

  Widget buildGameTile(BuildContext context, LiveSubCategory item, String label, {IconData? icon}) {
    return buildCategoryTile(context, item,
        label: label,
        fallbackIcon: icon ?? Icons.sports_esports_outlined,
        onTap: () => AppNavigator.toCategoryDetail(site: controller.site, category: item));
  }

  Widget buildSubCategory(BuildContext context, AppLiveCategory category, LiveSubCategory item) {
    final selected = category.expandedCategory.value?.id == item.id;
    return buildCategoryTile(
      context,
      item,
      selected: selected,
      expandable: item.children.isNotEmpty,
      fallbackIcon: item.children.isEmpty ? null : gameGroupIcon(item.name),
      onTap: () {
        if (item.children.isEmpty) {
          AppNavigator.toCategoryDetail(site: controller.site, category: item);
        } else {
          category.expandedCategory.value = selected ? null : item;
        }
      },
    );
  }

  IconData gameGroupIcon(String name) => switch (name) {
        '射击游戏' => Icons.gps_fixed_rounded,
        '竞技游戏' => Icons.emoji_events_outlined,
        '单机游戏' => Icons.sports_esports_outlined,
        '棋牌游戏' => Icons.casino_outlined,
        '休闲益智' => Icons.extension_outlined,
        '角色扮演' => Icons.auto_fix_high_outlined,
        '策略卡牌' => Icons.style_outlined,
        _ => Icons.sports_esports_outlined,
      };

  Widget buildCategoryTile(
    BuildContext context,
    LiveSubCategory item, {
    required VoidCallback onTap,
    String? label,
    IconData? fallbackIcon,
    bool selected = false,
    bool expandable = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label ?? item.name,
      child: ShadowCard(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.08) : null,
            border: selected ? Border.all(color: colors.primary.withValues(alpha: 0.45)) : null,
            borderRadius: AppStyle.radius8,
          ),
          child: Stack(children: [
            Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              if ((item.pic?.isNotEmpty ?? false) || fallbackIcon == null)
                NetImage(item.pic ?? '', width: 40, height: 40, borderRadius: 8)
              else
                Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(color: colors.primary.withValues(alpha: 0.06), borderRadius: AppStyle.radius8),
                    child: Icon(fallbackIcon, size: 26, color: colors.primary)),
              AppStyle.vGap4,
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(label ?? item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12))),
            ])),
            if (expandable)
              Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(selected ? Icons.expand_less : Icons.expand_more,
                      size: 14, color: selected ? colors.primary : colors.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  Widget buildShowMore(AppLiveCategory item) {
    return ShadowCard(
      onTap: () {
        item.showAll.value = true;
      },
      child: const Center(
        child: Text(
          "显示全部",
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
