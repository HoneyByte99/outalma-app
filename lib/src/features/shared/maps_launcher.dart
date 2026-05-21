import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external maps app with directions to the given coordinates.
/// Origin is left unspecified so the maps app uses the user's current GPS.
///
/// On iOS we probe Google Maps / Waze via their URL schemes; if more than one
/// is available we let the user pick. On Android the OS provides a chooser
/// for the universal `https://www.google.com/maps/dir/` URL, so we open it
/// directly.
Future<void> openDirections(
  BuildContext context, {
  required double destLat,
  required double destLng,
  String? destLabel,
}) async {
  final universal = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$destLat,$destLng'
    '&travelmode=driving',
  );

  if (kIsWeb) {
    await launchUrl(universal, mode: LaunchMode.externalApplication);
    return;
  }

  if (Platform.isIOS) {
    final options = await _availableIosOptions(
      destLat: destLat,
      destLng: destLng,
      destLabel: destLabel,
    );
    if (options.isEmpty) {
      // Fall back to Apple Plans web URL (always works on iOS).
      await launchUrl(
        Uri.parse('https://maps.apple.com/?daddr=$destLat,$destLng'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if (options.length == 1) {
      await launchUrl(options.first.uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    final picked = await _pickMapsApp(context, options);
    if (picked != null) {
      await launchUrl(picked.uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  // Android (and other platforms): the OS chooser will appear for the
  // universal URL when several map apps can handle it.
  await launchUrl(universal, mode: LaunchMode.externalApplication);
}

class _MapsOption {
  const _MapsOption({
    required this.label,
    required this.icon,
    required this.uri,
  });
  final String label;
  final IconData icon;
  final Uri uri;
}

Future<List<_MapsOption>> _availableIosOptions({
  required double destLat,
  required double destLng,
  String? destLabel,
}) async {
  final results = <_MapsOption>[];

  // Apple Plans is always present on iOS.
  results.add(
    _MapsOption(
      label: 'Plans (Apple)',
      icon: Icons.map_outlined,
      uri: Uri.parse('https://maps.apple.com/?daddr=$destLat,$destLng'),
    ),
  );

  final googleScheme = Uri.parse(
    'comgooglemaps://?daddr=$destLat,$destLng&directionsmode=driving',
  );
  if (await canLaunchUrl(googleScheme)) {
    results.add(
      _MapsOption(
        label: 'Google Maps',
        icon: Icons.navigation_outlined,
        uri: googleScheme,
      ),
    );
  }

  final wazeScheme = Uri.parse(
    'waze://?ll=$destLat,$destLng&navigate=yes',
  );
  if (await canLaunchUrl(wazeScheme)) {
    results.add(
      _MapsOption(
        label: 'Waze',
        icon: Icons.alt_route_outlined,
        uri: wazeScheme,
      ),
    );
  }

  return results;
}

Future<_MapsOption?> _pickMapsApp(
  BuildContext context,
  List<_MapsOption> options,
) {
  return showModalBottomSheet<_MapsOption>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ouvrir avec',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            for (final opt in options)
              ListTile(
                leading: Icon(opt.icon),
                title: Text(opt.label),
                onTap: () => Navigator.of(ctx).pop(opt),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
