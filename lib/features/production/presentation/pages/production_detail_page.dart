// lib/features/production_order/presentation/pages/production_detail_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../purchase_order/presentation/pages/purchase_order_detail_page.dart';
import '../../domain/entities/production_entity.dart';
import '../../../../core/utils/logger.dart';
import '../../providers/production_providers.dart';
import '../../providers/production_state.dart';


class ProductionDetailPage extends ConsumerStatefulWidget {
  final int orderId; // 生产单ID

  const ProductionDetailPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<ProductionDetailPage> createState() =>
      _ProductionDetailPageState();
}

class _ProductionDetailPageState extends ConsumerState<ProductionDetailPage> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _pickedImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.d(
          "ProductionDetailPage: Initializing for production order. Order ID: ${widget.orderId}");
      final notifier = ref.read(productionNotifierProvider.notifier);
      final productionState = ref.watch(productionNotifierProvider);
      if (productionState.selectedOrder != null && productionState.selectedOrder!.id == widget.orderId) {
        notifier.fetchRelatedPurchaseOrders(productionState.selectedOrder!.no);

        notifier.fetchShipmentImages(productionState.selectedOrder!.saleOrderId);
      } else {
        logger.w("ProductionDetailPage: selectedOrder is null or does not match widget.orderId (${widget.orderId}) in initState when trying to fetch related purchase orders. This might be an issue if related orders are expected immediately.");
        // ref.read(productionNotifierProvider.notifier).fetchProductionOrderDetails(widget.orderId);
      }
    });
  }

  // 修改: 图片选择逻辑，支持从相机单选或从相册多选
  Future<void> _pickImagesFromSource(ImageSource source) async { // 方法名修改以更清晰表达其作用
    try {
      if (source == ImageSource.camera) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (pickedFile != null) {
          setState(() {
            _pickedImages.add(File(pickedFile.path));
          });
          logger.d("Image picked from camera: ${pickedFile.path}");
        } else {
          logger.d("No image picked from camera.");
        }
      } else { // ImageSource.gallery
        final List<XFile> additionalPickedFiles = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (additionalPickedFiles.isNotEmpty) {
          setState(() {
            _pickedImages.addAll(additionalPickedFiles.map((xfile) => File(xfile.path)));
          });
          logger.d("${additionalPickedFiles.length} images selected from gallery.");
        } else {
          logger.d("No images selected from gallery.");
        }
      }
    } catch (e) {
      logger.e("Error picking images: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _uploadAllPickedImages(int saleOrderId) async {
    if (_pickedImages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择图片后再上传'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final notifier = ref.read(productionNotifierProvider.notifier);
    List<File> imagesToUpload = List.from(_pickedImages); // 复制列表以安全操作

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在上传 ${_pickedImages.length} 张图片...')),
      );
    }

    final bool allSuccess = await notifier.uploadShipmentImages(saleOrderId, imagesToUpload); // 假设的新方法

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // 移除"正在上传"的提示
      if (allSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('所有 ${_pickedImages.length} 张图片均成功上传!'), backgroundColor: Colors.green),
        );
        setState(() {
          _pickedImages.clear(); // 全部成功后清空
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(productionNotifierProvider).imageUploadMessage.isNotEmpty
                ? ref.read(productionNotifierProvider).imageUploadMessage
                : '图片上传失败，部分或全部图片未能成功。'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  // 图片选择来源的底部操作表
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择 (可多选)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImagesFromSource(ImageSource.gallery); // 修改: 调用新的 picking 方法
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('使用相机拍摄 (单张)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImagesFromSource(ImageSource.camera); // 修改: 调用新的 picking 方法
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 以下是您原有的 _buildDetailRow 和 _buildStatusChip 方法，保持不变
  Widget _buildDetailRow(BuildContext context, String label, String? value,
      {IconData? icon}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // 减小垂直间距
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
            const SizedBox(width: 8),
          ] else ... [
            const SizedBox(width: 24), // Placeholder for alignment if no icon
          ],
          SizedBox(
            width: 80, // 固定标签宽度
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.9),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, ProductionEntity order) {
    Color statusColor = Colors.grey;
    String statusText = "状态 ${order.status}";
    try {
      statusText = order.statusString;
    } catch (e) {/* fallback */}

    return Chip(
      label: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: statusColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }


  @override
  Widget build(BuildContext context) {
    final productionState = ref.watch(productionNotifierProvider);
    // 从Notifier中获取选中的生产单，确保ID匹配 (与您原有逻辑一致)
    final ProductionEntity? order = (productionState.selectedOrder?.id == widget.orderId)
        ? productionState.selectedOrder
        : null;

    final theme = Theme.of(context);
    final DateFormat dateFormatter = DateFormat('yyyy/MM/dd');

    ref.listen<ScreenState>(
        productionNotifierProvider.select((s) => s.imageUploadState), // 监听单图上传的最终状态
            (previous, next) {
          if (next == ScreenState.error && mounted) {
            logger.d("Notifier's imageUploadState changed to error: ${productionState.imageUploadMessage}");
          } else if (next == ScreenState.success && mounted) {

            logger.d("Notifier's imageUploadState changed to success: ${productionState.imageUploadMessage}");
          }
        }
    );


    Widget mainContent;

    // 订单详情加载逻辑 (与您原有逻辑一致)
    if (order == null) {
      if (productionState.detailState == ScreenState.loading) {
        mainContent = const Center(child: CircularProgressIndicator());
      } else if (productionState.detailState == ScreenState.error) {
        mainContent = Center(
          child: Text('加载生产单详情失败: ${productionState.detailErrorMessage}'),
        );
      } else {
        // 与您原有逻辑一致的回退文本
        mainContent = const Center(child: Text('生产单信息未加载或不匹配。请返回重试。'));
      }
    } else {
      // 生产单详情已加载
      mainContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // _buildStatusChip(context, order), // 如果需要状态Chip
                  const SizedBox(height: 8),
                  _buildDetailRow(context, '状态:', order.statusString),
                  _buildDetailRow(context, '业务员:', order.creatorName),
                  _buildDetailRow(context, '跟单员:', order.orderKeeperName),
                  _buildDetailRow(context, '创建时间:', dateFormatter.format(order.createTime)),
                ],
              ),
            ),
          ),

          // 修改: 上传出货图部分 - 现在分为选择和上传两个操作
          // 1. 选择图片的按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined), // 更换图标示意选择
              label: const Text('选择/拍摄出货图'),
              onPressed: () {
                _showImageSourceActionSheet(context);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 8), // 增加一点间距

          // 2. 已选图片预览区域 (仅当有图片时显示)
          if (_pickedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("已选图片 (${_pickedImages.length} 张):", style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _pickedImages.map((imageFile) {
                      return Stack(
                        children: [
                          Image.file(imageFile, width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Container(width:80, height:80, color:Colors.grey[300], child: Icon(Icons.broken_image))
                          ),
                          Positioned(
                            top: -14, right: -14, // 微调移除按钮位置
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 22),
                              tooltip: '移除此图片',
                              onPressed: () {
                                setState(() {
                                  _pickedImages.remove(imageFile);
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  if (_pickedImages.isNotEmpty)
                    TextButton.icon(
                        icon: const Icon(Icons.clear_all, color: Colors.red, size: 20),
                        label: const Text("清除所有选择", style: TextStyle(color: Colors.red)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: (){ setState(() { _pickedImages.clear(); });}
                    )
                ],
              ),
            ),

          // 3. 上传已选图片的按钮 (仅当有图片时显示)
          if (_pickedImages.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // 图标和文本可以根据Notifier中更精细的批量上传状态来改变 (如果实现的话)
                icon: Icon(productionState.imageUploadState == ScreenState.submitting ? Icons.hourglass_empty : Icons.upload_file),
                label: Text(productionState.imageUploadState == ScreenState.submitting ? '上传处理中...' : '上传已选图片 (${_pickedImages.length}张)'),
                onPressed: (_pickedImages.isEmpty || productionState.imageUploadState == ScreenState.submitting)
                    ? null
                    : () { _uploadAllPickedImages(productionState.selectedOrder!.saleOrderId); }
                  ,
              ),
            ),

          const Padding(
            padding: EdgeInsets.only(top: 24.0, bottom: 8.0), // 增加与上方元素的间距
            child: Divider(),
          ),
          Text("已上传出货图", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10), // 标题和图片网格之间的间距
          _buildShipmentImagesSection(context, productionState), // 新的 Widget

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),

          Text("关联采购订单", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRelatedPurchaseOrdersSection(context, productionState), // 保持不变
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order != null ? '生产单: ${order.no}' : '生产单详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: mainContent,
      ),
    );
  }

  Widget _buildShipmentImagesSection(BuildContext context, ProductionState productionState) {
    if (productionState.shipmentImagesState == ScreenState.loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    }
    if (productionState.shipmentImagesState == ScreenState.error) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载已上传图片失败: ${productionState.shipmentImagesErrorMessage}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.read(productionNotifierProvider.notifier).fetchShipmentImages(productionState.selectedOrder!.saleOrderId),
                    child: const Text("重试"),
                  )
                ],
              )
          )
      );
    }
    if (productionState.shipmentImages.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('暂无已上传的出货图片。')));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // 因为在 SingleChildScrollView 内部
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 每行显示3张图片
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0, // 使单元格为正方形
      ),
      itemCount: productionState.shipmentImages.length,
      itemBuilder: (context, index) {
        final imageBytes = productionState.shipmentImages[index];
        return GestureDetector(
          onTap: () {
            // TODO: 实现点击图片放大预览功能 (例如使用 showDialog 和 InteractiveViewer)
            showDialog(
                context: context,
                builder: (_) => Dialog(
                    child: InteractiveViewer( // 允许缩放和平移
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.memory(imageBytes, fit: BoxFit.contain)
                    )
                )
            );
            logger.d("Tapped on shipment image $index");
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))
                );
              },
            ),
          ),
        );
      },
    );
  }

  // _buildRelatedPurchaseOrdersSection 保持不变
  Widget _buildRelatedPurchaseOrdersSection(BuildContext context, ProductionState productionState) {
    if (productionState.relatedPurchaseOrdersState == ScreenState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (productionState.relatedPurchaseOrdersState == ScreenState.error) {
      return Center(child: Text('加载关联采购订单失败: ${productionState.relatedPurchaseOrdersErrorMessage}'));
    }
    if (productionState.relatedPurchaseOrders.isEmpty) {
      return const Center(child: Text('没有关联的采购订单。'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: productionState.relatedPurchaseOrders.length,
      itemBuilder: (context, index) {
        final poSummary = productionState.relatedPurchaseOrders[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text('${poSummary.no}   ${poSummary.statusString}'),
            subtitle: Text('供应商: ${poSummary.supplierName}'),
            trailing: ElevatedButton(
              child: const Text('查看'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseOrderDetailPage(orderId: poSummary.id)));
              },
            ),
          ),
        );
      },
    );
  }
}