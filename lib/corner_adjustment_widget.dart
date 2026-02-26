import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CornerAdjustmentWidget extends StatefulWidget {
  final File imageFile;
  final int imageWidth;
  final int imageHeight;
  final Map<String, List<int>> initialCorners;
  final Function(Map<String, List<int>>) onCornersConfirmed;

  const CornerAdjustmentWidget({
    super.key,
    required this.imageFile,
    required this.imageWidth,
    required this.imageHeight,
    required this.initialCorners,
    required this.onCornersConfirmed,
  });

  @override
  State<CornerAdjustmentWidget> createState() => _CornerAdjustmentWidgetState();
}

class _CornerAdjustmentWidgetState extends State<CornerAdjustmentWidget> {
  // Corner positions in IMAGE coordinates (pixels in original image)
  late Offset topLeft;
  late Offset topRight;
  late Offset bottomLeft;
  late Offset bottomRight;

  // Dragging state
  String? _draggingCorner;
  Offset? _fingerScreenPosition;

  // Display parameters (calculated based on container size)
  double _displayScale = 1.0;
  double _displayOffsetX = 0.0;
  double _displayOffsetY = 0.0;
  double _displayWidth = 0.0;
  double _displayHeight = 0.0;
  Size _containerSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _initializeCorners();
  }

  void _initializeCorners() {
    topLeft = Offset(
      widget.initialCorners['top_left']![0].toDouble(),
      widget.initialCorners['top_left']![1].toDouble(),
    );
    topRight = Offset(
      widget.initialCorners['top_right']![0].toDouble(),
      widget.initialCorners['top_right']![1].toDouble(),
    );
    bottomLeft = Offset(
      widget.initialCorners['bottom_left']![0].toDouble(),
      widget.initialCorners['bottom_left']![1].toDouble(),
    );
    bottomRight = Offset(
      widget.initialCorners['bottom_right']![0].toDouble(),
      widget.initialCorners['bottom_right']![1].toDouble(),
    );
  }

  void _calculateDisplayParams(Size containerSize) {
    _containerSize = containerSize;
    
    final double imageAspect = widget.imageWidth / widget.imageHeight;
    final double containerAspect = containerSize.width / containerSize.height;

    if (imageAspect > containerAspect) {
      // Image is wider - fills width
      _displayWidth = containerSize.width;
      _displayHeight = containerSize.width / imageAspect;
      _displayOffsetX = 0;
      _displayOffsetY = (containerSize.height - _displayHeight) / 2;
    } else {
      // Image is taller - fills height
      _displayHeight = containerSize.height;
      _displayWidth = containerSize.height * imageAspect;
      _displayOffsetX = (containerSize.width - _displayWidth) / 2;
      _displayOffsetY = 0;
    }

    _displayScale = _displayWidth / widget.imageWidth;
  }

  // Convert IMAGE coordinates to SCREEN coordinates
  Offset _imageToScreen(Offset imagePoint) {
    return Offset(
      _displayOffsetX + imagePoint.dx * _displayScale,
      _displayOffsetY + imagePoint.dy * _displayScale,
    );
  }

  // Convert SCREEN coordinates to IMAGE coordinates
  Offset _screenToImage(Offset screenPoint) {
    final double imageX = (screenPoint.dx - _displayOffsetX) / _displayScale;
    final double imageY = (screenPoint.dy - _displayOffsetY) / _displayScale;
    
    // Clamp to valid image bounds
    return Offset(
      imageX.clamp(0, widget.imageWidth.toDouble()),
      imageY.clamp(0, widget.imageHeight.toDouble()),
    );
  }

  String? _hitTestCorner(Offset screenPos) {
    const double hitRadius = 35;

    if ((_imageToScreen(topLeft) - screenPos).distance < hitRadius) return 'top_left';
    if ((_imageToScreen(topRight) - screenPos).distance < hitRadius) return 'top_right';
    if ((_imageToScreen(bottomLeft) - screenPos).distance < hitRadius) return 'bottom_left';
    if ((_imageToScreen(bottomRight) - screenPos).distance < hitRadius) return 'bottom_right';
    
    return null;
  }

  void _setCorner(String corner, Offset imagePos) {
    setState(() {
      switch (corner) {
        case 'top_left':
          topLeft = imagePos;
          break;
        case 'top_right':
          topRight = imagePos;
          break;
        case 'bottom_left':
          bottomLeft = imagePos;
          break;
        case 'bottom_right':
          bottomRight = imagePos;
          break;
      }
    });
  }

  Offset _getCorner(String corner) {
    switch (corner) {
      case 'top_left': return topLeft;
      case 'top_right': return topRight;
      case 'bottom_left': return bottomLeft;
      case 'bottom_right': return bottomRight;
      default: return Offset.zero;
    }
  }

  Color _getCornerColor(String corner) {
    switch (corner) {
      case 'top_left': return Colors.red;
      case 'top_right': return Colors.blue;
      case 'bottom_left': return Colors.green;
      case 'bottom_right': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Map<String, List<int>> _getFinalCorners() {
    return {
      'top_left': [topLeft.dx.round(), topLeft.dy.round()],
      'top_right': [topRight.dx.round(), topRight.dy.round()],
      'bottom_left': [bottomLeft.dx.round(), bottomLeft.dy.round()],
      'bottom_right': [bottomRight.dx.round(), bottomRight.dy.round()],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drag corners. Crosshair in magnifier = exact position.',
                  style: TextStyle(color: Colors.blue[700]!.withOpacity(0.8), fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Image with corners
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _calculateDisplayParams(Size(constraints.maxWidth, constraints.maxHeight));
                  
                  return GestureDetector(
                    onPanStart: (details) {
                      final corner = _hitTestCorner(details.localPosition);
                      if (corner != null) {
                        setState(() {
                          _draggingCorner = corner;
                          _fingerScreenPosition = details.localPosition;
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      if (_draggingCorner != null) {
                        final imagePos = _screenToImage(details.localPosition);
                        _setCorner(_draggingCorner!, imagePos);
                        setState(() {
                          _fingerScreenPosition = details.localPosition;
                        });
                      }
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _draggingCorner = null;
                        _fingerScreenPosition = null;
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Base image
                        Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),

                        // Quadrilateral overlay
                        CustomPaint(
                          painter: _QuadPainter(
                            tl: _imageToScreen(topLeft),
                            tr: _imageToScreen(topRight),
                            bl: _imageToScreen(bottomLeft),
                            br: _imageToScreen(bottomRight),
                          ),
                        ),

                        // Corner handles (hide dragging one)
                        if (_draggingCorner != 'top_left')
                          _buildHandle(topLeft, Colors.red, 'TL'),
                        if (_draggingCorner != 'top_right')
                          _buildHandle(topRight, Colors.blue, 'TR'),
                        if (_draggingCorner != 'bottom_left')
                          _buildHandle(bottomLeft, Colors.green, 'BL'),
                        if (_draggingCorner != 'bottom_right')
                          _buildHandle(bottomRight, Colors.orange, 'BR'),

                        // Magnifier (only while dragging)
                        if (_draggingCorner != null)
                          _buildMagnifier(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _initializeCorners()),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => widget.onCornersConfirmed(_getFinalCorners()),
                icon: const Icon(Icons.check),
                label: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHandle(Offset imagePos, Color color, String label) {
    final screenPos = _imageToScreen(imagePos);
    return Positioned(
      left: screenPos.dx - 12,
      top: screenPos.dy - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifier() {
    if (_draggingCorner == null) return const SizedBox.shrink();

    const double size = 130;
    const double zoom = 3.0;
    
    final corner = _getCorner(_draggingCorner!);
    final color = _getCornerColor(_draggingCorner!);
    final screenPos = _imageToScreen(corner);

    // Position magnifier - top-left of screen, or top-right if dragging left corners
    double left = 16;
    double top = 16;
    if (_draggingCorner == 'top_left' || _draggingCorner == 'bottom_left') {
      left = _containerSize.width - size - 16;
    }

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              // Zoomed image centered on corner point
              Positioned(
                left: size / 2 - screenPos.dx * zoom,
                top: size / 2 - screenPos.dy * zoom,
                child: SizedBox(
                  width: _containerSize.width * zoom,
                  height: _containerSize.height * zoom,
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              // Crosshair at center
              CustomPaint(
                size: Size(size, size),
                painter: _CrosshairPainter(color: color),
              ),

              // Coordinates at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '(${corner.dx.round()}, ${corner.dy.round()})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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

class _QuadPainter extends CustomPainter {
  final Offset tl, tr, bl, br;

  _QuadPainter({required this.tl, required this.tr, required this.bl, required this.br});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // Fill
    canvas.drawPath(path, Paint()..color = Colors.yellow.withOpacity(0.15));
    
    // Stroke
    canvas.drawPath(path, Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter old) =>
      old.tl != tl || old.tr != tr || old.bl != bl || old.br != br;
}

class _CrosshairPainter extends CustomPainter {
  final Color color;
  
  _CrosshairPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    // Vertical line
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height - 25), paint);
    
    // Horizontal line
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    
    // Center circle
    canvas.drawCircle(center, 6, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(center, 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
