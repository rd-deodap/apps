import 'package:flutter/material.dart';
import 'package:rapidmiles/utils/date_utils.dart';

/// Displays detailed order information after successful pickup
class PickupConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const PickupConfirmationScreen({Key? key, required this.orderData})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = orderData['data'] as Map<String, dynamic>?;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pickup Confirmation')),
        body: const Center(child: Text('No order data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Confirmation'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDetails(context, data),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Success Header
            Container(
              width: double.infinity,
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    orderData['message'] ?? 'Order picked up successfully',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDateTime(data['picked_up_at']),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            // Order Basic Info
            _buildSection(
              title: 'Order Information',
              icon: Icons.receipt_long,
              children: [
                _buildInfoRow('Order No', data['order_no']),
                _buildInfoRow('AWB', data['awb']),
                _buildInfoRow('Order Date', _formatDate(data['order_date'])),
                _buildInfoRow(
                  'Status',
                  data['order_status'],
                  valueStyle: TextStyle(
                    color: _getStatusColor(data['order_status']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildInfoRow('Payment Type', data['payment_type']),
                if (data['payment_type'] == 'COD')
                  _buildInfoRow(
                    'Collectable Amount',
                    '₹${data['collectable_amount']}',
                    valueStyle: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),

            const Divider(height: 1),

            // Shipping From
            _buildSection(
              title: 'Ship From',
              icon: Icons.store,
              children: [
                _buildInfoRow('Name', data['ship_from_name']),
                _buildAddressRow(
                  data['ship_from_address_line_1'],
                  data['ship_from_address_line_2'],
                ),
                _buildInfoRow(
                  'Location',
                  '${data['ship_from_city']}, ${data['ship_from_state']} - ${data['ship_from_pincode']}',
                ),
                _buildInfoRow('Contact', data['ship_from_contact']),
              ],
            ),

            const Divider(height: 1),

            // Shipping To
            _buildSection(
              title: 'Ship To',
              icon: Icons.location_on,
              children: [
                _buildInfoRow('Name', data['ship_to_name']),
                _buildAddressRow(
                  data['ship_to_address_line_1'],
                  data['ship_to_address_line_2'],
                ),
                _buildInfoRow(
                  'Location',
                  '${data['ship_to_city']}, ${data['ship_to_state']} - ${data['ship_to_pincode']}',
                ),
                _buildInfoRow('Contact', data['ship_to_contact']),
              ],
            ),

            const Divider(height: 1),

            // Package Details
            _buildSection(
              title: 'Package Details',
              icon: Icons.inventory_2,
              children: [
                _buildInfoRow('Weight', '${data['total_weight_kg']} kg'),
                _buildInfoRow(
                  'Dimensions (L×W×H)',
                  '${data['package_length_cm']}×${data['package_width_cm']}×${data['package_height_cm']} cm',
                ),
                _buildInfoRow('Order Amount', '₹${data['order_amount']}'),
              ],
            ),

            // Items List
            if (data['items'] != null && (data['items'] as List).isNotEmpty)
              Column(
                children: [
                  const Divider(height: 1),
                  _buildSection(
                    title: 'Items (${(data['items'] as List).length})',
                    icon: Icons.list_alt,
                    children: [
                      ...(data['items'] as List).map(
                        (item) => _buildItemCard(item),
                      ),
                    ],
                  ),
                ],
              ),

            // Company Info
            if (data['company'] != null)
              Column(
                children: [
                  const Divider(height: 1),
                  _buildSection(
                    title: 'Company',
                    icon: Icons.business,
                    children: [
                      _buildInfoRow('Name', data['company']['name']),
                      _buildInfoRow('Code', data['company']['code']),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style:
                  valueStyle ??
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String? line1, String? line2) {
    final address = [line1, line2]
        .where((line) => line != null && line.isNotEmpty && line != ',')
        .join(', ');
    return _buildInfoRow('Address', address);
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['item_description'] ?? item['item_identifier'] ?? 'Item',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qty: ${item['item_qty']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  'Weight: ${item['item_weight']} kg',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  '₹${item['item_amount']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (item['item_length_cm'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Dimensions: ${item['item_length_cm']}×${item['item_width_cm']}×${item['item_height_cm']} cm',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String? dateTime) =>
      AppDate.formatDateTimeFromIso(dateTime);

  String _formatDate(String? date) => AppDate.formatDateFromIso(date);

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PICKED_UP':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'RTO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _shareDetails(BuildContext context, Map<String, dynamic> data) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality - Coming soon')),
    );
  }
}
