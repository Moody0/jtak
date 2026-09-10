import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/themes/colors.dart';
import 'package:jtek_app/src/utils/custom_widgets/image_widgets.dart';
import '../../../core/models/catalog/category_model.dart';
import '../../../core/models/catalog/tag_model.dart';
import '../../../../main_imports.dart';

class CategorySingleItem extends StatelessWidget {
  final CategoryModel item;
  final Function() onTap;

  const CategorySingleItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    double imageWidth = 75;
    double imageHeight = imageWidth * 4 / 3;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            ImageView(
              item.icon,
              imageHeight: 400,
              imageWidth: 300,
              width: imageWidth,
              height: imageHeight,
              alignment: AlignmentDirectional.centerStart,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(item.title ?? '', style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChipItem extends StatelessWidget {
  final CategoryModel item;
  final Function()? onTap;
  const CategoryChipItem({required this.item, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: context.appTheme.primaryColorLight,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        item.title ?? '',
        style: context.textTheme.bodyLarge?.copyWith(fontSize: 10),
      ),
    );
  }
}

class TagChipItem extends StatelessWidget {
  final TagModel item;
  const TagChipItem(this.item);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: context.appTheme.primaryColorLight,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        item.name ?? '',
        style: context.textTheme.bodyLarge?.copyWith(fontSize: 10),
      ),
    );
  }
}

class CategoryHeaderItem extends StatelessWidget {
  final CategoryModel item;
  final bool isActive;
  final void Function()? onTap;
  final Key? catKey;
  const CategoryHeaderItem(this.item, {this.isActive = false, this.onTap, this.catKey});

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.only(top: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          color: kAccentColor,
        ),
        child: _buildBody(context),
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    TextStyle textStyle = context.textTheme.bodyLarge!.copyWith(color: kPrimaryColor, height: 1);
    if (isActive) textStyle = context.textTheme.titleLarge!.copyWith(color: Colors.white, height: 1);
    return InkWell(
      key: catKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(item.title ?? '', style: textStyle),
      ),
    );
  }
}
