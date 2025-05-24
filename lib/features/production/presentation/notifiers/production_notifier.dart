// lib/features/production_order/presentation/notifiers/production_notifier.dart
import 'dart:io'; // 用于 File 类型
import 'package:erp_app/features/production/domain/entities/production_entity.dart';
import 'package:erp_app/features/purchase_order/data/models/purchase_order_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../domain/usecases/get_production_usecase.dart';
import '../../domain/usecases/get_related_purchase_orders_usecase.dart';
import '../../domain/usecases/upload_shipment_image_usecase.dart';
import '../../providers/production_state.dart';
import '../../../../core/utils/logger.dart';

class ProductionNotifier extends StateNotifier<ProductionState> {
  final GetProductionsUseCase _getProductionsUseCase;
  final UploadShipmentImageUseCase? _uploadShipmentImageUseCase;
  final GetRelatedPurchaseOrdersUseCase? _getRelatedPurchaseOrdersUseCase;

  ProductionNotifier({
    required GetProductionsUseCase getProductionsUseCase,
    UploadShipmentImageUseCase? uploadShipmentImageUseCase,
    GetRelatedPurchaseOrdersUseCase? getRelatedPurchaseOrdersUseCase,
  })  : _getProductionsUseCase = getProductionsUseCase,
        _uploadShipmentImageUseCase = uploadShipmentImageUseCase,
        _getRelatedPurchaseOrdersUseCase = getRelatedPurchaseOrdersUseCase,
        super(ProductionState.initial());

  // --- 列表获取、筛选、分页逻辑 (与之前类似，假设分页和筛选对生产单列表适用) ---
  Future<void> fetchOrders({
    String? orderNumber,
    int? status,
    required int pageNoToFetch,
  }) async {
    String queryToUse = orderNumber ?? state.currentOrderNumberQuery;
    int? statusToUse = status ?? state.currentStatusFilterCode;
    bool filtersChanged = (orderNumber != null && orderNumber != state.currentOrderNumberQuery) ||
        (status != state.currentStatusFilterCode);

    if (filtersChanged) {
      pageNoToFetch = 1;
      state = state.copyWith(
        listState: ScreenState.loading,
        orders: [], // 清空订单
        currentPageNo: 1,
        canLoadMore: true,
        listErrorMessage: '',
        currentOrderNumberQuery: queryToUse,
        currentStatusFilterCode: statusToUse,
        clearStatusFilter: statusToUse == null,
      );
    } else {
      // 翻页
      state = state.copyWith(listState: ScreenState.loadingMore, listErrorMessage: '');
    }

    logger.d(
        "ProductionNotifier: Fetching production orders. Page: $pageNoToFetch, Query: '$queryToUse', Status Code: $statusToUse");
    try {
      final paginatedResult = await _getProductionsUseCase(
        orderNumberQuery: queryToUse.isEmpty ? null : queryToUse,
        statusFilter: statusToUse,
        pageNo: pageNoToFetch,
        pageSize: state.pageSize,
      );
      final newOrders = paginatedResult.orders; // 假设 paginatedResult.orders 是 List<ProductionEntity>
      final totalOrdersCount = paginatedResult.totalCount;

      bool canActuallyLoadMore;
      if (totalOrdersCount > 0) {
        canActuallyLoadMore = (pageNoToFetch * state.pageSize) < totalOrdersCount;
      } else if (totalOrdersCount == 0) {
        canActuallyLoadMore = false;
      } else {
        canActuallyLoadMore = newOrders.length == state.pageSize;
      }

      state = state.copyWith(
        listState: ScreenState.loaded,
        orders: newOrders,
        currentPageNo: pageNoToFetch,
        canLoadMore: canActuallyLoadMore,
        listErrorMessage: '',
      );
    } on DioException catch (e, s) {
      logger.e("ProductionNotifier: DioException fetching production orders page $pageNoToFetch", error: e, stackTrace: s);
      state = state.copyWith(
          listState: ScreenState.error, listErrorMessage: "网络错误: ${e.message}", canLoadMore: false);
    } catch (e, s) {
      logger.e("ProductionNotifier: Exception fetching production orders page $pageNoToFetch", error: e, stackTrace: s);
      state = state.copyWith(
          listState: ScreenState.error, listErrorMessage: "发生意外错误: ${e.toString()}", canLoadMore: false);
    }
  }

  void applyOrderNumberFilter(String query) {
    logger.d("ProductionNotifier: Applying order number filter: '$query'");
    fetchOrders(orderNumber: query, status: state.currentStatusFilterCode, pageNoToFetch: 1);
  }

  void applyStatusFilter(int? statusCode) {
    logger.d("ProductionNotifier: Applying status filter: $statusCode");
    fetchOrders(orderNumber: state.currentOrderNumberQuery, status: statusCode, pageNoToFetch: 1);
  }

  Future<void> goToNextPage() async { // 如果您使用上一页/下一页按钮
    if (!state.canLoadMore || state.listState == ScreenState.loading) return;
    logger.d("ProductionNotifier: Going to next page. Current: ${state.currentPageNo}");
    await fetchOrders( // 这里的 fetchOrders 应该替换列表，而不是追加
        pageNoToFetch: state.currentPageNo + 1,
        orderNumber: state.currentOrderNumberQuery,
        status: state.currentStatusFilterCode,
    );
  }

