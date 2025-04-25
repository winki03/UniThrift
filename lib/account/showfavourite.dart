import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unithrift/account/favourite_service.dart';
import 'package:unithrift/explore/feature/item_feature.dart';
import 'package:unithrift/explore/rental/item_rental.dart';
import 'package:unithrift/explore/service/item_service.dart';

class ShowFavorites extends StatefulWidget {
  const ShowFavorites({Key? key}) : super(key: key);

  @override
  State<ShowFavorites> createState() => _ShowFavoritesState();
}

class _ShowFavoritesState extends State<ShowFavorites> {
  int _selectedTabIndex = 0;
  final FavoriteService _favoriteService = FavoriteService();

  Widget _buildTabRow() {
    return Row(
      children: [
        _buildTab(0, 'Items'),
        _buildTab(1, 'Rentals'),
        _buildTab(2, 'Services'),
      ],
    );
  }

  Widget _buildTab(int index, String title) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
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

  Stream<List<Map<String, dynamic>>> getFavoriteItems() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Likes'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabRow(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getFavoriteItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No likes yet'));
                }

                String selectedType;
                String sectionTitle;

                switch (_selectedTabIndex) {
                  case 0:
                    selectedType = 'feature';
                    sectionTitle = 'Items';
                    break;
                  case 1:
                    selectedType = 'rental';
                    sectionTitle = 'Rentals';
                    break;
                  case 2:
                    selectedType = 'service';
                    sectionTitle = 'Services';
                    break;
                  default:
                    selectedType = 'feature';
                    sectionTitle = 'Items';
                }

                final filteredItems = snapshot.data!
                    .where((item) => item['type'] == selectedType)
                    .toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${sectionTitle.toLowerCase()} in likes',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
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
      ),
    );
  }

  String getValidImageUrl(Map<String, dynamic> product) {
    // List of possible image URLs in priority order
    final imageUrls = [
      product['imageUrl1'],
      product['imageUrl2'],
      product['imageUrl3']
    ];

    // Find first valid image URL
    for (String? url in imageUrls) {
      if (url != null &&
          url.isNotEmpty &&
          !url.toLowerCase().endsWith('.mp4') &&
          url != 'https://via.placeholder.com/50') {
        return url;
      }
    }

    return 'https://via.placeholder.com/100';
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _navigateToItemDetails(item),
      child: Card(
        elevation: 2,
        color: const Color(0xFFF2F3EC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image.network(
                  getValidImageUrl(item),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_not_supported, size: 40),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unnamed Item',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RM ${item['price'] ?? '0'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 24,
                          ),
                          onPressed: () =>
                              _showRemoveConfirmation(item, context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveConfirmation(
      Map<String, dynamic> item, BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove from My Likes'),
          content: const Text('Are you sure you want to unlike this item?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop();
                _favoriteService.toggleFavorite(item);
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToItemDetails(Map<String, dynamic> item) async {
  // Fetch complete product data including seller info
  final productDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(item['sellerUserId'])
      .collection('products')
      .doc(item['productID'])
      .get();

  if (productDoc.exists) {
    final completeProduct = {
      ...productDoc.data()!,
      'productID': item['productID'],
      'userId': item['sellerUserId'],
      'username': item['sellerName'],
      'userEmail': item['sellerEmail'],
    };

    Widget targetPage;
    switch (item['type']) {
      case 'feature':
        targetPage = ItemFeaturePage(product: completeProduct);
        break;
      case 'rental':
        targetPage = ItemRentalPage(product: completeProduct);
        break;
      case 'service':
        targetPage = ItemServicePage(product: completeProduct);
        break;
      default:
        targetPage = ItemFeaturePage(product: completeProduct);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }
}


  Widget _buildFavoriteItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            getValidImageUrl(item),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              );
            },
          ),
        ),
        title: Text(
          item['name'] ?? 'Unnamed Item',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'RM ${item['price'] ?? '0'}',
          style: const TextStyle(
            color: Color(0xFF808569),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _favoriteService.toggleFavorite(item),
        ),
        onTap: () {
          // Navigate to item details page
          Navigator.pushNamed(
            context,
            '/item-details',
            arguments: item,
          );
        },
      ),
    );
  }
}
