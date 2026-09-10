import 'package:flutter/material.dart';
import 'package:jtek_app/src/ui/pages/account/account_page.dart';
import 'package:jtek_app/src/ui/pages/catalog/categories_page.dart';
import 'package:jtek_app/src/ui/pages/catalog/favorite_page.dart';
import 'package:jtek_app/src/ui/pages/home_page.dart';
import 'package:jtek_app/src/ui/pages/orders/orders_page.dart';

class HomeNavigationProvider extends ChangeNotifier {
  Widget homePage = HomePage();

  void categoryOnTap(int catIndex, [String? categoryTitle]) {
    homePage = CategoriesPage(catIndex, categoryTitle: categoryTitle);
    notifyListeners();
  }

  void categoryBack() {
    homePage = HomePage();
    notifyListeners();
  }

  int currentIndex = 0;

  void changePage(int index) {
    currentIndex = index;
    if (homePage is! HomePage) {
      homePage = HomePage();
    }
    notifyListeners();
  }

  Widget getMainWidget() {
    switch (currentIndex) {
      case 0:
        return homePage;
      case 1:
        return OrderPage();
      case 2:
        return FavoritePage();
      case 3:
        return AccountPage();
    }
    return homePage;
  }

  Future<bool> onWillPop() async {
    if (currentIndex != 0) {
      changePage(0);
      return Future.value(false);
    } else {
      if (homePage is! HomePage) {
        homePage = HomePage();
        notifyListeners();
        return Future.value(false);
      }
    }
    return Future.value(true);
  }
}
