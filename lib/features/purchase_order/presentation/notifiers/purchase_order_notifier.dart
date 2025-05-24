// lib/features/purchase_order/presentation/notifiers/production_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart'; // To catch DioException specifically

import '../../domain/entities/purchase_order_entity.dart';
import '../../domain/usecases/get_purchase_orders_usecase.dart';
import '../../domain/usecases/get_purchase_order_detail_usecase.dart';
import '../../domain/usecases/update_purchase_order_status_usecase.dart';
import '../../providers/purchase_order_state.dart';
import '../../../../core/utils/logger.dart'; // Your logger

class PurchaseOrderNotifier extends StateNotifier<PurchaseOrderState> {
  final GetPurchaseOrdersUseCase _getPurchaseOrdersUseCase;
  final GetPurchaseOrderDetailUseCase _getPurchaseOrderDetailUseCase;
  final UpdatePurchaseOrderStatusUseCase _updatePurchaseOrderStatusUseCase;

  PurchaseOrderNotifier({
    required GetPurchaseOrdersUseCase getPurchaseOrdersUseCase,
    required GetPurchaseOrderDetailUseCase getPurchaseOrderDetailUseCase,
    required UpdatePurchaseOrderStatusUseCase updatePurchaseOrderStatusUseCase,
  })  : _getPurchaseOrdersUseCase = getPurchaseOrdersUseCase,
        _getPurchaseOrderDetailUseCase = getPurchaseOrderDetailUseCase,
        _updatePurchaseOrderStatusUseCase = updatePurchaseOrderStatusUseCase,
        super(PurchaseOrderState.initial());

