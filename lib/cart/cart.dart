import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unithrift/checkout/chekout.dart';
import 'package:unithrift/navigation%20bar/bottom_navbar.dart';

class Cart extends StatefulWidget {
  const Cart(this.noAppBar, {super.key});
  final bool noAppBar;

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  int _selectedTabIndex = 0;
  int _selectedIndex = 3;
  String? sellerName;
String? sellerProfileImage;

  final Set<String> _deletingItems = {};

  Stream<List<Map<String, dynamic>>> getCartItems() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('cart')
        .snapshots()
        .asyncMap((cartSnapshot) async {
      List<Map<String, dynamic>> cartItems = [];

      for (var doc in cartSnapshot.docs) {
        if (!_deletingItems.contains(doc.id)) {
          var cartData = doc.data();
          cartData['docId'] = doc.id;

          // Fetch seller info
          if (cartData['sellerUserId'] != null) {
            final sellerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(cartData['sellerUserId'])
                .get();

            if (sellerDoc.exists) {
               cartData['sellerName'] = sellerDoc.data()?['username'];
            cartData['sellerProfileImage'] = sellerDoc.data()?['profileImage'];
            }
          }

          cartItems.add(cartData);
        }
      }
      return cartItems;
    });
  }



Future<String?> getSellerProfileImage(String sellerId) async {
  final sellerDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(sellerId)
      .get();
  return sellerDoc.data()?['profileImage'];
}


  String getValidImageUrl(Map<String, dynamic> item) {
    // List of possible image URLs in priority order
    final imageUrls = [item['imageUrl1'], item['imageUrl2'], item['imageUrl3']];

    // Return first valid image URL
    for (String? url in imageUrls) {
      if (url != null &&
          url.isNotEmpty &&
          !url.toLowerCase().endsWith('.mp4')) {
        return url;
      }
    }

    return 'https://via.placeholder.com/100';
  }

  String _getRateType(String? category) {
    switch (category?.toLowerCase()) {
      case 'Laundry Service':
        return '/ piece';
      case 'Delivery Service':
        return '/ km';
      case 'Tutoring Service':
        return '/ hour';
      case 'Printing Service':
        return '/ piece';
      default:
        return '/ service';
    }
  }

  void _removeFromCart(String docId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
        return;
      }

      setState(() {
        _deletingItems.add(docId);
      });

      // Use document ID directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .doc(docId)
          .delete();

      setState(() {
        _deletingItems.remove(docId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item removed from cart'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _deletingItems.remove(docId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing from cart: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      commonNavigate(context, index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return (widget.noAppBar)
        ? Scaffold(
            body: Column(
              children: [
                _buildTabRow(),
                const SizedBox(height: 10),
                Expanded(child: _buildContentSection()),
              ],
            ),
          )
        : Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart),
                  SizedBox(width: 8),
                  Text('My Cart'),
                ],
              ),
              centerTitle: true,
            ),
            body: Column(
              children: [
                _buildTabRow(),
                const SizedBox(height: 10),
                Expanded(child: _buildContentSection()),
              ],
            ),
          );
  }

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
                color: _selectedTabIndex == index ? Colors.black : Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getCartItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Your cart is empty'));
        }

        // Group items by type and seller
        Map<String, Map<String, List<Map<String, dynamic>>>> groupedItems = {
          'feature': {},
          'rental': {},
          'service': {}
        };

        for (var item in snapshot.data!) {
          String type = item['type'] ?? 'feature';
          String seller = item['sellerName'] ?? 'Unknown Seller';
          groupedItems[type]!.putIfAbsent(seller, () => []).add(item);
        }

        // Determine which items to show based on selected tab
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

        if (groupedItems[selectedType]!.isEmpty) {
          return Center(
            child: Text(
              'No ${sectionTitle.toLowerCase()} in cart',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (var seller in groupedItems[selectedType]!.keys)
              _buildSellerCartSection(
                seller,
                groupedItems[selectedType]![seller]!,
              ),
          ],
        );
      },
    );
  }

  Widget _buildSellerCartSection(
      String seller, List<Map<String, dynamic>> items) {
    double totalPrice = items.fold(0.0, (sum, item) {
      if (item['type'] == 'rental') {
        // Add null checks for rental dates
        final startRentalDate = item['startRentalDate'];
        final endRentalDate = item['endRentalDate'];

        if (startRentalDate != null && endRentalDate != null) {
          List<String> startParts = startRentalDate.split('/');
          List<String> endParts = endRentalDate.split('/');

          DateTime startDate = DateTime(int.parse(startParts[2]),
              int.parse(startParts[1]), int.parse(startParts[0]));

          DateTime endDate = DateTime(int.parse(endParts[2]),
              int.parse(endParts[1]), int.parse(endParts[0]));

          int days = endDate.difference(startDate).inDays + 1;
          return sum + (double.parse(item['price'].toString()) * days);
        }
      } else if (item['type'] == 'service') {
        return sum +
            (double.parse(item['price'].toString()) * (item['quantity'] ?? 1));
      }
      return sum + double.parse(item['price'].toString());
    });

    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
  padding: const EdgeInsets.all(10),
  child: Row(
    children: [
      FutureBuilder<String?>(
        future: getSellerProfileImage(items[0]['sellerUserId']),
        builder: (context, snapshot) {
          return CircleAvatar(
            backgroundColor: const Color(0xFF808569),
            radius: 20,
            backgroundImage: snapshot.data != null ? NetworkImage(snapshot.data!) : null,
            child: (!snapshot.hasData || snapshot.data == null) 
              ? Text(
                  seller.isNotEmpty ? seller[0].toUpperCase() : '',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
          );
        },
      ),
      const SizedBox(width: 10),
      Text(
        seller ?? 'Seller Name',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
)
,
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        getValidImageUrl(item),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported,
                              size: 50);
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Unknown Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Color.fromARGB(255, 74, 74, 74),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Show different information based on the type
                          // In your _buildSellerCartSection widget, modify the rental dates display section:

                          if (_selectedTabIndex == 1) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Rental Duration',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 66, 66, 66),
                                fontSize: 9,
                              ),
                            ),
                            if (item['startRentalDate'] != null &&
                                item['endRentalDate'] != null)
                              Text(
                                '${item['startRentalDate']} - ${item['endRentalDate']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.normal,
                                  color: Color.fromARGB(255, 94, 94, 94),
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 15),
                            Builder(
                              builder: (context) {
                                if (item['startRentalDate'] == null ||
                                    item['endRentalDate'] == null) {
                                  return const Text('Invalid rental dates');
                                }

                                List<String> startParts =
                                    item['startRentalDate'].split('/');
                                List<String> endParts =
                                    item['endRentalDate'].split('/');

                                DateTime startDate = DateTime(
                                    int.parse(startParts[2]),
                                    int.parse(startParts[1]),
                                    int.parse(startParts[0]));
                                DateTime endDate = DateTime(
                                    int.parse(endParts[2]),
                                    int.parse(endParts[1]),
                                    int.parse(endParts[0]));

                                int days =
                                    endDate.difference(startDate).inDays + 1;
                                double totalPrice =
                                    double.parse(item['price'].toString()) *
                                        days;

                                return RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            'RM ${totalPrice.toStringAsFixed(2)} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          fontSize: 15,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '/ $days days',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color:
                                              Color.fromARGB(255, 94, 94, 94),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ] else if (_selectedTabIndex == 2) ...[
                            const SizedBox(height: 8),
                            // Service Date
                            const Text(
                              'Service Date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 66, 66, 66),
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              item['serviceDate'] is Timestamp
                                  ? '${item['serviceDate'].toDate().day}/${item['serviceDate'].toDate().month}/${item['serviceDate'].toDate().year}'
                                  : item['serviceDate'] ?? 'Date not set',
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Color.fromARGB(255, 94, 94, 94),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Price and Rate Type
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        // Calculate total price based on quantity
                                        text:
                                            'RM ${(double.parse(item['price'].toString()) * (item['quantity'] ?? 1)).toStringAsFixed(2)} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '(Quantity: ${item['quantity'] ?? 1})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: Color.fromARGB(255, 94, 94, 94),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              item['condition'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Color.fromARGB(255, 94, 94, 94),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'RM ${item['price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontSize: 15,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Color.fromARGB(255, 113, 113, 113),
                      ),
                      onPressed: () => _removeFromCart(item['docId']),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${items.length} Item${items.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
                Text(
                  'Total: RM ${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Inside _buildSellerCartSection
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutPage(
                      totalAmount: totalPrice,
                      itemCount: items.length,
                      cartItems: items,
                      sellerName: seller,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF808569),
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text(
                'Check Out',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
