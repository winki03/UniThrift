import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:unithrift/account/view_user_profile.dart';

class OrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final bool isSeller; // True for My Sales, False for My Orders

  const OrderDetailsPage({
    Key? key,
    required this.orderData,
    required this.isSeller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Product Information',
              icon: Icons.shopping_bag,
              child: _buildProductInfo(),
            ),
            if (isSeller)
              _buildSection(
                title: 'Buyer Information',
                icon: Icons.person,
                child: _buildBuyerInfo(context),
              )
            else
              _buildSection(
                title: 'Seller Information',
                icon: Icons.store,
                child: _buildSellerInfo(context),
              ),
            _buildSection(
              title: 'Order Details',
              icon: Icons.receipt_long,
              child: _buildOrderDetails(),
            ),
            if (orderData['type'] == 'rental') ...[
              _buildSection(
                title: 'Rental Details',
                icon: Icons.calendar_today,
                child: _buildRentalDetails(),
              ),
            ] else if (orderData['type'] == 'service') ...[
              _buildSection(
                title: 'Service Details',
                icon: Icons.build_circle,
                child: _buildServiceDetails(),
              ),
            ],
            if (orderData['isMeetup'] == true) ...[
              _buildSection(
                title: 'Meetup Information',
                icon: Icons.location_on,
                child: _buildMeetupDetails(),
              ),
            ] else if (!orderData['isMeetup'] &&
                orderData['address'] != null) ...[
              _buildSection(
                title: 'Delivery Information',
                icon: Icons.local_shipping,
                child: _buildDeliveryDetails(),
              ),
            ],
            _buildSection(
              title: 'Status History',
              icon: Icons.history,
              child: _buildStatusHistory(orderData['orderId']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String? getFirstValidImage(Map<String, dynamic> product) {
    //yy
    List<dynamic> images = [
      product['imageUrl1'],
      product['imageUrl2'],
      product['imageUrl3'],
      product['imageUrl4'],
      product['imageUrl5'],
    ]
        .where((url) =>
            url != null &&
            url != 'https://via.placeholder.com/50' &&
            !url.toLowerCase().endsWith('.mp4'))
        .toList();

    return images.isNotEmpty ? images[0] : null;
  }

  Widget _buildProductInfo() {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          //yy
          getFirstValidImage(orderData) ?? 'https://via.placeholder.com/200',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.image_not_supported, size: 40),
            );
          },
        ),
      ),
      title: Text(
        orderData['name'] ?? 'Unknown Product',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Condition: ${orderData['condition'] ?? 'N/A'}'),
          Text('Price: RM ${orderData['price']?.toStringAsFixed(2) ?? '0.00'}'),
        ],
      ),
    );
  }

  Widget _buildBuyerInfo(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(orderData['buyerId'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey,
              child: CircularProgressIndicator(color: Colors.white),
            ),
            title: Text('Loading...'),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              orderData['buyerName'] ?? 'Unknown Buyer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(orderData['buyerEmail'] ?? 'No Email'),
          );
        }

        final buyerData = snapshot.data!.data() as Map<String, dynamic>?;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(
                  userId: orderData['buyerId'],
                ),
              ),
            );
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: buyerData?['profileImage'] != null
                  ? NetworkImage(buyerData!['profileImage'])
                  : null,
              backgroundColor: Colors.grey[300],
              child: buyerData?['profileImage'] == null
                  ? Text(
                      orderData['buyerName']?.substring(0, 1).toUpperCase() ??
                          'B',
                      style: const TextStyle(color: Colors.black),
                    )
                  : null,
            ),
            title: Text(
              orderData['buyerName'] ?? 'Unknown Buyer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(orderData['buyerEmail'] ?? 'No Email'),
          ),
        );
      },
    );
  }

  Widget _buildSellerInfo(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(orderData['sellerUserId'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey,
              child: CircularProgressIndicator(color: Colors.white),
            ),
            title: Text('Loading...'),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              orderData['sellerName'] ?? 'Unknown Seller',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(orderData['sellerEmail'] ?? 'No Email'),
          );
        }

        final sellerData = snapshot.data!.data() as Map<String, dynamic>?;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(
                  userId: orderData['sellerUserId'], // Pass seller's userId
                ),
              ),
            );
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: sellerData?['profileImage'] != null
                  ? NetworkImage(sellerData!['profileImage'])
                  : null,
              backgroundColor: Colors.grey[300],
              child: sellerData?['profileImage'] == null
                  ? Text(
                      orderData['sellerName']?.substring(0, 1).toUpperCase() ??
                          'S',
                      style: const TextStyle(color: Colors.black),
                    )
                  : null,
            ),
            title: Text(
              orderData['sellerName'] ?? 'Unknown Seller',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(orderData['sellerEmail'] ?? 'No Email'),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      children: [
        _buildDetailRow('Order ID', orderData['orderId']),
        _buildDetailRow(
          'Order Date',
          DateFormat.yMMMd()
              .add_jm()
              .format((orderData['orderDate'] as Timestamp).toDate()),
        ),
        _buildDetailRow('Total Amount',
            'RM ${orderData['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
        _buildDetailRow('Quantity', '${orderData['quantity'] ?? 1}'),
      ],
    );
  }

  Widget _buildRentalDetails() {
    return Column(
      children: [
        _buildDetailRow('Start Date', orderData['startRentalDate']),
        _buildDetailRow('End Date', orderData['endRentalDate']),
      ],
    );
  }

  Widget _buildServiceDetails() {
    return Column(
      children: [
        _buildDetailRow('Service Date', orderData['serviceDate']),
      ],
    );
  }

  Widget _buildMeetupDetails() {
    return Column(
      children: [
        _buildDetailRow(
          'Meetup Location',
          orderData['meetingDetails']?['location'] ??
              orderData['address'] ??
              'Not specified',
        ),
        if (orderData['meetingDetails']?['time'] != null)
          _buildDetailRow('Date & Time', orderData['meetingDetails']?['time']),
      ],
    );
  }

  Widget _buildDeliveryDetails() {
    return _buildDetailRow('Delivery Address', orderData['address']);
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHistory(String orderId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection(isSeller ? 'sales' : 'orders') // Adjust collection
          .doc(orderId)
          .collection('statusHistory')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No status history available.");
        }

        final statusHistory = snapshot.data!.docs;

        return Column(
          children: statusHistory.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final details = data['details'] as Map<String, dynamic>?;

            return ListTile(
              leading: const Icon(Icons.circle, color: Colors.blue, size: 12),
              title: Text(data['status'] ?? "Unknown Status"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMd()
                        .add_jm()
                        .format((data['timestamp'] as Timestamp).toDate()),
                  ),
                  if (details != null) ...[
                    if (details['location'] != null)
                      Text('Location: ${details['location']}'),
                    if (details['time'] != null)
                      Text('Date & Time: ${details['time']}'),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
