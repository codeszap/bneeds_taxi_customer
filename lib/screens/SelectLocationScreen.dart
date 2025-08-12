// Required dependencies in pubspec.yaml
// google_maps_webservice: ^0.0.20-nullsafety.5
// flutter_riverpod: any

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

final fromLocationProvider = StateProvider<String>((ref) => 'Current Location');
final toLocationProvider = StateProvider<String>((ref) => '');
final placeQueryProvider = StateProvider<String>((ref) => '');

// Google Places API Key
const String _googleApiKey = 'AIzaSyAWzUqf3Z8xvkjYV7F4gOGBBJ5d_i9HZhs';

final placeSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];

  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_googleApiKey&components=country:in',
  );

  final response = await http.get(url);
  final jsonBody = jsonDecode(response.body);
  print("Map Result: $jsonBody");
  if (jsonBody['status'] == 'OK') {
    return (jsonBody['predictions'] as List)
        .map((e) => e['description'] as String)
        .toList();
  } else {
    throw Exception(
      jsonBody['error_message'] ?? 'Error: ${jsonBody['status']}',
    );
  }
});

class SelectLocationScreen extends ConsumerWidget {
  final String vehTypeId;
  const SelectLocationScreen({super.key, required this.vehTypeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromLocation = ref.watch(fromLocationProvider);
    final toLocation = ref.watch(toLocationProvider);
    final query = ref.watch(placeQueryProvider);
    final suggestionsAsync = ref.watch(placeSuggestionsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationCard(
                title: "From",
                value: fromLocation,
                icon: Icons.my_location,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _ToLocationField(
                initialValue: toLocation,
                onChanged: (value) {
                  ref.read(toLocationProvider.notifier).state = value;
                  ref.read(placeQueryProvider.notifier).state = value;
                },
              ),
              const SizedBox(height: 20),
              _buildMapButton(context, ref),
              const SizedBox(height: 40),
              const Text(
                "\uD83D\uDCCD Recent Locations",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _buildRecentLocationTile(
                context,
                ref,
                location: "Simmakkal",
                subLocation: "Madurai, Madurai Municipal Corporation",
              ),
              _buildRecentLocationTile(
                context,
                ref,
                location: "Periyar Bus Stand",
                subLocation: "Madurai, East Avani Moola Street",
              ),
              _buildRecentLocationTile(
                context,
                ref,
                location: "Madurai Airport",
                subLocation: "Madurai, Airport Road",
              ),
              const SizedBox(height: 10),
              if (query.isNotEmpty)
                suggestionsAsync.when(
                  data: (suggestions) => Column(
                    children: suggestions
                        .map(
                          (s) => _buildRecentLocationTile(
                            context,
                            ref,
                            location: s,
                            subLocation: "Suggested",
                          ),
                        )
                        .toList(),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const Text('Error loading suggestions'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final selectedAddress = await context.push<String>('/select-on-map');
          if (selectedAddress != null && selectedAddress.isNotEmpty) {
            ref.read(toLocationProvider.notifier).state = selectedAddress;
            ref.read(placeQueryProvider.notifier).state =
                ''; // Clear suggestion box
          }
        },
        icon: const Icon(Icons.map_outlined),
        label: const Text("Select on Map"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentLocationTile(
    BuildContext context,
    WidgetRef ref, {
    required String location,
    required String subLocation,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(Icons.place_outlined, color: Colors.deepPurple),
        title: Text(
          location,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subLocation,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        onTap: () {
          ref.read(toLocationProvider.notifier).state = location;
          ref.read(placeQueryProvider.notifier).state = '';
          print("Selected vehicle type: $vehTypeId");
          context.push('/service-options', extra: vehTypeId);
        },
      ),
    );
  }
}

class _ToLocationField extends ConsumerStatefulWidget {
  final String initialValue;
  final Function(String) onChanged;

  const _ToLocationField({
    required this.initialValue,
    required this.onChanged,
    super.key,
  });

  @override
  ConsumerState<_ToLocationField> createState() => _ToLocationFieldState();
}

class _ToLocationFieldState extends ConsumerState<_ToLocationField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toLocation = ref.watch(toLocationProvider);

    // Sync controller text only if it's different
    if (_controller.text != toLocation) {
      _controller.value = TextEditingValue(
        text: toLocation,
        selection: TextSelection.collapsed(offset: toLocation.length),
      );
    }

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: "To",
        prefixIcon: const Icon(Icons.place_outlined, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.grey[100],
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
