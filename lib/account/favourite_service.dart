import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

 Future<bool> toggleFavorite(Map<String, dynamic> product) async {
  final user = _auth.currentUser;
  if (user == null) return false;

  final favoriteRef = _firestore
      .collection('users')
      .doc(user.uid)
      .collection('favorites')
      .doc(product['productID']);

  final doc = await favoriteRef.get();

  if (doc.exists) {
    // Remove from favorites
    await favoriteRef.delete();
    return false;
  } else {
    // Add to favorites with all necessary fields
    await favoriteRef.set({
      'productID': product['productID'],
      'name': product['name'],
      'price': product['price'],
      'imageUrl1': getValidImageUrl(product),
      'details': product['details'],
      'category': product['category'],
      'type': product['type'],
      'sellerUserId': product['userId'],
      'sellerName': product['username'],
      'condition': product['condition'], // Added
      'brand': product['brand'], // Added
      'timestamp': product['timestamp'] ?? FieldValue.serverTimestamp(),
      'createdAt': product['createdAt'] ?? FieldValue.serverTimestamp(),
      'addedAt': FieldValue.serverTimestamp(),
      // Add any other fields you need to preserve
      'imageUrl2': product['imageUrl2'],
      'imageUrl3': product['imageUrl3'],
      'userEmail': product['userEmail']
    });
    return true;
  }
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

  // Check if item is favorited
  Stream<bool> isFavorite(String productId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(productId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Add this method to your existing FavoriteService class
  Future<bool> isItemFavorited(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(productId)
        .get();

    return doc.exists;
  }
}
