import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyOrders extends StatefulWidget {
  @override
  _MyOrdersState createState() => _MyOrdersState();
}

class _MyOrdersState extends State<MyOrders> {
  int _selectedTabIndex = 0;
  int _selectedStatusIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTypesTabs(),
          const SizedBox(height: 7), // Spacing between tabs and status
          _buildStatusTabs(),
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypesTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildTab(0, 'Items'),
          _buildTab(1, 'Rentals'),
          _buildTab(2, 'Services'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _selectedStatusIndex =
                0; // Reset to 'Processing' when switching tabs
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedTabIndex == index
                    ? const Color(0xFF808569)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _selectedTabIndex == index
                  ? const Color(0xFF808569)
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Row(
      children: [
        _buildStatusTab(0, 'Processing'),
        _buildStatusTab(1, 'Delivered'),
        _buildStatusTab(2, 'Canceled'),
      ],
    );
  }

  String? getFirstValidImage(Map<String, dynamic> data) {
    // Get first non-MP4 image URL
    final imageUrls =
        [data['imageUrl1'], data['imageUrl2'], data['imageUrl3']].firstWhere(
      (url) =>
          url != null && url.isNotEmpty && !url.toLowerCase().endsWith('.mp4'),
      orElse: () =>
          data['imageUrl'] ??
          'https://via.placeholder.com/100x100?text=No+Image',
    );

    return imageUrls;
  }

  Widget _buildOrderCard(DocumentSnapshot order) {
    Map<String, dynamic> data = order.data() as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    // In _buildOrderCard, update the Image.network part:
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        getFirstValidImage(data) ??
                            'https://via.placeholder.com/100x100?text=No+Image',
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: Icon(Icons.image_not_supported,
                                color: Colors.grey[400]),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[100],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    )),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name
                      Text(
                        data['name'] ?? 'Product Name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Order details in grey
                      Text(
                        'Order ID: ${order.id}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Tracking No: ${data['trackingNo'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      _buildSpecificInfo(order),
                      Text(
                        'Total: RM ${data['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ButtonBar(
            children: [
              ElevatedButton(
                onPressed: () => _navigateToDetails(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF808569),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text('Details',
                    style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () => _showReviewDialog(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB1BA8E),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child:
                    const Text('Review', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      return date.toDate().toString().split(' ')[0];
    }
    return date.toString();
  }

  void _showReviewDialog(DocumentSnapshot order) {
    double _rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review ${order['name']}'),
          content: SingleChildScrollView(
            // Added SingleChildScrollView
            child: Container(
              width: MediaQuery.of(context).size.width *
                  0.8, // Set width constraint
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Color(0xFF808569),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 10), // Added spacing
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'Write your review...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10), // Adjusted padding
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_rating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a rating')),
                  );
                  return;
                }
                await _submitReview(order, _rating, commentController.text);
                Navigator.pop(context);
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview(
      DocumentSnapshot order, double rating, String comment) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Map<String, dynamic> data = order.data() as Map<String, dynamic>;

      final reviewData = {
        'buyerId': user.uid,
        'userEmail': user.email,
        'comment': comment,
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
        'productId': data['productId'],
        'productName': data['name'],
        'imageUrl': data['imageUrl'],
        'orderType': data['type'],
        'sellerId': data['sellerUserId']
      };

      // Updated path to match your structure
      await FirebaseFirestore.instance
          .collection('products')
          .doc(data['productId'])
          .collection('reviews')
          .add(reviewData);

      // Update order status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(order.id)
          .update({
        'reviewed': true,
        'rating': rating,
        'reviewText': comment,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error submitting review: $e');
    }
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('orders') // User's orders subcollection
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No ${_getTypeString()} orders found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final orders = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String type = data['type'] ?? '';
          String status =
              data['status']?.toString().toLowerCase() ?? 'processing';

          // Match both type and status with the selected filters
          return type == _getTypeString() && status == _getStatusString();
        }).toList();

        if (orders.isEmpty) {
          return Center(
            child: Text(
              'No ${_getTypeString()} orders found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index]);
          },
        );
      },
    );
  }

  Widget _buildStatusTab(int index, String title) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatusIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _selectedStatusIndex == index
                ? const Color(0xFFE5E8D9)
                : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _selectedStatusIndex == index ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeString() {
    switch (_selectedTabIndex) {
      case 0:
        return 'item';
      case 1:
        return 'rental';
      case 2:
        return 'service';
      default:
        return 'item';
    }
  }

  String _getStatusString() {
    switch (_selectedStatusIndex) {
      case 0:
        return 'processing';
      case 1:
        return 'delivered';
      case 2:
        return 'canceled';
      default:
        return 'processing';
    }
  }

  Widget _buildSpecificInfo(DocumentSnapshot order) {
    Map<String, dynamic> data = order.data() as Map<String, dynamic>;

    String infoText = '';
    switch (_selectedTabIndex) {
      case 0: // Items
        infoText = 'Condition: ${data['condition'] ?? 'N/A'}';
        break;
      case 1: // Rentals
        final startDate =
            _formatDate(data['startRentalDate']); // Changed from startDate
        final endDate =
            _formatDate(data['endRentalDate']); // Changed from endDate
        infoText = 'Rental Duration: $startDate - $endDate';
        break;
      case 2: // Services
        final serviceDate = _formatDate(data['serviceDate']);
        infoText = 'Service Date: $serviceDate';
        break;
    }

    return Text(
      infoText,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
      ),
    );
  }

  void _navigateToDetails(DocumentSnapshot order) {
    String route;
    switch (_selectedTabIndex) {
      case 0:
        route = '/item_feature';
        break;
      case 1:
        route = '/item_rental';
        break;
      case 2:
        route = '/item_service';
        break;
      default:
        route = '/item_feature';
    }

    Navigator.pushNamed(context, route, arguments: order.id);
  }
}
