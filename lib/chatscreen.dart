import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  Future<void> _sendMessage(String text, [String? imageUrl]) async {
    await _firestoreService.sendMessage(
      widget.chatId,
      currentUser!.uid,
      text,
      imageUrl: imageUrl,
    );
    _controller.clear();
  }

  Future<void> _sendImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final imageUrl = await _firestoreService.uploadImage(pickedFile.path);
      _sendMessage('', imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .get(),
          builder: (context, chatSnapshot) {
            if (chatSnapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(color: Colors.white);
            }

            if (!chatSnapshot.hasData || chatSnapshot.data == null) {
              return const Text('Chat');
            }

            // Extract the other user's ID
            final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
            final chatUsers = chatData['users'] as List<dynamic>;
            final otherUserId = chatUsers.firstWhere(
              (id) => id != currentUser?.uid,
              orElse: () => null,
            );

            if (otherUserId == null) {
              return const Text('Chat');
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(color: Colors.white);
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const Text('Chat');
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final profileImage = userData['profileImage'] ?? '';
                final username = userData['username'] ?? 'Unknown User';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: profileImage.isNotEmpty
                          ? NetworkImage(profileImage)
                          : null,
                      backgroundColor: Colors.grey,
                      child: profileImage.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      username,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                );
              },
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Product information banner
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data == null) {
                return const SizedBox.shrink();
              }

              final chatData = snapshot.data!.data() as Map<String, dynamic>;

              if (chatData['contextType'] == 'sales' ||
                  chatData['contextType'] == 'orders') {
                // Sales page chat
                return Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      if (chatData['productImage'] != null)
                        Image.network(
                          chatData['productImage'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chatData['productName'] ?? 'Product',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Order ID: ${chatData['orderId']}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              } else if (chatData['contextType'] == 'product') {
                // Product page chat
                return Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      if (chatData['productImage'] != null)
                        Image.network(
                          chatData['productImage'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chatData['productName'] ?? 'Product',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Product ID: ${chatData['productId']}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),

          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: messages.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final message = messages[index].data();
                    final messageText = message['text'] ?? '';
                    final imageUrl = message['imageUrl'];
                    final timestamp =
                        message['timestamp']?.toDate() ?? DateTime.now();
                    final isCurrentUser = message['userId'] == currentUser?.uid;

                    return Align(
                      alignment: isCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? const Color(0xFFA4AA8B)
                              : const Color(0xFFF2F3EC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl != null)
                              GestureDetector(
                                onTap: () {
                                  // Show enlarged image in full screen
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      backgroundColor: Colors.black,
                                      child: Stack(
                                        children: [
                                          InteractiveViewer(
                                            child: Image.network(imageUrl),
                                          ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: IconButton(
                                              icon: const Icon(Icons.close,
                                                  color: Colors.white),
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.network(
                                    imageUrl,
                                    width: 180, // Set your desired max width
                                    height: 240, // Set your desired max height
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            if (messageText.isNotEmpty)
                              Text(
                                messageText,
                                style: TextStyle(
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.black),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 5.0), // Add top padding
                              child: Text(
                                "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        _sendMessage(_controller.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
