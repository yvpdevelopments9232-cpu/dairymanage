import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/display_mode_provider.dart';

class DesktopWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final double minWidth;

  const DesktopWrapper({
    super.key,
    required this.child,
    this.minWidth = 1000,
  });

  @override
  ConsumerState<DesktopWrapper> createState() => _DesktopWrapperState();
}

class _DesktopWrapperState extends ConsumerState<DesktopWrapper> {
  late final TransformationController _transformationController;
  double _currentScale = 1.0;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.storage[0];
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() => _currentScale = scale);
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomTo(double targetScale) {
    HapticFeedback.selectionClick();
    _transformationController.value = Matrix4.diagonal3Values(targetScale, targetScale, targetScale);
  }

  void _zoomIn() {
    final newScale = (_currentScale + 0.15).clamp(0.25, 2.50);
    _zoomTo(newScale);
  }

  void _zoomOut() {
    final newScale = (_currentScale - 0.15).clamp(0.25, 2.50);
    _zoomTo(newScale);
  }

  void _zoomFit(double screenWidth) {
    final fitScale = (screenWidth / widget.minWidth).clamp(0.25, 1.0);
    _zoomTo(fitScale);
  }

  void _zoomReset() {
    _zoomTo(1.0);
  }

  void _toggleDoubleTap(double screenWidth) {
    final fitScale = (screenWidth / widget.minWidth).clamp(0.25, 1.0);
    if ((_currentScale - 1.0).abs() < 0.08) {
      // If at 100%, zoom out to fit all columns!
      _zoomTo(fitScale);
    } else {
      // If at fit or zoomed out, return to 100%
      _zoomTo(1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(displayModeProvider);

    // In Mobile Mode: bypass the 1000px Desktop canvas and InteractiveViewer zoom wrapper!
    // The child widgets adapt natively and responsively to the mobile viewport.
    if (displayMode == DisplayMode.mobile) {
      return widget.child;
    }

    // In Previous / Desktop Mode:
    // Exactly preserves existing zooming logic, pinch-to-zoom, floating toolbar (+, -, %, Fit, 100%), and 1000px canvas!
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // On desktop screens (>= 1000px), render normally without any zoom wrappers
    if (screenWidth >= widget.minWidth) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;

        return Stack(
          children: [
            // Two-finger pinch-to-zoom & Pan container wrapping the 1000px canvas directly
            GestureDetector(
              onDoubleTap: () => _toggleDoubleTap(screenWidth),
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.25, // Start from 25% as requested
                maxScale: 2.50, // Up to 250%
                scaleEnabled: true,
                panEnabled: true,
                constrained: false, // Unconstrained child allows full 1000px desktop canvas
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: widget.minWidth,
                  height: viewportHeight,
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      size: Size(widget.minWidth, viewportHeight),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),

            // Floating Mobile Zoom Controls Toolbar
            Positioned(
              bottom: 24,
              right: 16,
              child: SafeArea(
                child: _isCollapsed
                    ? Material(
                        elevation: 6,
                        shape: const CircleBorder(),
                        color: Colors.black87,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _isCollapsed = false),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      )
                    : Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.black.withValues(alpha: 0.85),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Zoom Out Button
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 20),
                                tooltip: 'Zoom Out (झूम कमी करा)',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: _zoomOut,
                              ),
                              const SizedBox(width: 4),

                              // Zoom percentage (tap to toggle 100% / Fit)
                              GestureDetector(
                                onTap: () => _toggleDoubleTap(screenWidth),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(_currentScale * 100).round()}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // Zoom In Button
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                                tooltip: 'Zoom In (झूम वाढवा)',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: _zoomIn,
                              ),

                              // Divider
                              Container(height: 16, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),

                              // Fit to screen button (fits all 1000px columns without white space!)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _zoomFit(screenWidth),
                                child: const Text('Fit', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),

                              // 100% Reset button (exact native Windows size!)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _zoomReset,
                                child: const Text('100%', style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),

                              // Minimize/Hide button
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                                tooltip: 'Hide Controls',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() => _isCollapsed = true),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
