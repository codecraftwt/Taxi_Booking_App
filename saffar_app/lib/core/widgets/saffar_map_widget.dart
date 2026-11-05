import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/services/map_service.dart';

class SaffarMapWidget extends StatefulWidget {
  const SaffarMapWidget({
    Key? key,
    this.mapController,
    this.initialCenter = MapConfig.defaultCenter,
    this.initialZoom = MapConfig.defaultZoom,
    this.polylines = const [],
    this.markers = const [],
    this.onTap,
    this.onPositionChanged,
    this.showRecenterButton = true,
    this.recenterLocation,
    this.showZoomControls = false,
    this.showAttribution = true,
    this.isInteractive = true,
  }) : super(key: key);

  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Polyline> polylines;
  final List<Marker> markers;
  final void Function(TapPosition, LatLng)? onTap;
  final void Function(MapCamera, bool)? onPositionChanged;
  final bool showRecenterButton;
  final LatLng? recenterLocation;
  final bool showZoomControls;
  final bool showAttribution;
  final bool isInteractive;

  @override
  State<SaffarMapWidget> createState() => _SaffarMapWidgetState();
}

class _SaffarMapWidgetState extends State<SaffarMapWidget> {
  late final MapController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.mapController != null) {
      _controller = widget.mapController!;
    } else {
      _controller = MapController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _recenter() {
    final target = widget.recenterLocation ?? widget.initialCenter;
    _controller.move(target, widget.initialZoom);
  }

  void _zoomIn() {
    final newZoom = (_controller.camera.zoom + 1.0).clamp(MapConfig.minZoom, MapConfig.maxZoom);
    _controller.move(_controller.camera.center, newZoom);
  }

  void _zoomOut() {
    final newZoom = (_controller.camera.zoom - 1.0).clamp(MapConfig.minZoom, MapConfig.maxZoom);
    _controller.move(_controller.camera.center, newZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. FlutterMap Core
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            interactionOptions: InteractionOptions(
              flags: widget.isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: widget.onTap,
            onPositionChanged: widget.onPositionChanged,
          ),
          children: [
            // Styled Tile Layer with Caching & Headers
            MapService.instance.buildTileLayer(),
            // Polylines Layer
            if (widget.polylines.isNotEmpty)
              PolylineLayer(
                polylines: widget.polylines,
              ),
            // Markers Layer
            if (widget.markers.isNotEmpty)
              MarkerLayer(
                markers: widget.markers,
              ),
          ],
        ),

        // 2. Attribution Widget
        if (widget.showAttribution)
          MapService.instance.buildAttributionWidget(context),

        // 3. Recenter FAB
        if (widget.showRecenterButton)
          Positioned(
            right: 14,
            bottom: widget.showAttribution ? 32 : 14,
            child: FloatingActionButton.small(
              heroTag: 'map_recenter_${widget.hashCode}',
              backgroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: _recenter,
              child: const Icon(
                Icons.my_location_rounded,
                color: Palette.secondary,
                size: 20,
              ),
            ),
          ),

        // 4. Zoom Controls (Optional)
        if (widget.showZoomControls)
          Positioned(
            right: 14,
            top: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.add, size: 20, color: Palette.neutral),
                    onPressed: _zoomIn,
                  ),
                ),
                Container(
                  width: 36,
                  height: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.remove, size: 20, color: Palette.neutral),
                    onPressed: _zoomOut,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

