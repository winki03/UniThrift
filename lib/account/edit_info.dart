import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

  String selectedGender = "Boy"; // Default value for gender dropdown

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

          fullNameController.text = data['fullName'] ?? ''; // Fetch full name
          usernameController.text = data['username'] ?? '';
          addressController.text = data['address'] ?? '';
          bioController.text = data['bio'] ?? '';
          phoneNumberController.text = data['phoneNumber'] ?? '';
          selectedGender = data['gender'] ?? 'Boy'; // Default to "Boy"
          setState(() {}); // Update the UI
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> updateUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> updatedData = {
          'username': usernameController.text,
          'address': addressController.text,
          'bio': bioController.text,
          'phoneNumber': phoneNumberController.text,
          'gender': selectedGender,
        };

        await _firestore.collection('users').doc(user.uid).update(updatedData);

        Navigator.of(context).pop(updatedData); // Pass updated data back
      }
    } catch (e) {
      print("Error updating user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Edit Information",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              // Full Name Field (Non-editable)
              TextField(
                controller: fullNameController,
                enabled: false, // Disable editing
                decoration: InputDecoration(
                  hintText: "Full Name",
                  filled: true,
                  fillColor: Colors.grey[300], // Slightly darker to show disabled
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Username Field
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  hintText: "Username",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Address Field
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  hintText: "Address",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bio Field
              TextField(
                controller: bioController,
                decoration: InputDecoration(
                  hintText: "Bio",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Phone Number Field
              TextField(
                controller: phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Phone Number",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: selectedGender,
                items: const [
                  DropdownMenuItem(value: "Boy", child: Text("Boy")),
                  DropdownMenuItem(value: "Girl", child: Text("Girl")),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedGender = value!;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Gender",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: updateUserData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C805C),
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
