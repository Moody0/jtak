import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';

class OrderProvider extends BaseProvider<OrderModel> {
  final SolApi _api = locator<SolApi>();
  OrderModel? order;

  Future refreshData() async {
    final selectedId = order?.id;
    page = 0;
    await loadPagedData();
    if (selectedId != null) {
      order = dataList.cast<OrderModel?>().firstWhere(
        (item) => item?.id == selectedId,
        orElse: () => order,
      );
      notifyListeners();
    }
  }

  Future loadPagedData() async {
    await loadInfinityData(
      loadData: (page) async {
        Map body = {
          'pageNumber': page,
          "pageSize": 20,
          "sortField": "id",
          "sortOrder": "desc",
        };
        var res = await _api.postRequest('/Orders/Mine', body);
        List data = res['items'];
        return data.map((e) => OrderModel.fromMap(e)).toList();
      },
    );
  }

  Future loadOrder(int id) async {
    return await loadBaseData(
      loadBody: () async {
        var data = await _api.getRequest('/Orders/$id');
        order = OrderModel.fromMap(data);
      },
    );
  }

  void setOrderObject(OrderModel orderObject) async {
    order = orderObject;
    if (orderIsEmpty()) {
      await loadOrder(order!.id ?? -1);
    }
  }

  OrderDetailsStatus getOrderStatus(OrderModel order) {
    OrderDetailsStatus status = OrderDetailsStatus.pending;
    if (GlobalVar.checkListNotEmpty(order.orderDetails)) {
      status =
          order.orderDetails!.first.orderDetailStatus ??
          OrderDetailsStatus.pending;
      for (var element in order.orderDetails!) {
        if (element.orderDetailStatus!.index < status.index) {
          status = element.orderDetailStatus ?? OrderDetailsStatus.pending;
        }
      }
    }
    return status;
  }

  Future acceptOrder(OrderModel order) async {
    await loadBaseData(
      loadBody: () async {
        bool res = await _api.postRequest('/Orders/Accept/${order.id}', {});
        if (res) {
          setOrderDetailsStatus(order, OrderDetailsStatus.merchantAccepted);
        }
      },
    );
  }

  Future rejectOrder(OrderModel order) async {
    return await loadBaseData(
      loadBody: () async {
        bool res = await _api.postRequest('/Orders/Reject/${order.id}', {});
        if (res) {
          setOrderDetailsStatus(order, OrderDetailsStatus.merchantRejected);
        }
      },
    );
  }

  bool orderIsEmpty() {
    return order == null ||
        !GlobalVar.checkListNotEmpty(order!.orderDetails) ||
        order!.id == null;
  }

  void setOrderDetailsStatus(OrderModel order, OrderDetailsStatus status) {
    order = dataList.firstWhere((element) => element.id == order.id);
    if (GlobalVar.checkListNotEmpty(order.orderDetails)) {
      for (var i = 0; i < order.orderDetails!.length; i++) {
        order.orderDetails![i].orderDetailStatus = status;
      }
    }
  }
}
