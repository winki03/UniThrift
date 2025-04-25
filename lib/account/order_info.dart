import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unithrift/explore/feature/item_feature.dart';
import 'package:unithrift/account/view_user_profile.dart';
import 'package:unithrift/explore/rental/item_rental.dart';
import 'package:unithrift/explore/service/item_service.dart';

class OrderInfo extends StatefulWidget {
  final String orderId;
  const OrderInfo({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderInfo> createState() => _OrderInfoState();
}

class _OrderInfoState extends State<OrderInfo> {
  Map<String, dynamic>? order;
  Map<String, dynamic>? sellerInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        setState(() {
          order = orderDoc.data();
        });

        if (order!['sellerUserId'] != null) {
          await _fetchSellerProfile(order!['sellerUserId']);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not found.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load order details: $e')),
      );
    }
  }

  Future<void> _fetchSellerProfile(String sellerUserId) async {
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerUserId)
          .get();

      if (sellerDoc.exists) {
        setState(() {
          sellerInfo = sellerDoc.data();
        });
      }
    } catch (e) {
      print('Failed to fetch seller profile: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (order == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFFE5E8D9),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              order!['imageUrl'] ?? 'https://via.placeholder.com/150',
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product: ${order!['name'] ?? 'Unknown Product'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Order ID: ${order!['orderId'] ?? 'N/A'}'),
                  const SizedBox(height: 5),
                  Text(
                      'Total Amount: RM${order!['totalAmount']?.toString() ?? '0.00'}'),
                  const SizedBox(height: 5),
                  Text('Status: ${order!['status'] ?? 'Pending'}'),
                  const SizedBox(height: 30),

                  // Seller Section
                  _buildSellerInfo(),

                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final productType = order!['type'];
                        final sellerUserId = order!['sellerUserId'];
                        final productID = order!['productID'];

                        // Fetch product from the seller's products subcollection
                        final productDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(sellerUserId)
                            .collection('products')
                            .doc(productID)
                            .get();

                        // Include the productID in the data
                        final productData = {
                          ...productDoc.data() ?? {},
                          'productID': productID,
                          'userId': sellerUserId,
                        };

                        Widget destinationPage;
                        switch (productType.toString().toLowerCase()) {
                          case 'rental':
                            destinationPage =
                                ItemRentalPage(product: productData);
                            break;
                          case 'service':
                            destinationPage =
                                ItemServicePage(product: productData);
                            break;
                          case 'feature':
                          default:
                            destinationPage =
                                ItemFeaturePage(product: productData);
                            break;
                        }

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => destinationPage,
                          ),
                        );
                        if (order!['sellerUserId'] != null) {
                          _fetchSellerProfile(order!['sellerUserId']);
                        }
                      },
                      child: const Text(
                        'View Product Page',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerInfo() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sellerInfo == null) {
      return const Center(child: Text('Seller information unavailable.'));
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UserProfilePage(userId: order!['sellerUserId']),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFD8DCC6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundImage: sellerInfo!['profileImage'] != null
                  ? NetworkImage(sellerInfo!['profileImage'])
                  : null,
              child: sellerInfo!['profileImage'] == null
                  ? Text(
                      sellerInfo!['username']?[0].toUpperCase() ?? 'S',
                      style: const TextStyle(fontSize: 30),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller: ${sellerInfo!['username'] ?? 'Unknown Seller'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Tap to view profile',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
