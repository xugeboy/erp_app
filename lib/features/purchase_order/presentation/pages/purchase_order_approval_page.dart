// lib/features/purchase_order/presentation/pages/purchase_order_approval_page.dart
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

// Assuming your providers are correctly imported
import '../../domain/entities/purchase_order_entity.dart';
import '../../../../core/utils/logger.dart';
// Corrected import path for purchase_order_providers if it's directly in features/purchase_order/providers
import '../../providers/purchase_order_providers.dart';
import '../../providers/purchase_order_state.dart';
// Corrected import path for purchase_order_state if it's directly in features/purchase_order/providers
// This should be '../notifiers/purchase_order_state.dart' if state is with notifier
// Assuming dioProvider is from your auth setup if it's global
import '../../../auth/providers/auth_provider.dart'; // Or your central dio provider location


enum ApprovalAction { approve, reject }

class PurchaseOrderApprovalPage extends ConsumerStatefulWidget {
  // Changed orderId to int to match your provided code structure
  final int orderId;

  const PurchaseOrderApprovalPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<PurchaseOrderApprovalPage> createState() =>
      _PurchaseOrderApprovalPageState();
}

class _PurchaseOrderApprovalPageState
    extends ConsumerState<PurchaseOrderApprovalPage> {
  final _formKeyInDialog = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  bool _isPdfLoading = false;
  String? _localPdfPath;
  String _pdfLoadingError = '';

  int? _pdfPages = 0;
  int? _pdfCurrentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reset any previous approval messages
      ref.read(purchaseOrderNotifierProvider.notifier).resetApprovalStatus();

      // Attempt to load PDF if order details are already in the notifier's state
      // The main trigger will be the ref.listen below.
      final initialOrder = ref.read(purchaseOrderNotifierProvider).selectedOrder;
      if (initialOrder != null && initialOrder.id == widget.orderId) {
        logger.d("ApprovalPage: Initial order found in state. ID: ${initialOrder.id}. Attempting PDF load.");
        _fetchContractUrlAndDisplayPdf(initialOrder);
      } else {
        logger.w("ApprovalPage: Initial selectedOrder in notifier is null or doesn't match widget.orderId (${widget.orderId}). Waiting for listener or previous page to set it.");
        // Display a message if order is not immediately available (handled in build method)
      }
    });
  }

  // This method remains largely the same, fetching PDF based on order.id
  Future<void> _fetchContractUrlAndDisplayPdf(PurchaseOrderEntity order) async {
    final String pdfMetadataApiUrl =
        'https://erp.xiangletools.store:30443/admin-api/erp/sale-order/exportPdfApp?id=${order.id}';

    logger.d("ApprovalPage: Fetching PDF URL from metadata API: $pdfMetadataApiUrl for order ${order.no}");

    if (!mounted) return;
    setState(() {
      _isPdfLoading = true;
      _pdfLoadingError = '';
      _localPdfPath = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final metaResponse = await dio.get(pdfMetadataApiUrl);

      String? directPdfUrl;
      if (metaResponse.statusCode == 200 && metaResponse.data != null) {
        logger.d("PDF Metadata API Response Data: ${metaResponse.data}");
        if (metaResponse.data is Map<String, dynamic>) {
          final responseData = metaResponse.data as Map<String, dynamic>;
          // CRITICAL: Adjust this to your actual API response structure
          if (responseData.containsKey('data') && responseData['data'] is String) {
            directPdfUrl = responseData['data'] as String?;
          } else if (responseData.containsKey('data') && responseData['data'] is Map) {
            directPdfUrl = responseData['data']?['url'] as String? ?? responseData['data']?['pdfUrl'] as String?;
          }
          else if (responseData.containsKey('url')) {
            directPdfUrl = responseData['url'] as String?;
          }
          else if (responseData.containsKey('pdfUrl')) {
            directPdfUrl = responseData['pdfUrl'] as String?;
          }
          // ... other potential structures
        } else if (metaResponse.data is String) {
          directPdfUrl = metaResponse.data as String;
        }

        if (directPdfUrl == null || directPdfUrl.isEmpty || (!Uri.tryParse(directPdfUrl)!.hasAbsolutePath)) {
          logger.e("Failed to parse a valid PDF URL from metadata API response. Received URL: $directPdfUrl. Full response: ${metaResponse.data}");
          throw Exception("从API获取的PDF链接无效或为空。 ($directPdfUrl)");
        }
        logger.d("ApprovalPage: Received direct PDF URL: $directPdfUrl");
      } else {
        logger.e("PDF Metadata API request failed with status ${metaResponse.statusCode}, data: ${metaResponse.data}");
        throw DioException(
            requestOptions: metaResponse.requestOptions,
            response: metaResponse,
            error: "获取PDF链接API返回状态 ${metaResponse.statusCode}",
            message: "无法从API获取PDF链接。");
      }

      logger.d("ApprovalPage: Downloading PDF from direct URL: $directPdfUrl");
      final dir = await getTemporaryDirectory();
      final fileName = directPdfUrl.split('/').last.split('?').first;
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_]'), '_') + (fileName.toLowerCase().endsWith('.pdf') ? '' : '.pdf');
      final localPath = '${dir.path}/$safeFileName';

      await dio.download(directPdfUrl, localPath);

      if (mounted) {
        setState(() {
          _localPdfPath = localPath;
          _isPdfLoading = false;
        });
        logger.d("PDF downloaded successfully from direct URL to: $localPath");
      }
    } on DioException catch (e, s) {
      logger.e("DioException during PDF URL fetch or download for $pdfMetadataApiUrl", error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          _pdfLoadingError = "获取合同文件失败 (网络): ${e.response?.data?['message'] ?? e.response?.data ?? e.message ?? e.message}";
          _isPdfLoading = false;
        });
      }
    } catch (e, s) {
      logger.e("Unexpected error during PDF URL fetch or download for $pdfMetadataApiUrl", error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          _pdfLoadingError = "获取合同文件时发生意外错误: ${e.toString()}";
          _isPdfLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    if (_localPdfPath != null) {
      try {
        final file = File(_localPdfPath!);
        if (file.existsSync()) {
          file.delete();
          logger.d("Temporary PDF file deleted: $_localPdfPath");
        }
      } catch (e) {
        logger.w("Could not delete temporary PDF: $_localPdfPath", error: e);
      }
    }
    super.dispose();
  }

  void _showApprovalDialog(BuildContext context, ApprovalAction action, PurchaseOrderEntity order) {
    _remarksController.clear();
    final notifier = ref.read(purchaseOrderNotifierProvider.notifier);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(action == ApprovalAction.approve ? '确认审核通过' : '驳回订单'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKeyInDialog,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('订单号: ${order.no}'), // Display order number for context
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text(action == ApprovalAction.approve ? '确认通过' : '确认驳回'),
              style: ElevatedButton.styleFrom(
                backgroundColor: action == ApprovalAction.approve ? Colors.green : Colors.red,
              ),
              onPressed: () async {
                if (_formKeyInDialog.currentState!.validate()) {
                  final remarks = _remarksController.text.trim();
                  Navigator.of(dialogContext).pop();

                  if (action == ApprovalAction.approve) {
                    // Pass order.id instead of widget.orderId if they are different types
                    await notifier.approveOrder(order.id);
                  } else {
                    await notifier.rejectOrder(order.id);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final purchaseOrderState = ref.watch(purchaseOrderNotifierProvider);
    // Get the order that should have been selected by the previous page
    final PurchaseOrderEntity? order =
    (purchaseOrderState.selectedOrder?.id == widget.orderId)
        ? purchaseOrderState.selectedOrder
        : null;

    // Listener for selectedOrder changes to trigger PDF load if not already done
    ref.listen<PurchaseOrderEntity?>(
      purchaseOrderNotifierProvider.select((s) => s.selectedOrder),
          (previousOrder, newOrder) {
        if (newOrder != null && newOrder.id == widget.orderId) {
          // Check if PDF needs to be loaded
          if (!_isPdfLoading && _localPdfPath == null && _pdfLoadingError.isEmpty) {
            logger.d("Listener: selectedOrder updated for ID ${newOrder.id}. Attempting to fetch PDF URL via API.");
            _fetchContractUrlAndDisplayPdf(newOrder);
          }
        }
      },
    );

    // Listener for approval state changes (for SnackBar and navigation)
    ref.listen<PurchaseOrderState>(purchaseOrderNotifierProvider, (previous, next) {
      if (previous?.approvalState != next.approvalState) {
        if (next.approvalState == ScreenState.success) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(next.approvalMessage.isNotEmpty ? next.approvalMessage : '操作成功!'),
                backgroundColor: Colors.green),
          );
          int popCount = 0;
          Navigator.of(context).popUntil((route) {
            popCount++;
            // Example: Pop twice if coming from Detail -> Approval to go back to List
            // This needs to be robust based on your actual navigation stack
            return popCount == 2;
          });
        } else if (next.approvalState == ScreenState.error) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(next.approvalMessage.isNotEmpty ? next.approvalMessage : '操作失败。'),
                backgroundColor: Colors.red),
          );
        }
      }
    });

    Widget bodyContent;

    if (order == null) {
      // If order details are not available (e.g., not set by previous page or doesn't match ID)
      // This state should ideally be brief if the listener picks up the correct selectedOrder.
      // If purchaseOrderState.detailState reflects an error FOR THIS orderId from a previous attempt, show it.
      if (purchaseOrderState.detailState == ScreenState.loading && purchaseOrderState.selectedOrder?.id != widget.orderId) {
        bodyContent = const Center(child: CircularProgressIndicator(semanticsLabel: '等待订单信息...'));
      } else if (purchaseOrderState.detailState == ScreenState.error && purchaseOrderState.selectedOrder?.id != widget.orderId) {
        bodyContent = Center(child: Text("加载订单信息时出错: ${purchaseOrderState.detailErrorMessage}"));
      }
      else {
        bodyContent = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 48),
              SizedBox(height: 16),
              Text('订单信息不可用或不匹配。\n请确保从订单详情页正确导航。', textAlign: TextAlign.center),
            ],
          ),
        );
      }
    } else { // Order is available, proceed with PDF display logic
      if (_isPdfLoading) {
        bodyContent = const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(semanticsLabel: '加载合同中...'),
            SizedBox(height: 16),
            Text("加载合同中，请稍候...")
          ],
        ));
      } else if (_pdfLoadingError.isNotEmpty) {
        bodyContent = Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 48),
                  const SizedBox(height:10),
                  const Text("加载合同PDF失败", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height:10),
                  Text(_pdfLoadingError, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center,),
                  const SizedBox(height:10),
                  ElevatedButton(onPressed: (){
                    _fetchContractUrlAndDisplayPdf(order); // Retry fetching
                  }, child: const Text("重试加载PDF"))
                ]),
          ),
        );
      } else if (_localPdfPath != null) {
        bodyContent = PDFView(
          filePath: _localPdfPath!,
          enableSwipe: true, swipeHorizontal: false, autoSpacing: false,
          pageFling: true, pageSnap: true, defaultPage: _pdfCurrentPage ?? 0,
          fitPolicy: FitPolicy.BOTH, preventLinkNavigation: false,
          onRender: (pages) { if (mounted) setState(() => _pdfPages = pages); },
          onError: (error) { if (mounted) setState(() => _pdfLoadingError = "显示PDF时发生错误: $error"); },
          onPageError: (page, error) { if (mounted) setState(() => _pdfLoadingError = '显示第 $page 页时发生错误: $error'); },
          onPageChanged: (int? page, int? total) { if (mounted && page != null) setState(() => _pdfCurrentPage = page); },
        );
      } else {
        bodyContent = const Center(child: Text("没有合同文件可供预览，或未能获取链接。"));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order != null ? '审批订单: ${order.no}' : '订单审批'),
        actions: order == null || purchaseOrderState.approvalState == ScreenState.submitting || _isPdfLoading
            ? []
            : <Widget>[
          TextButton(
            onPressed: () => _showApprovalDialog(context, ApprovalAction.reject, order), // Pass the loaded order
            child: const Text('驳回', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showApprovalDialog(context, ApprovalAction.approve, order), // Pass the loaded order
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('确认审核通过', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: _localPdfPath != null && !_isPdfLoading && _pdfLoadingError.isEmpty && _pdfPages != null && _pdfPages! > 0
          ? Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.black.withOpacity(0.1),
          child: Text( '页码: ${_pdfCurrentPage! + 1}/$_pdfPages',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))
          : null,
    );
  }
}