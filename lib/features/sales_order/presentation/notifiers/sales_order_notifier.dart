// lib/features/sales_order/presentation/notifiers/sales_order_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart'; // To catch DioException specifically
import '../../domain/usecases/get_sales_orders_usecase.dart';
import '../../domain/usecases/get_sales_order_detail_usecase.dart';
import '../../domain/usecases/update_sales_order_status_usecase.dart';
import '../../providers/sales_order_state.dart';
import '../../../../core/utils/logger.dart'; // Your logger

class SalesOrderNotifier extends StateNotifier<SalesOrderState> {
  final GetSalesOrdersUseCase _getSalesOrdersUseCase;
  final GetSalesOrderDetailUseCase _getSalesOrderDetailUseCase;
  final UpdateSalesOrderStatusUseCase _updateSalesOrderStatusUseCase;

  SalesOrderNotifier({
    required GetSalesOrdersUseCase getSalesOrdersUseCase,
    required GetSalesOrderDetailUseCase getSalesOrderDetailUseCase,
    required UpdateSalesOrderStatusUseCase updateSalesOrderStatusUseCase,
  })  : _getSalesOrdersUseCase = getSalesOrdersUseCase,
        _getSalesOrderDetailUseCase = getSalesOrderDetailUseCase,
        _updateSalesOrderStatusUseCase = updateSalesOrderStatusUseCase,
        super(SalesOrderState.initial());

  Future<void> fetchOrders({String? orderNumber, int? status}) async {
    // Update current filters in state if new ones are provided
    if (orderNumber != null) {
      state = state.copyWith(currentOrderNumberQuery: orderNumber);
    }
    if (status != null) {
      state = state.copyWith(currentStatusFilterCode: status);
    } else if (orderNumber == null) { // if status is explicitly null (e.g. "All" selected) and orderNumber is not being set
      state = state.copyWith(clearStatusFilter: true);
    }


    state = state.copyWith(listState: ScreenState.loading);
    logger.d(
        "Notifier: Fetching orders with query: '${state.currentOrderNumberQuery}', status: ${state.currentStatusFilterCode}");

    try {
      final ordersData = await _getSalesOrdersUseCase(
        orderNumberQuery: state.currentOrderNumberQuery.isEmpty
            ? null
            : state.currentOrderNumberQuery,
        statusFilter: state.currentStatusFilterCode?.toString(), // API expects string status
      );
      state = state.copyWith(
        listState: ScreenState.loaded,
        orders: ordersData,
        listErrorMessage: '', // Clear previous error
      );
    } on DioException catch (e, s) {
      logger.e("Notifier: DioException fetching orders", error: e, stackTrace: s);
      String errorMessage = "网络错误: ${e.message}";
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      }
      state = state.copyWith(
          listState: ScreenState.error, listErrorMessage: errorMessage, orders: []); // Clear orders on error
    } catch (e, s) {
      logger.e("Notifier: Exception fetching orders", error: e, stackTrace: s);
      state = state.copyWith(
          listState: ScreenState.error,
          listErrorMessage: "发生意外错误: $e", orders: []); // Clear orders on error
    }
  }

  void applyOrderNumberFilter(String query) {
    // This will call fetchOrders, which then updates state.currentOrderNumberQuery
    fetchOrders(orderNumber: query);
  }

  void applyStatusFilter(int? statusCode) {
    // This will call fetchOrders, which then updates state.currentStatusFilterCode
    fetchOrders(status: statusCode);
  }

  Future<void> fetchOrderDetail(String orderId) async {
    state = state.copyWith(detailState: ScreenState.loading, clearSelectedOrder: true, detailErrorMessage: '');
    try {
      final orderData = await _getSalesOrderDetailUseCase(orderId);
      state = state.copyWith(
        detailState: ScreenState.loaded,
        selectedOrder: orderData,
      );
    } on DioException catch (e,s) {
      logger.e("Notifier: DioException fetching order detail", error: e, stackTrace: s);
      state = state.copyWith(
          detailState: ScreenState.error, detailErrorMessage: "网络错误: ${e.message}");
    } catch (e,s) {
      logger.e("Notifier: Exception fetching order detail", error: e, stackTrace: s);
      state = state.copyWith(
          detailState: ScreenState.error,
          detailErrorMessage: "发生意外错误: $e");
    }
  }

  // Constants for approval actions (map these to what your API expects)
  // Let's assume your API expects the integer codes for status updates directly.
  // If it expects strings like "已审核", "已驳回", you'll need to map them.
  // For example, 0 for "待审批" was a display string, not an action to send.
  // Let's assume for "Approve" you send the code for "已审核" (e.g. 1 if that's the 'Approved' code after audit)
  // and for "Reject" you send code for "已驳回" (99).
  // **THIS NEEDS TO BE VERIFIED WITH YOUR API'S EXPECTATIONS FOR STATUS TRANSITIONS**
  static const int API_STATUS_APPROVED = 1; // Placeholder: Example "Approved" code after audit
  static const int API_STATUS_REJECTED = 99; // This is "已驳回"

  Future<bool> approveOrder(String orderId, String remarks) async {
    // **VERIFY API_STATUS_APPROVED with your actual 'Approved' status code after '待审批'**
    // The statusString "已审核" might correspond to a different integer than what we hardcode here.
    // For this example, I'll use a hypothetical "approved" code.
    // Your backend might have specific transition logic.
    // The `status` field in `SalesOrderEntity` is the current status. The `newStatus` sent to API
    // is the *target* status.
    return _updateOrderStatus(orderId, API_STATUS_APPROVED.toString(), remarks);
  }

  Future<bool> rejectOrder(String orderId, String remarks) async {
    return _updateOrderStatus(orderId, API_STATUS_REJECTED.toString(), remarks);
  }

  Future<bool> _updateOrderStatus(String orderId, String newApiStatusString, String remarks) async {
    state = state.copyWith(approvalState: ScreenState.submitting, approvalMessage: '');
    try {
      await _updateSalesOrderStatusUseCase(
        orderId: orderId,
        newStatus: newApiStatusString, // API UseCase expects a string
        remarks: remarks,
      );
      state = state.copyWith(approvalState: ScreenState.success, approvalMessage: '订单状态更新成功!');

      // Refresh detail and list
      if (state.selectedOrder?.id.toString() == orderId) {
        await fetchOrderDetail(orderId); // Refresh detail
      }
      await fetchOrders( // Refetch with current filters
          orderNumber: state.currentOrderNumberQuery,
          status: state.currentStatusFilterCode
      );
      return true;
    } on DioException catch (e,s) {
      logger.e("Notifier: DioException updating status", error: e, stackTrace: s);
      state = state.copyWith(
          approvalState: ScreenState.error, approvalMessage: "网络错误: ${e.message}");
      return false;
    } catch (e,s) {
      logger.e("Notifier: Exception updating status", error: e, stackTrace: s);
      state = state.copyWith(
          approvalState: ScreenState.error,
          approvalMessage: "发生意外错误: $e");
      return false;
    }
  }

  void resetApprovalStatus() {
    state = state.copyWith(approvalState: ScreenState.initial, approvalMessage: '');
  }
}