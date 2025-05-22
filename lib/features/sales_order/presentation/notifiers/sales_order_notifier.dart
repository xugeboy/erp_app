// lib/features/sales_order/presentation/notifiers/sales_order_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart'; // To catch DioException specifically

import '../../domain/entities/sales_order_entity.dart';
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

  /// Fetches orders. Can be used for initial load, filter changes, or loading more pages.
  ///
  /// - [orderNumber]: Explicitly set the order number query for this fetch.
  /// - [status]: Explicitly set the status code for this fetch.
  /// - [pageNoToFetch]: Explicitly set the page number to fetch.
  /// - [loadFirstPage]: If true, clears existing orders and fetches page 1.
  ///   Used for initial loads, refreshes, or when filters change.
  Future<void> fetchOrders({
    String? orderNumber,
    int? status, // Nullable int for status code
    int? pageNoToFetch,
    bool loadFirstPage = false,
  }) async {
    int pageToFetch;
    List<SalesOrderEntity> currentOrders = state.orders;

    if (loadFirstPage) {
      pageToFetch = 1;
      currentOrders = []; // Clear orders for a fresh load/filter
      state = state.copyWith(
        listState: ScreenState.loading,
        orders: currentOrders,
        currentPageNo: pageToFetch,
        canLoadMore: true, // Assume can load more when starting fresh
        listErrorMessage: '',
        currentOrderNumberQuery: orderNumber ?? state.currentOrderNumberQuery, // Use new or existing
        currentStatusFilterCode: status, // Use new status, allow null for "All"
        clearStatusFilter: status == null && orderNumber == null, // Logic for clearing
      );
    } else {
      pageToFetch = pageNoToFetch ?? state.currentPageNo;
      if (pageToFetch > state.currentPageNo && state.listState != ScreenState.loadingMore) { // Loading more
        state = state.copyWith(listState: ScreenState.loadingMore);
      } else if (pageToFetch == 1 && currentOrders.isEmpty) { // Initial page 1 load
        state = state.copyWith(listState: ScreenState.loading);
      }
      // Persist filters if only pageNo is changing
      if (orderNumber != null) state = state.copyWith(currentOrderNumberQuery: orderNumber);
      if (status != null || (orderNumber == null && pageNoToFetch == null)) {
        // If status is explicitly passed, or if no other params are passed (implying a general refresh),
        // update/clear the status filter.
        state = state.copyWith(currentStatusFilterCode: status, clearStatusFilter: status == null);
      }
    }

    // Use the most up-to-date filter values from the state for the API call
    final String queryToUse = state.currentOrderNumberQuery;
    final int? statusToUse = state.currentStatusFilterCode;

    logger.d(
        "Notifier: Fetching orders. Page: $pageToFetch, Query: '$queryToUse', Status Code: $statusToUse");

    try {
      final newOrders = await _getSalesOrdersUseCase(
        orderNumberQuery: queryToUse.isEmpty ? null : queryToUse,
        statusFilter: statusToUse, // Pass int? directly
        pageNo: pageToFetch,
        pageSize: state.pageSize,
      );

      state = state.copyWith(
        listState: ScreenState.loaded,
        orders: loadFirstPage ? newOrders : [...currentOrders, ...newOrders],
        currentPageNo: pageToFetch,
        canLoadMore: newOrders.length == state.pageSize,
        listErrorMessage: '',
      );
    } on DioException catch (e, s) {
      logger.e("Notifier: DioException fetching orders for page $pageToFetch", error: e, stackTrace: s);
      String errorMessage = "网络错误: ${e.message}";
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'].toString();
      }
      state = state.copyWith(
          listState: ScreenState.error, listErrorMessage: errorMessage, canLoadMore: (pageToFetch > 1)); // Keep canLoadMore if it was a subsequent page load error
    } catch (e, s) {
      logger.e("Notifier: Exception fetching orders for page $pageToFetch", error: e, stackTrace: s);
      state = state.copyWith(
          listState: ScreenState.error,
          listErrorMessage: "发生意外错误: ${e.toString()}",
          canLoadMore: (pageToFetch > 1));
    }
  }

  void applyOrderNumberFilter(String query) {
    logger.d("Notifier: Applying order number filter: '$query'");
    // Will set currentOrderNumberQuery in state and fetch page 1
    fetchOrders(orderNumber: query, status: state.currentStatusFilterCode, loadFirstPage: true);
  }

  void applyStatusFilter(int? statusCode) {
    logger.d("Notifier: Applying status filter: $statusCode");
    // Will set currentStatusFilterCode in state and fetch page 1
    fetchOrders(orderNumber: state.currentOrderNumberQuery, status: statusCode, loadFirstPage: true);
  }

  Future<void> loadMoreOrders() async {
    if (state.listState == ScreenState.loadingMore || !state.canLoadMore) {
      logger.d(
          "Notifier: Load more skipped. State: ${state.listState}, CanLoadMore: ${state.canLoadMore}");
      return;
    }
    logger.d(
        "Notifier: Loading more orders. Current page: ${state.currentPageNo}, Attempting page: ${state.currentPageNo + 1}");
    // Fetch orders for the next page, preserving current filters
    await fetchOrders(
        orderNumber: state.currentOrderNumberQuery,
        status: state.currentStatusFilterCode,
        pageNoToFetch: state.currentPageNo + 1
    );
  }

  Future<void> fetchOrderDetail(int orderId) async {
    state = state.copyWith(detailState: ScreenState.loading, clearSelectedOrder: true, detailErrorMessage: '');
    logger.d("Notifier: Fetching detail for order ID $orderId");
    try {
      final orderData = await _getSalesOrderDetailUseCase(orderId);
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
      await _updateSalesOrderStatusUseCase(
        orderId: orderId,
        newStatus: newApiStatus,
      );
      state = state.copyWith(approvalState: ScreenState.success, approvalMessage: '订单状态更新成功!');

      // Refresh relevant data
      if (state.selectedOrder?.id.toString() == orderId) {
        await fetchOrderDetail(orderId); // Refresh currently viewed detail
      }
      // Refresh the list with current filters, resetting to page 1
      await fetchOrders(
          orderNumber: state.currentOrderNumberQuery,
          status: state.currentStatusFilterCode,
          loadFirstPage: true
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