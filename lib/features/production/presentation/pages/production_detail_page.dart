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
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.d(
          "ProductionDetailPage: Initializing for production order)");
      final notifier = ref.read(productionNotifierProvider.notifier);
      final productionState = ref.watch(productionNotifierProvider);
      notifier.fetchRelatedPurchaseOrders(productionState.selectedOrder!.no);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024, maxHeight: 1024);
      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
        });
        logger.d("Image picked: ${pickedFile.path}");
        // 调用Notifier上传图片
        final success = await ref.read(productionNotifierProvider.notifier)
            .uploadShipmentImage(widget.orderId, _pickedImage!);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片上传成功!'), backgroundColor: Colors.green),
          );
          setState(() { _pickedImage = null; }); // 上传成功后清空预览 (可选)
        } else if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图片上传失败: ${ref.read(productionNotifierProvider).imageUploadMessage}'), backgroundColor: Colors.red),
          );
        }
      } else {
        logger.d("No image selected.");
      }
    } catch (e) {
      logger.e("Error picking image: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('使用相机拍摄'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
    // 假设 ProductionEntity 有 statusString 和 getStatusColor 方法或类似逻辑
    // 您需要根据实际的 ProductionEntity 实现来获取颜色
    Color statusColor = Colors.grey; // 默认颜色
    // 示例： final statusConfig = getProductionStatusDisplay(order.status);
    // statusColor = statusConfig.color;
    // String statusText = statusConfig.text;
    // 为了编译，我们先用一个占位
    String statusText = "状态 ${order.status}";
    try {
      statusText = order.statusString; // 假设有这个getter
      // 你可能需要一个更复杂的逻辑来从 ProductionEntity 获取颜色
      // statusColor = _getProductionStatusColor(order.status);
    } catch (e) {/* fallback */}


    return Chip(
      label: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: statusColor, // 使用从实体或辅助函数获取的颜色
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }


  @override
  Widget build(BuildContext context) {
    final productionState = ref.watch(productionNotifierProvider);
    // 从Notifier中获取选中的生产单，确保ID匹配
    final ProductionEntity? order = (productionState.selectedOrder?.id == widget.orderId)
        ? productionState.selectedOrder
        : null;

    final theme = Theme.of(context);
    final DateFormat dateFormatter = DateFormat('yyyy/MM/dd');

    // 监听图片上传状态以显示提示
    ref.listen<ScreenState>(
        productionNotifierProvider.select((s) => s.imageUploadState),
            (previous, next) {
          if (next == ScreenState.error) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(productionState.imageUploadMessage.isNotEmpty ? productionState.imageUploadMessage : '图片上传失败'), backgroundColor: Colors.red),
            );
          } else if (next == ScreenState.success) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(productionState.imageUploadMessage.isNotEmpty ? productionState.imageUploadMessage : '图片上传成功'), backgroundColor: Colors.green),
            );
          }
        }
    );


    Widget mainContent;

    if (order == null) {
      if (productionState.detailState == ScreenState.loading) {
        mainContent = const Center(child: CircularProgressIndicator());
      } else if (productionState.detailState == ScreenState.error) {
        mainContent = Center(
          child: Text('加载生产单详情失败: ${productionState.detailErrorMessage}'),
        );
      } else {
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
                  const SizedBox(height: 8),
                  _buildDetailRow(context, '状态:', order.statusString),
                  _buildDetailRow(context, '业务员:', order.creatorName),
                  _buildDetailRow(context, '跟单员:', order.orderKeeperName),
                  _buildDetailRow(context, '创建时间:', dateFormatter.format(order.createTime)),
                ],
              ),
            ),
          ),

          // 上传出货图部分
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(productionState.imageUploadState == ScreenState.submitting ? Icons.hourglass_empty : Icons.camera_alt_outlined),
              label: Text(productionState.imageUploadState == ScreenState.submitting ? '图片上传中...' : '上传出货图'),
              onPressed: productionState.imageUploadState == ScreenState.submitting ? null : () {
                _showImageSourceActionSheet(context);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          if (_pickedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                children: [
                  const Text("已选图片预览:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Image.file(_pickedImage!, height: 150, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Text("无法预览图片")),
                  const SizedBox(height: 8),
                  TextButton.icon(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      label: const Text("清除选择", style: TextStyle(color: Colors.red)),
                      onPressed: (){ setState(() { _pickedImage = null; });})
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),

          Text("关联采购订单", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRelatedPurchaseOrdersSection(context, productionState),
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
