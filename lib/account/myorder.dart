import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:unithrift/account/OrderDetailsPage.dart';
import 'package:unithrift/chatscreen.dart';

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
        centerTitle: true, // Ensure the title group is centered
        title: Row(
          mainAxisSize:
              MainAxisSize.min, // Minimize space to just fit the content
          children: const [
            Icon(Icons.shopping_bag_outlined, color: Colors.black),
            SizedBox(width: 8), // Spacing between icon and text
            Text(
              "My Orders",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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
        _buildStatusTab(1, 'Completed'),
        _buildStatusTab(2, 'Cancelled'),
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

    final orderDate = data['orderDate'] != null
        ? (data['orderDate'] as Timestamp).toDate()
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Section
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    getFirstValidImage(data) ??
                        'https://via.placeholder.com/100',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'RM ${data['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Order ID: ${order.id}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        orderDate != null
                            ? 'Order Date: ${DateFormat.yMMMd().format(orderDate)}'
                            : 'Order Date: Not available',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Chat Icon
                IconButton(
                  icon: const Icon(Icons.chat_outlined, color: Colors.black),
                  onPressed: () => _navigateToChat(data),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Order Status, View Details, and Leave a Review Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${data['status'] ?? 'Processing'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _navigateToDetail(data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF808569),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                      child: const Text('View Details',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                // Leave a Review Button (only show if not reviewed and completed)
                if (data['status']?.toLowerCase() == 'completed' &&
                    data['reviewed'] != true)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF808569),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                      child: const Text('Leave a Review',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(Map<String, dynamic> order) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && order['sellerUserId'] != null) {
      final sellerId = order['sellerUserId'];
      final chatId = _generateChatId(currentUser.uid, sellerId);

      // Check if the chat room exists
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      // Create or update the chat room with order-specific details
      if (!chatDoc.exists) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'users': [currentUser.uid, sellerId],
          'createdAt': FieldValue.serverTimestamp(),
          'contextType': 'orders',
          'orderId': order['orderId'],
          'productName': order['name'],
          'productImage': order['imageUrl'],
        });
      } else {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .update({
          'contextType': 'orders',
          'orderId': order['orderId'],
          'productName': order['name'],
          'productImage': order['imageUrl1'],
        });
      }

      // Navigate to the chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start chat.')),
      );
    }
  }

  void _navigateToDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(
          orderData: order,
          isSeller: false, // Buyer role
        ),
      ),
    );
  }

  String _generateChatId(String userId1, String userId2) {
    return (userId1.compareTo(userId2) < 0)
        ? '$userId1\_$userId2'
        : '$userId2\_$userId1';
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
      builder: (context) => AlertDialog(
        title: Text('Review ${order['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                _rating = rating;
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Write a review...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_rating > 0) {
                await _submitReview(order, _rating, commentController.text);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a rating')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview(
      DocumentSnapshot order, double rating, String reviewText) async {
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final FirebaseAuth auth = FirebaseAuth.instance;

      final user = auth.currentUser;
      if (user == null) return;

      final data = order.data() as Map<String, dynamic>;

      // Fetch reviewer's name
      String reviewerName = 'Anonymous';
      final reviewerDoc = await db.collection('users').doc(user.uid).get();
      if (reviewerDoc.exists) {
        reviewerName = reviewerDoc.data()?['username'] ?? 'Anonymous';
      }

      // Extract product details from order
      final String productId = data['productID'] ?? '';
      final String productName = data['name'] ?? 'Unknown Product';
      final String productImage = data['imageUrl'] ?? '';
      final double productPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
      final String sellerId = data['sellerUserId'] ?? '';

      // Prepare review data
      final Map<String, dynamic> reviewData = {
        'reviewerId': user.uid,
        'reviewerName': reviewerName,
        'orderId': order.id,
        'productId': productId,
        'productName': productName,
        'productImage': productImage,
        'productPrice': productPrice,
        'rating': rating,
        'reviewText': reviewText,
        'role': 'buyer',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add review to the seller's reviews collection
      final sellerReviewsRef =
          db.collection('users').doc(sellerId).collection('reviewsglobal');//yy 原本是reviews only
      await sellerReviewsRef.add(reviewData);

      // Update the seller's average rating
      final sellerReviewsSnapshot = await sellerReviewsRef.get();
      double totalSellerRating = 0;
      for (var review in sellerReviewsSnapshot.docs) {
        totalSellerRating += (review.data()['rating'] as num).toDouble();
      }
      final sellerAverageRating =
          totalSellerRating / sellerReviewsSnapshot.docs.length;

      await db.collection('users').doc(sellerId).update({
        'rating': sellerAverageRating,
      });

      // If the product type is "rental" or "service," add the review to the product reviews collection
      if (data['type'] == 'rental' || data['type'] == 'service'|| data['type'] == 'feature' ) {//yy 加了一个feature
        final productReviewsRef = db
            .collection('users')
            .doc(sellerId)
            .collection('products')
            .doc(productId)
            .collection('reviews');
        await productReviewsRef.add(reviewData);

        // Update the product's average rating
        final productReviewsSnapshot = await productReviewsRef.get();
        double totalProductRating = 0;
        for (var review in productReviewsSnapshot.docs) {
          totalProductRating += (review.data()['rating'] as num).toDouble();
        }
        final productAverageRating =
            totalProductRating / productReviewsSnapshot.docs.length;

        await db
            .collection('users')
            .doc(sellerId)
            .collection('products')
            .doc(productId)
            .update({
          'averageRating': productAverageRating,
        });
      }

      // Mark the order as reviewed
      await db
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(order.id)
          .update({'reviewed': true});

      // Send notification to the seller
      await _addNotification(
        userId: sellerId,
        title: 'New Review Received',
        message:
            '$reviewerName left a review for their order: "$reviewText" with a rating of $rating stars.',
        productImageUrl: productImage,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e')),
      );
    }
  }

  Future<void> _addNotification({
    required String userId,
    required String title,
    required String message,
    String? productImageUrl,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'productImageUrl': productImageUrl,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _updateSellerRating(String sellerId) async {
    try {
      final db = FirebaseFirestore.instance;

      // Get all reviews for the seller
      final reviewsSnapshot = await db
          .collection('users')
          .doc(sellerId)
          .collection('reviews')
          .get();

      if (reviewsSnapshot.docs.isEmpty) return;

      // Calculate the new average rating
      double totalRating = 0;
      for (var review in reviewsSnapshot.docs) {
        totalRating += (review.data()['rating'] as double);
      }
      final averageRating = totalRating / reviewsSnapshot.docs.length;

      // Update the seller's profile with the new average rating
      await db
          .collection('users')
          .doc(sellerId)
          .update({'rating': averageRating});
    } catch (e) {
      print('Error updating seller rating: $e');
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
              'No orders found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Filter the orders based on the selected tab
        final orders = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Determine the order type
          String type = '';
          if (data.containsKey('type')) {
            type = data['type'] == 'feature'
                ? 'item'
                : data['type'].toString().toLowerCase();
          }

          // Determine the status of the order
          String status =
              data['status']?.toString().toLowerCase() ?? 'processing';

          // Processing tab: All statuses except "completed" and "cancelled"
          if (_selectedStatusIndex == 0) {
            return type == _getTypeString() &&
                status != 'completed' &&
                status != 'cancelled';
          }

          // Completed tab: Only "completed"
          if (_selectedStatusIndex == 1) {
            return type == _getTypeString() && status == 'completed';
          }

          // Cancelled tab: Only "cancelled"
          if (_selectedStatusIndex == 2) {
            return type == _getTypeString() && status == 'cancelled';
          }

          return false; // Fallback for unexpected cases
        }).toList();

        // Display a message if no orders match the filter
        if (orders.isEmpty) {
          return Center(
            child: Text(
              'No ${_getStatusLabel()} orders found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Build the list of filtered orders
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index]);
          },
        );
      },
    );
  }

// Helper method to get the selected status label
  String _getStatusLabel() {
    switch (_selectedStatusIndex) {
      case 0:
        return 'processing';
      case 1:
        return 'completed';
      case 2:
        return 'cancelled';
      default:
        return 'processing';
    }
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
        return 'completed';
      case 2:
        return 'cancelled';
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
