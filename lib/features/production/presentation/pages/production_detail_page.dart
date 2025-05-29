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
  // 修改: 用于存储多个已选图片文件
  List<File> _pickedImages = [];

  @override
  void initState() {
    super.initState();
    // 保持您原有的initState逻辑结构
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.d(
          "ProductionDetailPage: Initializing for production order. Order ID: ${widget.orderId}");
      final notifier = ref.read(productionNotifierProvider.notifier);
      final productionState = ref.watch(productionNotifierProvider);
      // 注意：以下行依赖于 productionState.selectedOrder 在此时已经被正确设置且不为null。
      // 如果 selectedOrder 可能为null或者与 widget.orderId 不符，这里可能会抛出错误或获取错误数据。
      // 您的原始代码使用了 ! ，表明您预期 selectedOrder 在这里是有效的。
      if (productionState.selectedOrder != null && productionState.selectedOrder!.id == widget.orderId) {
        notifier.fetchRelatedPurchaseOrders(productionState.selectedOrder!.no);
      } else {
        logger.w("ProductionDetailPage: selectedOrder is null or does not match widget.orderId (${widget.orderId}) in initState when trying to fetch related purchase orders. This might be an issue if related orders are expected immediately.");
        // 如果您的逻辑是在详情加载后才获取关联订单，那么这里可能不需要特别处理。
        // 或者，如果需要，可以在订单详情加载成功后触发关联订单的获取。
        // ref.read(productionNotifierProvider.notifier).fetchProductionOrderDetails(widget.orderId); // 例如，如果需要先确保订单详情已加载
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

  Future<void> _uploadAllPickedImages() async {
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

    // ---------------------------------------------------------------------------
    // Notifier 修改点:
    // 您需要在 ProductionNotifier 中实现或修改一个方法，使其接受图片列表进行批量上传。
    // 例如: Future<bool> uploadShipmentImages(int orderId, List<File> files)
    // 这个方法内部应该处理将多个文件发送到后端的逻辑 (可能是一次请求，也可能是并发的多次请求，取决于您的API设计)。
    // 它也应该相应地更新Notifier内部的状态 (如 imageUploadState, imageUploadMessage) 来反映整个批量操作的结果。
    // ---------------------------------------------------------------------------
    final bool allSuccess = await notifier.uploadShipmentImages(widget.orderId, imagesToUpload); // 假设的新方法

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
        // Notifier 应该在 uploadShipmentImages 方法中设置一个合适的 imageUploadMessage 来解释失败原因
        // (例如："部分图片上传失败" 或 "网络错误导致上传失败" 等)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(productionNotifierProvider).imageUploadMessage.isNotEmpty
                ? ref.read(productionNotifierProvider).imageUploadMessage
                : '图片上传失败，部分或全部图片未能成功。'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // 对于部分成功的情况，您可能需要更复杂的逻辑来从 _pickedImages 中移除已成功的图片，
        // 这需要 Notifier 返回更详细的成功/失败信息。
        // 为简单起见，如果批量操作不完全成功，这里不清除列表，让用户自行处理。
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
      // statusColor = _getProductionStatusColor(order.status); // 您需要根据实际的 ProductionEntity 实现来获取颜色
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

    // 监听图片上传状态以显示提示 (这是您原有的 ref.listen 逻辑，但现在上传在 _uploadAllPickedImages 中处理反馈)
    // 如果您的 notifier.uploadShipmentImage 更新了 imageUploadState 和 imageUploadMessage，
    // 这个监听器仍然可以对单张图片上传的最终状态做出反应（尽管 _uploadAllPickedImages 已提供即时反馈）。
    // 对于批量操作，您可能需要一个不同的状态属性来监听。
    ref.listen<ScreenState>(
        productionNotifierProvider.select((s) => s.imageUploadState), // 监听单图上传的最终状态
            (previous, next) {
          // 这个监听器现在更多的是对 notifier 内部状态变化的反应，
          // 而不是作为批量上传的主要反馈机制。
          if (next == ScreenState.error && mounted) {
            // 避免与 _uploadAllPickedImages 中的反馈重复过多，可选择性保留
            // ScaffoldMessenger.of(context).removeCurrentSnackBar();
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text("Notifier: " + (productionState.imageUploadMessage.isNotEmpty ? productionState.imageUploadMessage : '图片上传失败')), backgroundColor: Colors.red),
            // );
            logger.d("Notifier's imageUploadState changed to error: ${productionState.imageUploadMessage}");
          } else if (next == ScreenState.success && mounted) {
            // ScaffoldMessenger.of(context).removeCurrentSnackBar();
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text("Notifier: " + (productionState.imageUploadMessage.isNotEmpty ? productionState.imageUploadMessage : '图片上传成功')), backgroundColor: Colors.green),
            // );
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
                    ? null // 如果没有图片或(单个)图片正在上传(由Notifier的imageUploadState控制)，则禁用
                    : _uploadAllPickedImages, // 调用新的批量上传方法
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12)
                ),
              ),
            ),
          // 您原有的预览代码 (_pickedImage != null) 已被上面的 Wrap 和清除按钮替代

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