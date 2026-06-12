import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../domain/models/service_zone.dart';
import '../shared/maps_launcher.dart';

/// Read-only map showing every [ServiceZone] of a service as a circle whose
/// radius matches the zone's coverage. Static (no gestures) so it doesn't
/// fight the parent scroll; the parent can opt-in to interactive mode.
class ServiceZonesMap extends StatefulWidget {
  const ServiceZonesMap({
    super.key,
    required this.zones,
    this.height = 180,
    this.interactive = false,
  });

  final List<ServiceZone> zones;
  final double height;
  final bool interactive;

  @override
  State<ServiceZonesMap> createState() => _ServiceZonesMapState();
}

class _ServiceZonesMapState extends State<ServiceZonesMap> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final zones = widget.zones
        .where((z) => z.latitude != 0 || z.longitude != 0)
        .toList();

    if (zones.isEmpty) return const SizedBox.shrink();

    // Build markers + circles for each zone.
    final markers = <Marker>{};
    final circles = <Circle>{};
    LatLng? primary;
    String? primaryLabel;
    double swLat = 90, swLng = 180, neLat = -90, neLng = -180;
    for (final z in zones) {
      final pos = LatLng(z.latitude, z.longitude);
      primary ??= pos;
      primaryLabel ??= z.label;
      markers.add(
        Marker(
          markerId: MarkerId('zone-${z.label}-${z.latitude}-${z.longitude}'),
          position: pos,
          infoWindow: InfoWindow(
            title: z.label,
            snippet: z.radiusKm > 0 ? '${z.radiusKm} km' : null,
          ),
        ),
      );
      if (z.radiusKm > 0) {
        circles.add(
          Circle(
            circleId: CircleId(
              'circle-${z.label}-${z.latitude}-${z.longitude}',
            ),
            center: pos,
            radius: z.radiusKm * 1000.0,
            fillColor: oc.primary.withValues(alpha: 0.12),
            strokeColor: oc.primary.withValues(alpha: 0.6),
            strokeWidth: 2,
          ),
        );
      }
      // Expand a naive bounding box (good enough for fitBounds).
      swLat = swLat < z.latitude ? swLat : z.latitude;
      swLng = swLng < z.longitude ? swLng : z.longitude;
      neLat = neLat > z.latitude ? neLat : z.latitude;
      neLng = neLng > z.longitude ? neLng : z.longitude;
    }

    final l10n = AppLocalizations.of(context)!;
    final mapTarget = primary ?? const LatLng(46.2276, 2.2137); // France center
    void openInMaps() => openLocation(
      context,
      lat: mapTarget.latitude,
      lng: mapTarget.longitude,
      label: primaryLabel,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: mapTarget,
                  zoom: 10,
                ),
                markers: markers,
                circles: circles,
                // Tapping the map opens it in the device's maps app — the
                // embedded tiles don't render on the iOS Simulator, and a real
                // map is more useful than a static preview anyway.
                onTap: (_) => openInMaps(),
                // Defensive disabling of gestures unless caller opts in. Keeps the
                // map a "decorative chart" embedded in a scrollable detail page.
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: widget.interactive,
                scrollGesturesEnabled: widget.interactive,
                tiltGesturesEnabled: widget.interactive,
                zoomGesturesEnabled: widget.interactive,
                liteModeEnabled: true,
                onMapCreated: (controller) async {
                  _controller = controller;
                  if (zones.length > 1) {
                    // Defer to next frame so the map is laid out before we fit.
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted) return;
                      await _controller?.animateCamera(
                        CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                            southwest: LatLng(swLat, swLng),
                            northeast: LatLng(neLat, neLng),
                          ),
                          48, // padding in logical pixels
                        ),
                      );
                    });
                  }
                },
              ),
            ),
            // Discoverable affordance: a real map is one tap away even when the
            // embedded tiles are grey (iOS Simulator) — the whole map is also
            // tappable.
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: oc.cardSurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  onTap: openInMaps,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      border: Border.all(color: oc.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 16, color: oc.primary),
                        const SizedBox(width: 6),
                        Text(
                          l10n.serviceViewOnMap,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: oc.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
