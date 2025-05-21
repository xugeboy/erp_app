// lib/features/sales_order/presentation/notifiers/sales_order_state.dart
import 'package:equatable/equatable.dart';
import '../domain/entities/sales_order_entity.dart';

enum ScreenState { initial, loading, loaded, error, submitting, success }

class SalesOrderState extends Equatable {
  // List Page State
  final ScreenState listState;
  final List<SalesOrderEntity> orders;
  final String listErrorMessage;
  final String currentOrderNumberQuery;
  final int? currentStatusFilterCode; // The integer code for filtering

  // Detail Page State
  final ScreenState detailState;
  final SalesOrderEntity? selectedOrder;
  final String detailErrorMessage;

  // Approval Page State
  final ScreenState approvalState;
  final String approvalMessage; // Can be error or success message

  const SalesOrderState({
    this.listState = ScreenState.initial,
    this.orders = const [],
    this.listErrorMessage = '',
    this.currentOrderNumberQuery = '',
    this.currentStatusFilterCode,
    this.detailState = ScreenState.initial,
    this.selectedOrder,
    this.detailErrorMessage = '',
    this.approvalState = ScreenState.initial,
    this.approvalMessage = '',
  });

  // Initial state
  factory SalesOrderState.initial() {
    return const SalesOrderState();
  }

  SalesOrderState copyWith({
    ScreenState? listState,
    List<SalesOrderEntity>? orders,
    String? listErrorMessage,
    String? currentOrderNumberQuery,
    int? currentStatusFilterCode,
    bool clearStatusFilter = false, // Flag to explicitly clear the filter
    ScreenState? detailState,
    SalesOrderEntity? selectedOrder,
    bool clearSelectedOrder = false, // Flag to explicitly clear selectedOrder
    String? detailErrorMessage,
    ScreenState? approvalState,
    String? approvalMessage,
  }) {
    return SalesOrderState(
      listState: listState ?? this.listState,
      orders: orders ?? this.orders,
      listErrorMessage: listErrorMessage ?? this.listErrorMessage,
      currentOrderNumberQuery: currentOrderNumberQuery ?? this.currentOrderNumberQuery,
      currentStatusFilterCode: clearStatusFilter ? null : currentStatusFilterCode ?? this.currentStatusFilterCode,
      detailState: detailState ?? this.detailState,
      selectedOrder: clearSelectedOrder ? null : selectedOrder ?? this.selectedOrder,
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
    detailState,
    selectedOrder,
    detailErrorMessage,
    approvalState,
    approvalMessage,
  ];
}