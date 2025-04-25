import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:unithrift/account/OrderDetailsPage.dart';
import 'package:unithrift/account/sales_report.dart';
import 'package:unithrift/chatscreen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class MySalesPage extends StatefulWidget {
  const MySalesPage({super.key});

  @override
  State<MySalesPage> createState() => _MySalesPageState();
}

class _MySalesPageState extends State<MySalesPage> {
  int _selectedTabIndex = 0; // For Items, Rentals, Services
  int _selectedStatusIndex = 0; // For Processing, Completed, Cancelled

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> getSalesData() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('sales')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> salesData = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['orderId'] = doc.id;

        // Fetch buyer's profile image
        if (data['buyerId'] != null) {
          final buyerDoc =
              await _db.collection('users').doc(data['buyerId']).get();
          if (buyerDoc.exists) {
            data['buyerProfileImage'] = buyerDoc.data()?['profileImage'];
          }
        }
        salesData.add(data);
      }
      return salesData;
    });
  }

  void _updateOrderStatus(String orderId, String status,
      {String? location, String? time}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final sellerId = currentUser.uid;

      // Prepare data for update
      final Map<String, dynamic> updateData = {'status': status};

      if (status == 'Meeting Scheduled') {
        updateData['meetingDetails'] = {
          'location': location ?? 'Not set',
          'time': time ?? 'Not set',
        };
      }

      // Update seller's sales subcollection
      await _db
          .collection('users')
          .doc(sellerId)
          .collection('sales')
          .doc(orderId)
          .update(updateData);

      // Log the status change in the seller's statusHistory subcollection
      await _db
          .collection('users')
          .doc(sellerId)
          .collection('sales')
          .doc(orderId)
          .collection('statusHistory')
          .add({
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        if (status == 'Meeting Scheduled')
          'details': {'location': location, 'time': time},
      });

      // Fetch the order details
      final orderSnapshot = await _db
          .collection('users')
          .doc(sellerId)
          .collection('sales')
          .doc(orderId)
          .get();

      if (!orderSnapshot.exists) return;

      final orderData = orderSnapshot.data();
      if (orderData == null) return;

      final buyerId = orderData['buyerId'];

      if (buyerId != null) {
        // Update buyer's orders subcollection
        await _db
            .collection('users')
            .doc(buyerId)
            .collection('orders')
            .doc(orderId)
            .update(updateData);

        // Log the status change in buyer's statusHistory subcollection
        await _db
            .collection('users')
            .doc(buyerId)
            .collection('orders')
            .doc(orderId)
            .collection('statusHistory')
            .add({
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
          if (status == 'Meeting Scheduled')
            'details': {'location': location, 'time': time},
        });

        // Send specific notifications
        if (status == 'Meeting Scheduled') {
          await _addNotification(
            userId: buyerId,
            title: 'Meeting Scheduled',
            message:
                'The seller has scheduled a meetup for your order at $location on $time.',
            productImageUrl: orderData['imageUrl1'],
            type: 'track',
            meetingDetails: {
              'location': location,
              'time': time,
            },
          );
        } else {
          await _addNotification(
            userId: buyerId,
            title: 'Order Status Updated',
            message: 'Your order status has been updated to "$status".',
            productImageUrl: orderData['imageUrl1'],
            type: 'track',
          );
        }

        // Prompt for review if status is Completed
        if (status == 'Completed') {
          _promptForReview(
            orderId,
            sellerId,
            buyerId,
            {
              'productId': orderData['productID'],
              'productName': orderData['name'],
              'productImage': orderData['imageUrl1'],
              'productPrice': orderData['price'],
            },
          );
        }
      }
    } catch (e) {
      // Error Handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
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

  void _promptForReview(
    String orderId,
    String reviewerId,
    String userId,
    Map<String, dynamic> productDetails,
  ) {
    final reviewController = TextEditingController();
    double selectedRating = 5.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(labelText: 'Write a review'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text('Rating:'),
                  const SizedBox(width: 10),
                  RatingBar.builder(
                    initialRating: selectedRating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemSize: 30.0, // Adjust size to make the stars smaller
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      selectedRating = rating;
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (reviewController.text.isNotEmpty) {
                  _addReview(
                    reviewerId,
                    userId,
                    orderId,
                    productDetails,
                    selectedRating,
                    reviewController.text,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add a review text')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addReview(
    String reviewerId,
    String userId,
    String orderId,
    Map<String, dynamic> productDetails,
    double rating,
    String reviewText,
  ) async {
    try {
      // Fetch the reviewer's name from the Firestore 'users' collection
      String reviewerName = 'Anonymous'; // Default fallback
      final reviewerDoc = await _db.collection('users').doc(reviewerId).get();
      if (reviewerDoc.exists) {
        reviewerName = reviewerDoc.data()?['username'] ?? 'Anonymous';
      }

      final reviewRef =
          _db.collection('users').doc(userId).collection('reviews');

      // Add review to Firestore
      await reviewRef.add({
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'orderId': orderId,
        'productId': productDetails['productId'],
        'productName': productDetails['productName'],
        'productImage': productDetails['productImage'],
        'productPrice': productDetails['productPrice'],
        'rating': rating,
        'reviewText': reviewText,
        'role': 'seller', // Specify role of reviewer
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Calculate the new average rating
      final reviewsSnapshot = await reviewRef.get();
      double totalRating = 0;
      for (var review in reviewsSnapshot.docs) {
        totalRating += (review.data()['rating'] as double);
      }
      final averageRating = totalRating / reviewsSnapshot.docs.length;

      // Update the user's rating field in their profile
      await _db.collection('users').doc(userId).update({
        'rating': averageRating,
      });

      // Send a notification to the buyer
      await _addNotification(
        userId: userId,
        title: 'You Received a Review',
        message:
            '$reviewerName left a review on your transaction: "$reviewText" with a rating of $rating stars.',
        productImageUrl: productDetails['productImage'],
        type: 'review',
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
    required String type,
    Map<String, dynamic>?
        meetingDetails, // Add optional parameter for meeting details
  }) async {
    final notificationMessage = meetingDetails != null
        ? '$message Location: ${meetingDetails['location'] ?? 'Not set'}, Date & Time: ${meetingDetails['time'] ?? 'Not set'}.'
        : message;

    await _db.collection('users').doc(userId).collection('notifications').add({
      'title': title,
      'message': notificationMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'productImageUrl': productImageUrl,
      'type': type,
    });
  }

  void _showMeetingDetailsDialog(String orderId) {
    final locationController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Meeting Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: locationController,
                    decoration:
                        const InputDecoration(labelText: 'Meeting Location'),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate != null
                                ? DateFormat.yMMMd().format(selectedDate!)
                                : 'Select Date',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          selectedTime = time;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedTime != null
                                ? selectedTime!.format(context)
                                : 'Select Time',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.access_time),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedDate == null ||
                        selectedTime == null ||
                        locationController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please provide all meeting details')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _updateOrderStatus(
                      orderId,
                      'Meeting Scheduled',
                      location: locationController.text,
                      time:
                          '${DateFormat.yMMMd().format(selectedDate!)} ${selectedTime!.format(context)}',
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToChat(Map<String, dynamic> sale) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && sale['buyerId'] != null) {
      final buyerId = sale['buyerId'];
      final chatId = _generateChatId(currentUser.uid, buyerId);

      // Check if the chat room exists
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      // Create or update the chat room with order-specific details
      if (!chatDoc.exists) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'users': [currentUser.uid, buyerId],
          'createdAt': FieldValue.serverTimestamp(),
          'contextType': 'sales', // Indicates this chat is from sales page
          'orderId': sale['orderId'],
          'productName': sale['name'],
          'productImage': sale['imageUrl1'],
        });
      } else {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .update({
          'contextType': 'sales',
          'orderId': sale['orderId'],
          'productName': sale['name'],
          'productImage': sale['imageUrl1'],
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

  String _generateChatId(String userId1, String userId2) {
    return (userId1.compareTo(userId2) < 0)
        ? '$userId1\_$userId2'
        : '$userId2\_$userId1';
  }

  void _navigateToDetail(Map<String, dynamic> sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(
          orderData: sale,
          isSeller: true, // Seller role
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Ensure the title group is centered
        title: Row(
          mainAxisSize:
              MainAxisSize.min, // Minimize space to just fit the content
          children: const [
            Icon(Icons.storefront_outlined, color: Colors.black),
            SizedBox(width: 8), // Spacing between icon and text
            Text(
              "My Sales",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.black),
            tooltip: 'View Sales Report',
            onPressed: () {
              // Navigate to the Sales Report Page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesReportPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypesTabs(),
          const SizedBox(height: 7), // Spacing between tabs and status
          _buildStatusTabs(),
          Expanded(
            child: _buildContentSection(), // Replace with your sales content
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

  Widget _buildTabRow() {
    return Row(
      children: [
        _buildTab(0, 'All'),
        _buildTab(1, 'Ongoing'),
        _buildTab(2, 'Completed'),
      ],
    );
  }

  Widget _buildContentSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getSalesData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No sales data available.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Filter data by selected tab (Items, Rentals, Services)
        List<Map<String, dynamic>> filteredByType;
        switch (_selectedTabIndex) {
          case 0: // feature
            filteredByType = snapshot.data!
                .where((sale) => sale['type'] == 'feature')
                .toList();
            break;
          case 1: // Rentals
            filteredByType = snapshot.data!
                .where((sale) => sale['type'] == 'rental')
                .toList();
            break;
          case 2: // Services
            filteredByType = snapshot.data!
                .where((sale) => sale['type'] == 'service')
                .toList();
            break;
          default: // Items
            filteredByType =
                snapshot.data!.where((sale) => sale['type'] == 'item').toList();
        }

        // Further filter by status (Processing, Completed, Cancelled)
        List<Map<String, dynamic>> filteredData;
        switch (_selectedStatusIndex) {
          case 1: // Completed
            filteredData = filteredByType
                .where((sale) => sale['status']?.toLowerCase() == 'completed')
                .toList();
            break;
          case 2: // Cancelled
            filteredData = filteredByType
                .where((sale) => sale['status']?.toLowerCase() == 'cancelled')
                .toList();
            break;
          default: // Processing
            filteredData = filteredByType
                .where((sale) =>
                    sale['status']?.toLowerCase() != 'completed' &&
                    sale['status']?.toLowerCase() != 'cancelled')
                .toList();
        }

        if (filteredData.isEmpty) {
          return const Center(
            child: Text(
              'No matching sales found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filteredData.length,
          itemBuilder: (context, index) {
            final sale = filteredData[index];
            return _buildSalesCard(sale);
          },
        );
      },
    );
  }

  Widget _buildSalesCard(Map<String, dynamic> sale) {
    // Safely handle potential null values
    final orderDate = sale['orderDate'] != null
        ? (sale['orderDate'] as Timestamp).toDate()
        : null;

    return GestureDetector(
      onTap: () => _navigateToDetail(sale), // Navigate to the detailed view
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buyer Section
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: sale['buyerProfileImage'] != null
                      ? NetworkImage(sale['buyerProfileImage'])
                      : null,
                  backgroundColor: const Color(0xFF808569),
                  child: sale['buyerProfileImage'] == null
                      ? Text(
                          sale['buyerName']?.substring(0, 1).toUpperCase() ??
                              'B',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale['buyerName'] ?? 'Unknown Buyer',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (sale['buyerEmail'] != null)
                        Text(
                          sale['buyerEmail'],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: () => _navigateToChat(sale),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Product Section
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    //yy
                    getFirstValidImage(sale) ??
                        'https://via.placeholder.com/100',
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
                        sale['name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'RM ${sale['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Order ID: ${sale['orderId'] ?? 'Not available'}',
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
              ],
            ),
            const SizedBox(height: 15),

            // Conditional Section for Meetup or Delivery
            if (sale['isMeetup'] == true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meetup Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Location: ${sale['meetingDetails']?['location'] ?? 'Not set'}',
                  ),
                  Text(
                    'Date & Time: ${sale['meetingDetails']?['time'] ?? 'Not set'}',
                  ),
                ],
              )
            else if (sale['status'] == 'Shipped')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Status:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text('Tracking Number: ${sale['trackingNo'] ?? 'Not set'}'),
                ],
              ),
            const SizedBox(height: 15),

            // Order Status Section
            DropdownButtonFormField<String>(
              value: sale['status'],
              decoration: const InputDecoration(
                labelText: 'Order Status',
                border: OutlineInputBorder(),
              ),
              items: sale['isMeetup'] == true
                  ? const [
                      DropdownMenuItem(
                          value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'Meeting Scheduled',
                          child: Text('Meeting Scheduled')),
                      DropdownMenuItem(
                          value: 'In Progress', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'Completed', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'Cancelled', child: Text('Cancelled')),
                    ]
                  : const [
                      DropdownMenuItem(
                          value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'Shipped', child: Text('Shipped')),
                      DropdownMenuItem(
                          value: 'Out for Delivery',
                          child: Text('Out for Delivery')),
                      DropdownMenuItem(
                          value: 'Delivered', child: Text('Delivered')),
                      DropdownMenuItem(
                          value: 'Completed', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'Cancelled', child: Text('Cancelled')),
                    ],
              onChanged: (value) {
                if (value == 'Meeting Scheduled' && sale['isMeetup'] == true) {
                  _showMeetingDetailsDialog(sale['orderId']);
                } else {
                  _updateOrderStatus(sale['orderId'], value!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
