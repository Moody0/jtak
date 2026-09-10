import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/user/address_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../utils/custom_widgets/messages.dart';

class ChooseLocationMapPage extends StatefulWidget {
  static const String routeName = '/ChooseLocationMapPage';

  const ChooseLocationMapPage({super.key});

  @override
  State<ChooseLocationMapPage> createState() => _ChooseLocationMapPageState();
}

class _ChooseLocationMapPageState extends State<ChooseLocationMapPage> {
  late AddressProvider addressProvider;

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<AddressProvider>(context, listen: false);
    prov.cameraPosition = const LatLng(33.5138, 36.2765); // Damascus default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
      prov.resolveAddressName(prov.cameraPosition.latitude, prov.cameraPosition.longitude);
    });
  }

  @override
  void dispose() {
    addressProvider.controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    addressProvider = Provider.of<AddressProvider>(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        _mapWidget(),
        _marker(),
        _gpsButton(),
      ],
    );
  }

  Widget _marker() {
    return const Align(
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(bottom: 35),
        child: Icon(
          Icons.location_pin,
          color: kPrimaryOrange,
          size: 42,
        ),
      ),
    );
  }

  Widget _gpsButton() {
    return PositionedDirectional(
      bottom: 155,
      end: 16,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _getCurrentLocation();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.my_location,
              color: kPrimaryOrange,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Future _getCurrentLocation() async {
    try {
      LatLng? latLng = await LocationService().getCurrentLocation();
      if (latLng != null) {
        addressProvider.mapAnimateToPosision(latLng);
      } else {
        addressProvider.resolveAddressName(addressProvider.cameraPosition.latitude, addressProvider.cameraPosition.longitude);
      }
    } catch (err) {
      if (mounted) {
        showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
      }
    }
  }

  GoogleMap _mapWidget() {
    return GoogleMap(
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: addressProvider.cameraPosition,
        zoom: addressProvider.mapZoomLevel,
      ),
      onMapCreated: (GoogleMapController controller) {
        addressProvider.controller = controller;
        addressProvider.resolveAddressName(addressProvider.cameraPosition.latitude, addressProvider.cameraPosition.longitude);
      },
      onCameraMove: (CameraPosition position) {
        addressProvider.onCameraMoved(position.target);
      },
      onTap: (LatLng position) {
        HapticFeedback.selectionClick();
        addressProvider.mapAnimateToPosision(position);
      },
      myLocationButtonEnabled: false,
      onCameraMoveStarted: () {
        addressProvider.setStage(0);
      },
      onCameraIdle: () {
        addressProvider.onCameraIdle();
      },
    );
  }
}
