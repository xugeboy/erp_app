// lib/features/sales_order/presentation/pages/sales_order_approval_page.dart
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/sales_order_entity.dart';
import '../../../../core/utils/logger.dart';
import '../../providers/sales_order_providers.dart';
import '../../providers/sales_order_state.dart';

enum ApprovalAction { approve, reject }

class SalesOrderApprovalPage extends ConsumerStatefulWidget {
  final String orderId;

  const SalesOrderApprovalPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<SalesOrderApprovalPage> createState() =>
      _SalesOrderApprovalPageState();
}

class _SalesOrderApprovalPageState
    extends ConsumerState<SalesOrderApprovalPage> {
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
      _initializePage();
    });
  }

  Future<void> _initializePage() async {
    final notifier = ref.read(salesOrderNotifierProvider.notifier);
    final currentState = ref.read(salesOrderNotifierProvider);
    notifier.resetApprovalStatus();

    if (currentState.selectedOrder == null ||
        currentState.selectedOrder!.id.toString() != widget.orderId ||
        currentState.detailState != ScreenState.loaded) {
      logger.d("ApprovalPage: Order details not available/mismatch. Fetching for ${widget.orderId}");
      await notifier.fetchOrderDetail(widget.orderId);
      // PDF load will be triggered by the ref.listen on selectedOrder
    } else {
      final order = currentState.selectedOrder!;
      if (order.contractFile.isNotEmpty) { // Assuming contractFile holds an identifier for the meta-API
        _fetchPdfUrlAndDownload(order);
      } else {
        if (mounted) {
          setState(() { _pdfLoadingError = "此订单没有合同文件标识。"; });
        }
      }
    }
  }

  Future<void> _fetchPdfUrlAndDownload(SalesOrderEntity order) async {
    final String pdfMetaApiUrl =
        'https://erp.xiangletools.store:30443/admin-api/exportPdfApp?id=${order.id}';

    logger.d("ApprovalPage: Fetching PDF metadata from API: $pdfMetaApiUrl for order ${order.no}");

    if (mounted) {
      setState(() {
        _isPdfLoading = true;
        _pdfLoadingError = '';
        _localPdfPath = null;
      });
    }

    try {
      final dio = ref.read(dioProvider);
      final metaResponse = await dio.get(
        pdfMetaApiUrl,
        // Add headers if this meta-API call is protected
        // options: Options(headers: {'Authorization': 'Bearer YOUR_TOKEN'}),
      );

      String? directPdfUrl;
      if (metaResponse.statusCode == 200 && metaResponse.data != null) {
        // **IMPORTANT: Adjust this parsing based on your meta-API's response structure**
        if (metaResponse.data is Map<String, dynamic>) {
          // Example 1: { "data": { "pdfUrl": "..." } }
          directPdfUrl = metaResponse.data?['data']?['pdfUrl'] as String?;
          if (directPdfUrl == null) {
            // Example 2: { "url": "..." }
            directPdfUrl = metaResponse.data?['url'] as String?;
          }
          // Add more parsing logic if your structure is different
        } else if (metaResponse.data is String) {
          // If the API returns the URL as plain text
          directPdfUrl = metaResponse.data as String;
        }

        if (directPdfUrl == null || directPdfUrl.isEmpty || (!Uri.tryParse(directPdfUrl)?.hasAbsolutePath ?? true) ) {
          throw Exception("从API获取的PDF链接无效或为空: $directPdfUrl");
        }
        logger.d("ApprovalPage: Received direct PDF URL: $directPdfUrl");

      } else {
        throw DioException(
            requestOptions: metaResponse.requestOptions,
            response: metaResponse,
            error: "获取PDF链接API返回状态 ${metaResponse.statusCode}",
            message: "无法从API获取PDF链接。"
        );
      }

      // **STEP 2: Download the PDF from the direct URL**
      logger.d("ApprovalPage: Downloading PDF from direct URL: $directPdfUrl");
      final dir = await getTemporaryDirectory();
      final fileName = directPdfUrl.split('/').last.split('?').first;
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_]'), '_') + (fileName.toLowerCase().endsWith('.pdf') ? '' : '.pdf');
      final localPath = '${dir.path}/$safeFileName';

      await dio.download(directPdfUrl, localPath); // dio.download handles byte stream internally

      if (mounted) {
        setState(() {
          _localPdfPath = localPath;
          _isPdfLoading = false;
          logger.d("PDF downloaded successfully: $localPath");
        });
      }

    } on DioException catch (e, s) {
      logger.e("Error during PDF fetch/download process for $pdfMetaApiUrl", error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          _pdfLoadingError = "获取合同文件失败 (API/Download): ${e.response?.data ?? e.message}";
          _isPdfLoading = false;
        });
      }
    } catch (e, s) {
      logger.e("Unexpected error during PDF fetch/download for $pdfMetaApiUrl", error: e, stackTrace: s);
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

  void _showApprovalDialog(BuildContext context, ApprovalAction action, SalesOrderEntity order) {
    _remarksController.clear();
    final notifier = ref.read(salesOrderNotifierProvider.notifier);

    showDialog( /* ... Same as previous version ... */
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
                  Text('订单号: ${order.no}'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _remarksController,
                    decoration: InputDecoration(
                      labelText: '备注',
                      hintText: action == ApprovalAction.reject ? '驳回时备注必填' : '请输入备注 (可选)',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (action == ApprovalAction.reject &&
                          (value == null || value.trim().isEmpty)) {
                        return '驳回订单时，备注不能为空。';
                      }
                      return null;
                    },
                  ),
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

                  bool success = false;
                  if (action == ApprovalAction.approve) {
                    success = await notifier.approveOrder(widget.orderId, remarks);
                  } else {
                    success = await notifier.rejectOrder(widget.orderId, remarks);
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
    final salesOrderState = ref.watch(salesOrderNotifierProvider);
    final SalesOrderEntity? order =
    salesOrderState.selectedOrder?.id.toString() == widget.orderId
        ? salesOrderState.selectedOrder
        : null;

    // Listener to trigger PDF load when order details become available or change
    ref.listen<SalesOrderEntity?>(
      salesOrderNotifierProvider.select((s) => s.selectedOrder),
          (previousOrder, newOrder) {
        if (newOrder != null && newOrder.id.toString() == widget.orderId) {
          if (newOrder.contractFile.isNotEmpty) { // Assuming contractFile is still the identifier for the meta-API
            if (!_isPdfLoading && _localPdfPath == null && _pdfLoadingError.isEmpty) {
              logger.d("Order details available/updated, contractFile identifier: '${newOrder.contractFile}'. Attempting to fetch PDF URL and download for order ${newOrder.no}");
              _fetchPdfUrlAndDownload(newOrder);
            }
          } else {
            if(mounted) {
              setState(() {
                _pdfLoadingError = "此订单没有合同文件标识。";
                _localPdfPath = null;
                _isPdfLoading = false;
              });
            }
          }
        }
      },
    );

    // Listener for approval state changes (for SnackBar and navigation)
    ref.listen<SalesOrderState>(salesOrderNotifierProvider, (previous, next) {
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
            bool fromDetailPage = ModalRoute.of(context)?.settings.name == '/sales_order_detail';
            return popCount == (fromDetailPage ? 2 : 1);
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

    if (salesOrderState.detailState == ScreenState.loading && order == null) {
      bodyContent = const Center(child: CircularProgressIndicator(semanticsLabel: '加载订单信息...'));
    } else if (order == null) {
      bodyContent = Center( /* ... Error UI for order loading (same as before) ... */
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                  salesOrderState.detailErrorMessage.isNotEmpty
                      ? '加载订单信息失败: ${salesOrderState.detailErrorMessage}'
                      : '无法加载订单信息。',
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => ref.read(salesOrderNotifierProvider.notifier).fetchOrderDetail(widget.orderId),
                child: const Text('重试加载订单'),
              )
            ],
          ),
        ),
      );
    } else { // Order is loaded
      if (_isPdfLoading) {
        bodyContent = const Center(child: Column( /* ... Loading PDF UI (same as before) ... */
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(semanticsLabel: '加载合同中...'),
            SizedBox(height: 16),
            Text("加载合同中，请稍候...")
          ],
        ));
      } else if (_pdfLoadingError.isNotEmpty) {
        bodyContent = Center( /* ... PDF Error UI (same as before) ... */
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
                    if (order.contractFile.isNotEmpty) {
                      _fetchPdfUrlAndDownload(order);
                    } else {
                      ref.read(salesOrderNotifierProvider.notifier).fetchOrderDetail(widget.orderId);
                    }
                  }, child: const Text("重试加载PDF"))
                ]),
          ),
        );
      } else if (_localPdfPath != null) {
        bodyContent = PDFView( /* ... PDFView setup (same as before) ... */
          filePath: _localPdfPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: false,
          pageFling: true,
          pageSnap: true,
          defaultPage: _pdfCurrentPage ?? 0,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            if (mounted) {
              setState(() { _pdfPages = pages; });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() { _pdfLoadingError = "显示PDF时发生错误: $error"; });
            }
          },
          onPageError: (page, error) {
            if (mounted) {
              setState(() { _pdfLoadingError = '显示第 $page 页时发生错误: $error'; });
            }
          },
          onPageChanged: (int? page, int? total) {
            if (mounted && page != null) {
              setState(() { _pdfCurrentPage = page; });
            }
          },
        );
      } else {
        bodyContent = const Center(child: Text("没有合同文件可供预览或链接无效。"));
      }
    }

    return Scaffold(
      appBar: AppBar( /* ... AppBar setup (same as before) ... */
        title: Text(order != null ? '审批: ${order.no}' : '订单审批'),
        actions: order == null || salesOrderState.approvalState == ScreenState.submitting || _isPdfLoading
            ? []
            : <Widget>[
          TextButton(
            onPressed: () => _showApprovalDialog(context, ApprovalAction.reject, order),
            child: const Text('驳回', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _showApprovalDialog(context, ApprovalAction.approve, order),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('确认审核通过', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: _localPdfPath != null && !_isPdfLoading && _pdfLoadingError.isEmpty && _pdfPages != null && _pdfPages! > 0
          ? Container( /* ... Page count display (same as before) ... */
        padding: const EdgeInsets.all(8.0),
        color: Colors.black.withOpacity(0.1),
        child: Text(
          '页码: ${_pdfCurrentPage! + 1}/$_pdfPages',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      )
          : null,
    );
  }
}