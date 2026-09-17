import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:app_jtak_delivery/src/core/enums/viewstate.dart';

class BaseProvider<T> extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  ViewState get state => _state;
  void setState(ViewState viewState) {
    _state = viewState;
    notifyListeners();
  }

  get isBusy => _state == ViewState.busy;

  List<T> dataList = [];
  final int nextPageThreshold = 5;
  int page = 0;
  bool isMoreAvailable = true;

  Future loadInfinityData(
      {required Future<List<T>> Function(int page) loadData}) async {
    log('///////////////////////////////  loadinfinityData  $page');
    try {
      _state = ViewState.busy;
      if (page == 0) {
        dataList.clear();
        // A completed previous pagination run must not prevent a later
        // pull-to-refresh from requesting the first page again.
        isMoreAvailable = true;
      }

      var list = await loadData(page);

      dataList.insertAll(dataList.length, list);
      ++page;
      if (list.isEmpty) isMoreAvailable = false;

      setState(ViewState.idle);
    } catch (error) {
      setState(ViewState.idle);
      rethrow;
    }
  }

  void resetSetting() {
    page = 0;
    isMoreAvailable = true;
    dataList.clear();
  }

  Future loadBaseData({required Future Function() loadBody}) async {
    try {
      setState(ViewState.busy);
      await loadBody();
      setState(ViewState.idle);
    } catch (err) {
      setState(ViewState.idle);
      debugPrint(err.toString());
      rethrow;
    }
  }
}
