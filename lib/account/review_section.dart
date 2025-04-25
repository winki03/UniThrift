import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

class ReviewsSection extends StatefulWidget {
  final String userId; // Add userId to specify whose reviews to display

  const ReviewsSection({Key? key, required this.userId}) : super(key: key);

  @override
  _ReviewsSectionState createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  int _selectedTabIndex = 0;

  Stream<QuerySnapshot> getReviewsStream() {
    final reviewsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId) // Use userId from the widget
        .collection('reviewsglobal');

    if (_selectedTabIndex == 1) {
      return reviewsCollection.where('role', isEqualTo: 'seller').snapshots();
    } else if (_selectedTabIndex == 2) {
      return reviewsCollection.where('role', isEqualTo: 'buyer').snapshots();
    } else {
      return reviewsCollection
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(//yy line 38-53
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Reviews',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
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
        _buildTab(0, 'All'),
        _buildTab(1, 'Seller'),
        _buildTab(2, 'Buyer'),
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

  Widget _buildContentSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: getReviewsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No reviews available."));
        }

        final reviews = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index].data() as Map<String, dynamic>;
            return ReviewCard(review: review);
          },
        );
      },
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const ReviewCard({Key? key, required this.review}) : super(key: key);

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final dateTime = timestamp.toDate();
    return DateFormat('y MMM d • h:mm a')
        .format(dateTime); // Example: Dec 14 • 3:00 PM
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (review['productImage'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      review['productImage'],
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['productName'] ?? "Unknown Product",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Price: RM ${review['productPrice']?.toStringAsFixed(2) ?? 'N/A'}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.star, color: Colors.yellow, size: 18),
                Text(
                  "${review['rating'] ?? 'N/A'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review['reviewText'] ?? "No review text",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "By ${review['reviewerName'] ?? 'Anonymous'} (${review['role']?.toUpperCase() ?? 'N/A'})",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatTimestamp(review['timestamp'] as Timestamp?),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
