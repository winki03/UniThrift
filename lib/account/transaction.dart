import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_info.dart';

class TransactionHistoryPage extends StatefulWidget {
  final String userId;  // Accept userId to show transactions for any user

  const TransactionHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  @override
Widget build(BuildContext context) {
  return Scaffold(//yy line19-35
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Transaction History',
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
    body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)  // Use the userId passed to the widget
            .collection('orders')
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No transactions found.'),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var order = orders[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: Image.network(
                    order['imageUrl'] ?? 'https://via.placeholder.com/150',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                  title: Text(order['name'] ?? 'Unknown Product'),
                  subtitle: Text(
                      'Total: RM${order['totalAmount']} • Status: ${order['status']}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OrderInfo(orderId: order['orderId']),  // Navigate to Order Details
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
