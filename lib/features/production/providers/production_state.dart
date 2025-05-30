// lib/features/purchase_order/presentation/notifiers/production_state.dart
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:erp_app/features/purchase_order/domain/entities/purchase_order_entity.dart';
import '../domain/entities/production_entity.dart';

enum ScreenState { initial, loading, loaded, error, submitting, success, loadingMore } // Added loadingMore

class ProductionState extends Equatable {
  // List Page State
  final ScreenState listState;
  final List<ProductionEntity> orders;
  final String listErrorMessage;
  final String currentOrderNumberQuery;
  final int? currentStatusFilterCode;

  // Pagination State
  final int currentPageNo;
  final int pageSize;
  final bool canLoadMore;

  // Detail Page State
  final ScreenState detailState;
  final ProductionEntity? selectedOrder;
  final String detailErrorMessage;

  // Approval Page State
  final ScreenState approvalState;
  final String approvalMessage;

  final ScreenState imageUploadState;
  final String imageUploadMessage;

  final List<PurchaseOrderEntity> relatedPurchaseOrders;
  final ScreenState relatedPurchaseOrdersState;
  final String relatedPurchaseOrdersErrorMessage;

  final List<Uint8List> shipmentImages; // 存储解压后的图片字节数据
  final ScreenState shipmentImagesState;
  final String shipmentImagesErrorMessage;

  const ProductionState({
    this.listState = ScreenState.initial,
    this.orders = const [],
    this.listErrorMessage = '',
    this.currentOrderNumberQuery = '',
    this.currentStatusFilterCode,
    this.currentPageNo = 1, // Default to page 1
    this.pageSize = 10,     // Default page size
    this.canLoadMore = true,
    this.detailState = ScreenState.initial,
    this.selectedOrder,
    this.detailErrorMessage = '',
    this.approvalState = ScreenState.initial,
    this.approvalMessage = '',
    this.imageUploadState = ScreenState.initial,
    this.imageUploadMessage = '',

    this.relatedPurchaseOrders = const [],
    this.relatedPurchaseOrdersState = ScreenState.initial,
    this.relatedPurchaseOrdersErrorMessage = '',

    this.shipmentImages = const [], // 初始化
    this.shipmentImagesState = ScreenState.initial, // 初始化
    this.shipmentImagesErrorMessage = '', // 初始化
  });

  factory ProductionState.initial() {
    return const ProductionState();
  }

  ProductionState copyWith({
    ScreenState? listState,
    List<ProductionEntity>? orders,
    String? listErrorMessage,
    String? currentOrderNumberQuery,
    int? currentStatusFilterCode,
    bool clearStatusFilter = false,
    int? currentPageNo,
    int? pageSize, // Though typically pageSize is constant
    bool? canLoadMore,
    bool clearTotalOrdersCount = false,
    ScreenState? detailState,
    ProductionEntity? selectedOrder,
    bool clearSelectedOrder = false,
    String? detailErrorMessage,
    ScreenState? approvalState,
    String? approvalMessage,
    ScreenState? imageUploadState,
    String? imageUploadMessage,
    List<PurchaseOrderEntity>? relatedPurchaseOrders,
    ScreenState? relatedPurchaseOrdersState,
    String? relatedPurchaseOrdersErrorMessage,
    List<Uint8List>? shipmentImages,
    ScreenState? shipmentImagesState,
    String? shipmentImagesErrorMessage,
  }) {
    return ProductionState(
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
      detailState: detailState ?? this.detailState,
      selectedOrder:
      clearSelectedOrder ? null : selectedOrder ?? this.selectedOrder,
      detailErrorMessage: detailErrorMessage ?? this.detailErrorMessage,
      approvalState: approvalState ?? this.approvalState,
      approvalMessage: approvalMessage ?? this.approvalMessage,
      imageUploadState: imageUploadState ?? this.imageUploadState,
      imageUploadMessage: imageUploadMessage ?? this.imageUploadMessage,
      relatedPurchaseOrders: relatedPurchaseOrders ?? this.relatedPurchaseOrders,
      relatedPurchaseOrdersState: relatedPurchaseOrdersState ?? this.relatedPurchaseOrdersState,
      relatedPurchaseOrdersErrorMessage: relatedPurchaseOrdersErrorMessage ?? this.relatedPurchaseOrdersErrorMessage,
      shipmentImages: shipmentImages ?? this.shipmentImages,
      shipmentImagesState: shipmentImagesState ?? this.shipmentImagesState,
      shipmentImagesErrorMessage: shipmentImagesErrorMessage ?? this.shipmentImagesErrorMessage,
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
    detailState,
    selectedOrder,
    detailErrorMessage,
    approvalState,
    approvalMessage,
    relatedPurchaseOrders,
    relatedPurchaseOrdersState,
    relatedPurchaseOrdersErrorMessage,
    shipmentImages,
    shipmentImagesState,
    shipmentImagesErrorMessage,
  ];
}