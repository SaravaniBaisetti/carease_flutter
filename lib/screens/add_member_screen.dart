import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class AddMemberScreen extends StatefulWidget {
  final String clusterId;

  const AddMemberScreen({super.key, required this.clusterId});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.clusterId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('cluster_invite_copied'))),
    );
  }

  Future<String> _getUserName(String uid) async {
    try {
      final profileDoc = await _firestore.collection('users').doc(uid).collection('profile').doc(uid).get();
      if (profileDoc.exists && profileDoc.data()!.containsKey('name') && profileDoc.data()!['name'].toString().isNotEmpty) {
        return profileDoc.data()!['name'];
      }
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('name') && userDoc.data()!['name'].toString().isNotEmpty) {
        return userDoc.data()!['name'];
      }
    } catch (e) {
      debugPrint('Error fetching name for $uid: $e');
    }
    return '${tr('unknown_user')} ($uid)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('cluster_members_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.share, size: 40, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(tr('cluster_invite_code'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        widget.clusterId,
                        style: const TextStyle(fontSize: 24, letterSpacing: 2, color: Colors.blue, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy),
                      label: Text(tr('copy_invite_code')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('share_code_desc'),
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(tr('current_members'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 16),
            
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('elderClusters').doc(widget.clusterId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text(tr('cluster_data_not_found'));
                }
                
                final clusterData = snapshot.data!.data() as Map<String, dynamic>;
                final elderId = clusterData['elderId'];
                final caregiverId = clusterData['primaryCaregiverId'];
                final familyMembers = List<String>.from(clusterData['familyMembers'] ?? []);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (elderId != null) ...[
                      Text(tr('elder_label'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                      _buildMemberTile(elderId, Icons.elderly, Colors.deepPurple),
                      const SizedBox(height: 12),
                    ],
                    
                    Text(tr('primary_caregiver_label'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    if (caregiverId != null)
                      _buildMemberTile(caregiverId, Icons.medical_services, Colors.teal)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(tr('no_caregiver_assigned'), style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 12),

                    Text(tr('family_members_label'), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    if (familyMembers.isNotEmpty)
                      ...familyMembers.map((uid) => _buildMemberTile(uid, Icons.family_restroom, Colors.orange)).toList()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(tr('no_family_members'), style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(String uid, IconData icon, Color color) {
    return FutureBuilder<String>(
      future: _getUserName(uid),
      builder: (context, snapshot) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8, top: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            title: Text(snapshot.data ?? tr('loading')),
            subtitle: Text('${tr('id_prefix')}${uid.substring(0, 8)}...', style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
