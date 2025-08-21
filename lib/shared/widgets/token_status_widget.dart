import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/token_manager_provider.dart';
import '../../core/utils/logger.dart';

class TokenStatusWidget extends ConsumerStatefulWidget {
  const TokenStatusWidget({super.key});

  @override
  ConsumerState<TokenStatusWidget> createState() => _TokenStatusWidgetState();
}

class _TokenStatusWidgetState extends ConsumerState<TokenStatusWidget> {
  Map<String, dynamic>? _tokenStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTokenStatus();
  }

  Future<void> _loadTokenStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tokenManager = ref.read(tokenManagerProvider);
      final status = await tokenManager.getTokenStatus();
      setState(() {
        _tokenStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      logger.e("Error loading token status", error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tokenManager = ref.read(tokenManagerProvider);
      final success = await tokenManager.manualRefreshToken();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token refreshed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh token')),
        );
      }
    } catch (e) {
      logger.e("Error refreshing token", error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing token: $e')),
      );
    } finally {
      await _loadTokenStatus();
    }
  }

  Color _getStatusColor() {
    if (_tokenStatus == null) return Colors.grey;
    
    final status = _tokenStatus!['status'] as String?;
    switch (status) {
      case 'valid':
        return Colors.green;
      case 'expiring_soon':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    if (_tokenStatus == null) return 'Unknown';
    
    final status = _tokenStatus!['status'] as String?;
    switch (status) {
      case 'valid':
        return 'Valid';
      case 'expiring_soon':
        return 'Expiring Soon';
      case 'expired':
        return 'Expired';
      case 'error':
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Token Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_getStatusText()),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_tokenStatus != null) ...[
              _buildStatusRow('Has Token', _tokenStatus!['hasToken']?.toString() ?? 'Unknown'),
              _buildStatusRow('Is Expired', _tokenStatus!['isExpired']?.toString() ?? 'Unknown'),
              _buildStatusRow('Expiring Soon', _tokenStatus!['isExpiringSoon']?.toString() ?? 'Unknown'),
              if (_tokenStatus!['remainingTime'] != null)
                _buildStatusRow('Remaining Time', '${_tokenStatus!['remainingTime']} minutes'),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loadTokenStatus,
                    child: const Text('Refresh Status'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _refreshToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Refresh Token'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
}
