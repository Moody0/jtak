import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:jtek_app/src/config/constants/constants.dart';
import 'package:jtek_app/src/config/themes/colors.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/ui/pages/address/address_page.dart';
import 'package:jtek_app/src/utils/custom_widgets/init_widget.dart';
import 'package:jtek_app/src/utils/custom_widgets/messages.dart';
import '../../../core/controllers/user/address_provider.dart';
import '../../../core/models/user/address_model.dart';
import '../../../utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class AddressSingleItem extends StatelessWidget {
  final AddressModel item;
  const AddressSingleItem(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final mainAddress = locator<AppParametersProvider>().mainAddressService.mainAddress;
    final isSelected = mainAddress.id == item.id;

    final title = item.title ?? 'عنواني';
    final isHome = title.contains('منزل') || title.toLowerCase().contains('home');
    final isWork = title.contains('عمل') || title.toLowerCase().contains('work');

    final IconData icon = isHome
        ? PhosphorIconsFill.house
        : (isWork ? PhosphorIconsFill.buildings : PhosphorIconsFill.mapPin);

    final Color iconColor = isHome
        ? kPrimaryOrange
        : (isWork ? const Color(0xFF3B82F6) : const Color(0xFF10B981));

    final Color iconBg = isHome
        ? const Color(0xFFFFF0E8)
        : (isWork ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            Provider.of<AppParametersProvider>(context, listen: false).mainAddressService.setMainAddress(item);
            AddressProvider provider = Provider.of<AddressProvider>(context, listen: false);
            provider.globalMessage = str.app.addressHasBeenChanged;
            InitWidget.restartApp(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Squircle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 22,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Address Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kCharcoalDark,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'العنوان الحالي',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.fullAddress ?? 'دمشق، سوريا',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete Action
                _buildDeleteAction(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAction(BuildContext context) {
    if (Provider.of<AddressProvider>(context).dataList.length > 1 && item.id != null && item.id != 0) {
      return GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          var res = await showDialog(
            context: context,
            builder: (context) => CustomConfirmationDialog(
              title: str.msg.deleteConfermation,
              yesBTNCallBack: () {
                context.pop(data: true);
              },
            ),
          );
          if (res is bool && res && context.mounted) {
            final addressProvider = Provider.of<AddressProvider>(context, listen: false);
            await addressProvider.delete(item.id!);
            if (context.mounted) {
              context.showSnakBar(str.msg.addressDeleteSuccessfully);
            }
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(
              PhosphorIconsRegular.trash,
              color: Color(0xFFEF4444),
              size: 16,
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class AddressAppBarButton extends StatelessWidget {
  final bool showBackground;
  const AddressAppBarButton({this.showBackground = true});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.navigateName(AddressPage.routeName);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBackground) SvgPicture.asset('${kAssetSvgBase}address_abbbar.svg', fit: BoxFit.fill),
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      child: Text(
                        str.app.theAddress,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall!.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        locator<AppParametersProvider>().mainAddressService.mainAddress.title ?? str.app.myAddress,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showBackground)
                const Icon(
                  Icons.arrow_back_ios_new,
                  size: 15,
                  color: Colors.white,
                ),
              const SizedBox(width: 35),
            ],
          )
        ],
      ),
    );
  }
}
