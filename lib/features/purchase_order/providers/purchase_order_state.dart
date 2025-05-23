// lib/features/purchase_order/presentation/notifiers/purchase_order_state.dart
import 'package:equatable/equatable.dart';
import '../domain/entities/purchase_order_entity.dart';

enum ScreenState { initial, loading, loaded, error, submitting, success, loadingMore } // Added loadingMore

class PurchaseOrderState extends Equatable {
  // List Page State
  final ScreenState listState;
  final List<PurchaseOrderEntity> orders;
  final String listErrorMessage;
  final String currentOrderNumberQuery;
  final int? currentStatusFilterCode;

  // Pagination State
  final int currentPageNo;
  final int pageSize;
  final bool canLoadMore;
  final int? totalOrdersCount; // Optional: if your API returns total count

  // Detail Page State
  final ScreenState detailState;
  final PurchaseOrderEntity? selectedOrder;
  final String detailErrorMessage;

  // Approval Page State
  final ScreenState approvalState;
  final String approvalMessage;

  const PurchaseOrderState({
    this.listState = ScreenState.initial,
    this.orders = const [],
    this.listErrorMessage = '',
    this.currentOrderNumberQuery = '',
    this.currentStatusFilterCode,
    this.currentPageNo = 1, // Default to page 1
    this.pageSize = 10,     // Default page size
    this.canLoadMore = true,  // Assume can load more initially
    this.totalOrdersCount,
    this.detailState = ScreenState.initial,
    this.selectedOrder,
    this.detailErrorMessage = '',
    this.approvalState = ScreenState.initial,
    this.approvalMessage = '',
  });

  factory PurchaseOrderState.initial() {
    return const PurchaseOrderState();
  }

  PurchaseOrderState copyWith({
    ScreenState? listState,
    List<PurchaseOrderEntity>? orders,
    String? listErrorMessage,
    String? currentOrderNumberQuery,
    int? currentStatusFilterCode,
    bool clearStatusFilter = false,
    int? currentPageNo,
    int? pageSize, // Though typically pageSize is constant
    bool? canLoadMore,
    int? totalOrdersCount,
    bool clearTotalOrdersCount = false,
    ScreenState? detailState,
    PurchaseOrderEntity? selectedOrder,
    bool clearSelectedOrder = false,
    String? detailErrorMessage,
    ScreenState? approvalState,
    String? approvalMessage,
  }) {
    return PurchaseOrderState(
      listState: listState ?? this.listState,
      orders: orders ?? this.orders,
      listErrorMessage: listErrorMessage ?? this.listErrorMessage,
      currentOrderNumberQuery:
      currentOrderNumberQuery ?? this.currentOrderNumberQuery,
      currentStatusFilterCode: clearStatusFilter
          ? null
          : currentStatusFilterCode,
      currentPageNo: currentPageNo ?? this.currentPageNo,
      pageSize: pageSize ?? this.pageSize,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      totalOrdersCount: clearTotalOrdersCount ? null : totalOrdersCount ?? this.totalOrdersCount,
      detailState: detailState ?? this.detailState,
      selectedOrder:
      clearSelectedOrder ? null : selectedOrder ?? this.selectedOrder,
      detailErrorMessage: detailErrorMessage ?? this.detailErrorMessage,
      approvalState: approvalState ?? this.approvalState,
      approvalMessage: approvalMessage ?? this.approvalMessage,
    );
  }

  @override
  List<Object?> get props => [
    listState,
    orders,
    listErrorMessage,
    currentOrderNumberQuery,
    currentStatusFilterCode,
    currentPageNo,
    pageSize,
    canLoadMore,
    totalOrdersCount,
    detailState,
    selectedOrder,
    detailErrorMessage,
    approvalState,
    approvalMessage,
  ];
}