  Future<void> goToPreviousPage() async { // 如果您使用上一页/下一页按钮
    if (state.currentPageNo <= 1 || state.listState == ScreenState.loading) return;
    logger.d("ProductionNotifier: Going to previous page. Current: ${state.currentPageNo}");
    await fetchOrders( // 这里的 fetchOrders 应该替换列表
        pageNoToFetch: state.currentPageNo - 1,
        orderNumber: state.currentOrderNumberQuery,
        status: state.currentStatusFilterCode,
    );
  }

// --- 新增：上传出货图逻辑 ---
Future<bool> uploadShipmentImage(int productionOrderId, File imageFile) async {
  if (_uploadShipmentImageUseCase == null) {
    logger.e("UploadShipmentImageUseCase not provided to ProductionNotifier.");
    state = state.copyWith(imageUploadState: ScreenState.error, imageUploadMessage: "内部错误: 图片上传服务未配置"); // 假设 ProductionState 有这些字段
    return false;
  }
  state = state.copyWith(imageUploadState: ScreenState.submitting, imageUploadMessage: '');
  logger.d("ProductionNotifier: Uploading shipment image for production order ID $productionOrderId");

  try {
    // UploadShipmentImageUseCase 可能返回图片的 URL 或确认信息
    final String imageUrl = await _uploadShipmentImageUseCase(
      productionOrderId: productionOrderId,
      imageFile: imageFile,
    );

    state = state.copyWith(imageUploadState: ScreenState.success, imageUploadMessage: '图片上传成功！URL: $imageUrl');
    return true;
  } on DioException catch (e,s) {
    logger.e("ProductionNotifier: DioException uploading image for $productionOrderId", error: e, stackTrace: s);
    state = state.copyWith(
        imageUploadState: ScreenState.error, imageUploadMessage: "图片上传网络错误: ${e.message}");
    return false;
  } catch (e,s) {
    logger.e("ProductionNotifier: Exception uploading image for $productionOrderId", error: e, stackTrace: s);
    state = state.copyWith(
        imageUploadState: ScreenState.error,
        imageUploadMessage: "图片上传意外错误: ${e.toString()}");
    return false;
  }
}

void resetImageUploadStatus() {
  state = state.copyWith(imageUploadState: ScreenState.initial, imageUploadMessage: '');
}

// --- 完成 fetchRelatedPurchaseOrders 方法 ---
  Future<void> fetchRelatedPurchaseOrders(String productionNo) async {
    if (_getRelatedPurchaseOrdersUseCase == null) {
      logger.e("GetRelatedPurchaseOrdersUseCase not provided to ProductionNotifier.");
      state = state.copyWith(
          relatedPurchaseOrdersState: ScreenState.error,
          relatedPurchaseOrdersErrorMessage: "内部错误: 服务未配置");
      return;
    }
    // 进入加载状态前，先清空旧数据和错误信息
    state = state.copyWith(
        relatedPurchaseOrdersState: ScreenState.loading,
        relatedPurchaseOrders: [], // 清空列表
        relatedPurchaseOrdersErrorMessage: ''
    );
    logger.d("ProductionNotifier: Fetching related purchase orders for production order $productionNo");

    try {
      // 调用 UseCase 获取关联的采购订单摘要列表
      final List<PurchaseOrderModel> relatedPOs = await _getRelatedPurchaseOrdersUseCase(productionNo:productionNo);

      state = state.copyWith(
        relatedPurchaseOrdersState: ScreenState.loaded,
        relatedPurchaseOrders: relatedPOs,
        relatedPurchaseOrdersErrorMessage: '', // 清除之前的错误信息
      );
      logger.d("ProductionNotifier: Successfully fetched ${relatedPOs.length} related purchase orders.");
    } on DioException catch (e,s) {
      logger.e("ProductionNotifier: DioException fetching related POs for $productionNo", error: e, stackTrace: s);
      String errorMessage = "网络错误: ${e.message}";
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        errorMessage = e.response!.data['message'].toString();
      }
      state = state.copyWith(
          relatedPurchaseOrdersState: ScreenState.error,
          relatedPurchaseOrdersErrorMessage: errorMessage);
    } catch (e,s) {
      logger.e("ProductionNotifier: Exception fetching related POs for $productionNo", error: e, stackTrace: s);
      state = state.copyWith(
          relatedPurchaseOrdersState: ScreenState.error,
          relatedPurchaseOrdersErrorMessage: "获取关联采购订单失败: ${e.toString()}");
    }
  }

  void setCurrentlySelectedOrder(ProductionEntity order) {
    logger.d("ProductionNotifier: Setting currently selected production order: ID ${order.id}, No: ${order.no}");
    state = state.copyWith(
      selectedOrder: order,
      detailState: ScreenState.loaded,
      detailErrorMessage: '',
      relatedPurchaseOrders: [],
      relatedPurchaseOrdersState: ScreenState.initial,
      relatedPurchaseOrdersErrorMessage: '',
    );
  }
}
