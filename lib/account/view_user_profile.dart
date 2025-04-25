import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unithrift/account/review_section.dart';
import 'package:unithrift/explore/feature/item_feature.dart';
import 'package:unithrift/explore/rental/item_rental.dart';
import 'package:unithrift/explore/service/item_service.dart';
import 'package:unithrift/account/transaction.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

  Future<Map<String, dynamic>?> fetchUserData(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("User not found."));
          }

          final userData = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  color: Colors.green[100],
                  child: Stack(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: userData['backgroundImage'] != null
                              ? DecorationImage(
                                  image:
                                      NetworkImage(userData['backgroundImage']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.green[100],
                        ),
                      ),
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: userData['profileImage'] != null
                                ? NetworkImage(userData['profileImage'])
                                : const AssetImage('assets/profile.png')
                                    as ImageProvider,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            userData['username'] ?? 'User Name',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.yellow, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                //(userData['rating'] ?? 0.0).toStringAsFixed(2),
                                (double.tryParse(userData['rating'].toString()) ?? 0.0).toStringAsFixed(2),  // zx
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            userData['address'] ?? 'Location Unknown',
                            style: const TextStyle(
                                color: Colors.black, fontSize: 14),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            userData['bio'] ?? 'No bio added',
                            style: const TextStyle(
                                color: Colors.black, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey, thickness: 1),
                // Tab Section
                DefaultTabController(
                  length: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Listing'),
                          Tab(text: 'Review'),
                          Tab(text: 'Transaction'),
                        ],
                      ),
                      Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: TabBarView(
                          children: [
                            FilteredUserListings(userId: userId),
                            ReviewsSection(userId: userId),
                            TransactionHistoryPage(userId: userId),  // Pass userId here
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FilteredUserListings extends StatefulWidget {
  final String userId;

  const FilteredUserListings({Key? key, required this.userId})
      : super(key: key);

  @override
  _FilteredUserListingsState createState() => _FilteredUserListingsState();
}

class _FilteredUserListingsState extends State<FilteredUserListings> {
  int _selectedTabIndex = 0;

  Stream<List<Map<String, dynamic>>> getProductItems() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('products')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'productId': doc.id,
                })
            .toList());
  }

  String? getFirstValidImage(Map<String, dynamic> product) {
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

  void navigateToProductPage(
      BuildContext context, Map<String, dynamic> product) {
    // Ensure all necessary fields exist with defaults
    final consistentProduct = {
      'productID': product['productID'] ?? product['productId'] ?? '',
      'name': product['name'] ?? 'Unknown Product',
      'price': product['price'] ?? 0,
      'imageUrl1': product['imageUrl1'] ?? '',
      'imageUrl2': product['imageUrl2'] ?? '',
      'imageUrl3': product['imageUrl3'] ?? '',
      'type': product['type'] ?? 'feature',
      'details': product['details'] ?? 'No details available',
      'category': product['category'] ?? 'Miscellaneous',
      'condition': product['condition'] ?? 'Unknown',
      'userId': product['userId'] ?? '',
      'username': product['username'] ?? 'Unknown Seller',
      'userEmail': product['userEmail'] ?? 'Unknown Email',
      'timestamp':
          product['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    };

    // Determine the destination page
    Widget page;
    switch (consistentProduct['type']) {
      case 'feature':
        page = ItemFeaturePage(product: consistentProduct);
        break;
      case 'rental':
        page = ItemRentalPage(product: consistentProduct);
        break;
      case 'service':
        page = ItemServicePage(product: consistentProduct);
        break;
      default:
        page = const Scaffold(
          body: Center(child: Text('Invalid product type.')),
        );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildTab(0, 'Items'),
            _buildTab(1, 'Rentals'),
            _buildTab(2, 'Services'),
          ],
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: getProductItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No listings available.'));
              }

              final filteredItems = snapshot.data!
                  .where((item) =>
                      _selectedTabIndex == 0 && item['type'] == 'feature' ||
                      _selectedTabIndex == 1 && item['type'] == 'rental' ||
                      _selectedTabIndex == 2 && item['type'] == 'service')
                  .toList();

              if (filteredItems.isEmpty) {
                return const Center(
                    child: Text('No listings for this filter.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _buildGridItem(item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String title) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTabIndex = index;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: _selectedTabIndex == index
                ? const Color(0xFFE5E8D9)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _selectedTabIndex == index ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final bool isAvailable = item['isAvailable'] ?? true;

    return Card(
      elevation: 2,
      color: const Color(0xFFF2F3EC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => navigateToProductPage(context, item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image container
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(
                      getFirstValidImage(item) ??
                          'https://via.placeholder.com/200',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.image_not_supported, size: 40),
                        );
                      },
                    ),
                  ),
                ),
                // Content container
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['name'] ?? 'Unknown Item',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['details'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'RM ${(double.parse(item['price'].toString())).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isAvailable)
            Positioned.fill(
              child: Container(
                color: Colors.grey.withOpacity(0.9),
                child: const Center(
                  child: Text(
                    'Not Available',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
