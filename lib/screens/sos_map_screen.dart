import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SosMapScreen extends StatefulWidget {
  final String clusterId;
  final String elderName;
  final String alertId;
  final bool isLive;

  const SosMapScreen({
    super.key,
    required this.clusterId,
    required this.elderName,
    required this.alertId,
    required this.isLive,
  });

  @override
  State<SosMapScreen> createState() => _SosMapScreenState();
}

class _SosMapScreenState extends State<SosMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isLive) {
      _loadStaticLocation();
    }
  }

  Future<void> _loadStaticLocation() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('alerts')
          .doc(widget.alertId)
          .get();
      
      final data = doc.data();
      if (data != null && data['location'] != null) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(
              data['location']['latitude'],
              data['location']['longitude'],
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading static location: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openGoogleMaps(LatLng location) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Google Maps')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLive ? 'Live Tracking: ${widget.elderName}' : 'SOS Location: ${widget.elderName}'),
        backgroundColor: widget.isLive ? Colors.red[800] : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: widget.isLive ? _buildLiveMap() : _buildStaticMap(),
    );
  }

  Widget _buildStaticMap() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentLocation == null) return const Center(child: Text("Location data not available for this alert."));

    return _buildMapBody(_currentLocation!);
  }

  Widget _buildLiveMap() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('liveLocation')
          .doc('latest')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading live tracking: ${snapshot.error}'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['latitude'] == null) {
           return const Center(child: Text('Awaiting location ping...'));
        }

        final location = LatLng(data['latitude'], data['longitude']);
        
        // Auto-center camera if map is already initialized
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
             _mapController.move(location, 16.0);
          } catch(e) {
             // Map might not be ready on first frame
          }
        });

        return _buildMapBody(location);
      },
    );
  }

  Widget _buildMapBody(LatLng location) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: location,
            initialZoom: 16.0,
            maxZoom: 19.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.careasen.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 50,
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds),
                ),
              ],
            ),
          ],
        ),
        
        // Bottom Info Panel
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: widget.isLive ? Colors.red[50] : Colors.blue[50], shape: BoxShape.circle),
                        child: Icon(widget.isLive ? Icons.sensors : Icons.location_history, color: widget.isLive ? Colors.red : Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.isLive ? "Live SOS Location" : "Last Known Location", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text("${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(location),
                    icon: const Icon(Icons.navigation),
                    label: const Text("Open in Google Maps"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)
                    ),
                  )
                ],
              ),
            ),
          ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
        ),
        
        // Re-center button
        Positioned(
          right: 20,
          bottom: 200, // Above the card
          child: FloatingActionButton(
            heroTag: "recenterBtn",
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () => _mapController.move(location, 16.0),
            child: const Icon(Icons.my_location),
          )
        )
      ],
    );
  }
}