  /// Fetches orders. Can be used for initial load, filter changes, or loading more pages.
  ///
  /// - [orderNumber]: Explicitly set the order number query for this fetch.
  /// - [status]: Explicitly set the status code for this fetch.
  /// - [pageNoToFetch]: Explicitly set the page number to fetch.
  /// - [loadFirstPage]: If true, clears existing orders and fetches page 1.
  ///   Used for initial loads, refreshes, or when filters change.
  Future<void> fetchOrders({
    String? orderNumber, // For explicit filter changes
    int? status,        // For explicit filter changes
    required int pageNoToFetch, // Page to fetch
  }) async {
    String queryToUse = orderNumber ?? state.currentOrderNumberQuery;
    int? statusToUse = status;
    bool filtersChanged = (orderNumber != null && orderNumber != state.currentOrderNumberQuery) ||
        (status != state.currentStatusFilterCode); // status can be null

    if (filtersChanged) {
      // If filters changed, we are fetching page 1, so update state accordingly
      state = state.copyWith(
        currentOrderNumberQuery: queryToUse,
        currentStatusFilterCode: statusToUse,
        clearStatusFilter: status == null, // Clear if new status is null
        currentPageNo: 1, // Reset to page 1 on filter change
        orders: [], // Clear old orders
        canLoadMore: true, // Assume can load more with new filters
      );
      pageNoToFetch = 1; // Override to 1 if filters changed
    }


    state = state.copyWith(listState: ScreenState.loading, listErrorMessage: '');
    logger.d(
        "Notifier: Fetching orders. Page: $pageNoToFetch, Query: '$queryToUse', Status Code: $statusToUse");
    try {
      final paginatedOrdersResult = await _getPurchaseOrdersUseCase(
        orderNumberQuery: queryToUse.isEmpty ? null : queryToUse,
        statusFilter: statusToUse,
        pageNo: pageNoToFetch,
        pageSize: state.pageSize,
      );
      final newOrders = paginatedOrdersResult.orders;
      final totalOrdersCount = paginatedOrdersResult.totalCount;
      bool canActuallyLoadMore;
      canActuallyLoadMore = (pageNoToFetch * state.pageSize) < totalOrdersCount;

      state = state.copyWith(
        listState: ScreenState.loaded,
        orders: newOrders,
        currentPageNo: pageNoToFetch,
        canLoadMore: canActuallyLoadMore,
        currentStatusFilterCode: statusToUse,
        listErrorMessage: '',
      );
    } on DioException catch (e, s) {
      logger.e("Notifier: DioException fetching orders for page $pageNoToFetch", error: e, stackTrace: s);
      String errorMessage = "网络错误: ${e.message}";
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'].toString();
      }
      state = state.copyWith(
          listState: ScreenState.error, listErrorMessage: errorMessage, orders: pageNoToFetch == 1 ? [] : state.orders); // Clear orders only if it was a page 1 error
    } catch (e, s) {
      logger.e("Notifier: Exception fetching orders for page $pageNoToFetch", error: e, stackTrace: s);
      state = state.copyWith(
          listState: ScreenState.error,
          listErrorMessage: "发生意外错误: ${e.toString()}",
          orders: pageNoToFetch == 1 ? [] : state.orders);
    }
  }

  void applyOrderNumberFilter(String query) {
    logger.d("Notifier: Applying order number filter: '$query'");
    // Fetch page 1 with the new query and current status filter
    fetchOrders(orderNumber: query, status: state.currentStatusFilterCode, pageNoToFetch: 1);
  }

  void applyStatusFilter(int? statusCode) {
    logger.d("Notifier: Applying status filter: $statusCode");
    // Fetch page 1 with the new status and current order number query
    fetchOrders(orderNumber: state.currentOrderNumberQuery, status: statusCode, pageNoToFetch: 1);
  }

  Future<void> goToNextPage() async {
    if (!state.canLoadMore || state.listState == ScreenState.loading) return;
    logger.d("Notifier: Going to next page. Current: ${state.currentPageNo}");
    await fetchOrders(
        pageNoToFetch: state.currentPageNo + 1,
        // Filters are taken from current state
        orderNumber: state.currentOrderNumberQuery,
        status: state.currentStatusFilterCode
    );
  }

  Future<void> goToPreviousPage() async {
    if (state.currentPageNo <= 1 || state.listState == ScreenState.loading) return;
    logger.d("Notifier: Going to previous page. Current: ${state.currentPageNo}");
    await fetchOrders(
        pageNoToFetch: state.currentPageNo - 1,
        // Filters are taken from current state
        orderNumber: state.currentOrderNumberQuery,
        status: state.currentStatusFilterCode
    );
  }

  Future<void> fetchOrderDetail(int orderId) async {
    state = state.copyWith(detailState: ScreenState.loading, clearSelectedOrder: true, detailErrorMessage: '');
    logger.d("Notifier: Fetching detail for order ID $orderId");
    try {
      final orderData = await _getPurchaseOrderDetailUseCase(orderId);
      state = state.copyWith(
        detailState: ScreenState.loaded,
        selectedOrder: orderData,
        detailErrorMessage: '',
      );
    } on DioException catch (e,s) {
      logger.e("Notifier: DioException fetching order detail for $orderId", error: e, stackTrace: s);
      state = state.copyWith(
          detailState: ScreenState.error, detailErrorMessage: "网络错误: ${e.message}");
    } catch (e,s) {
      logger.e("Notifier: Exception fetching order detail for $orderId", error: e, stackTrace: s);
      state = state.copyWith(
          detailState: ScreenState.error,
          detailErrorMessage: "发生意外错误: ${e.toString()}");
    }
  }

  // **IMPORTANT**: Verify these integer codes with your backend's expected values
  // for status transitions after an approval action.
  // The names here are for clarity; the values are what get sent.
  static const int API_STATUS_APPROVED_AFTER_AUDIT = 1; // Example: "未收款" or your actual "Approved" state
  static const int API_STATUS_REJECTED_AFTER_AUDIT = 99;  // This is "已驳回"

  Future<bool> approveOrder(int orderId) async {
    logger.d("Notifier: Attempting to approve order $orderId");
    return _updateOrderStatus(orderId, API_STATUS_APPROVED_AFTER_AUDIT);
  }

  Future<bool> rejectOrder(int orderId) async {
    logger.d("Notifier: Attempting to reject order $orderId");
    return _updateOrderStatus(orderId, API_STATUS_REJECTED_AFTER_AUDIT);
  }

  Future<bool> _updateOrderStatus(int orderId, int newApiStatus) async {
    state = state.copyWith(approvalState: ScreenState.submitting, approvalMessage: '');
    try {
      await _updatePurchaseOrderStatusUseCase(
        orderId: orderId,
        newStatus: newApiStatus,
      );
      state = state.copyWith(approvalState: ScreenState.success, approvalMessage: '订单状态更新成功!');

      // Refresh relevant data
      if (state.selectedOrder?.id == orderId) {
        await fetchOrderDetail(orderId); // Refresh currently viewed detail
      }
      // Refresh the list with current filters, resetting to page 1
      await fetchOrders(
          orderNumber: state.currentOrderNumberQuery,
          status: state.currentStatusFilterCode,
          pageNoToFetch: 1
      );
      return true;
    } on DioException catch (e,s) {
      logger.e("Notifier: DioException updating status for order $orderId", error: e, stackTrace: s);
      state = state.copyWith(
          approvalState: ScreenState.error, approvalMessage: "网络错误: ${e.message}");
      return false;
    } catch (e,s) {
      logger.e("Notifier: Exception updating status for order $orderId", error: e, stackTrace: s);
      state = state.copyWith(
          approvalState: ScreenState.error,
          approvalMessage: "发生意外错误: ${e.toString()}");
      return false;
    }
  }

  void resetApprovalStatus() {
    state = state.copyWith(approvalState: ScreenState.initial, approvalMessage: '');
  }
}