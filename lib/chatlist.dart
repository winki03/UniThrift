import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatscreen.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Chat List"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            "You are not logged in. Please log in to view your chat list.",
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat List"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('chats')
            .where('users', arrayContains: currentUser.uid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No chats available.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chatData = chatDocs[index].data() as Map<String, dynamic>;
              final chatId = chatDocs[index].id;

              // Safely extract the other user's ID
              final otherUserId =
                  (chatData['users'] as List<dynamic>).firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => null,
              );

              if (otherUserId == null) {
                return const SizedBox.shrink(); // Skip if no other user
              }

              final lastMessage = chatData['lastMessage'] ?? 'No messages yet';
              final lastMessageTime =
                  chatData['lastMessageTime']?.toDate() ?? DateTime.now();
              final unreadCount =
                  chatData['unreadCount']?[currentUser.uid] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: _db.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (userSnapshot.hasError) {
                    return Center(child: Text("Error: ${userSnapshot.error}"));
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final userName = userData['username'] ?? 'Unknown Username';
                  final profileImage = userData['profileImage'] ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 16.0,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: InkWell(
                      onTap: () async {
                        // Reset unread count for the current user
                        if (unreadCount > 0) {
                          await _db.collection('chats').doc(chatId).update({
                            'unreadCount.${currentUser.uid}': 0,
                          });
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(chatId: chatId),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24, // Smaller size for avatar
                            backgroundImage: profileImage.isNotEmpty
                                ? NetworkImage(profileImage)
                                : const AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                          ),
                          const SizedBox(width: 12), // Adjusted spacing
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${lastMessageTime.hour.toString().padLeft(2, '0')}:${lastMessageTime.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 8.0),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
