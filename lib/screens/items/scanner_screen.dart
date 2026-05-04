import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  final bool batchMode;

  const ScannerScreen({super.key, this.batchMode = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController();
  bool _scanned = false;
  final List<String> _batchCodes = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;

    if (!widget.batchMode) {
      if (_scanned) return;
      _scanned = true;
      Navigator.pop(context, value);
      return;
    }

    // Batch mód: ne adjuk hozzá duplikátumot
    if (_batchCodes.contains(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Már beolvasva: $value'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() => _batchCodes.add(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batchMode
            ? 'Tömeges bevitel (${_batchCodes.length} db)'
            : 'Vonalkód beolvasása'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, state, _) => IconButton(
              icon: Icon(state.torchState == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off),
              onPressed: _controller.toggleTorch,
            ),
          ),
          if (widget.batchMode && _batchCodes.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _batchCodes),
              child: Text(
                'Kész (${_batchCodes.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          CustomPaint(
            painter: _ScannerOverlay(),
            child: const SizedBox.expand(),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  widget.batchMode
                      ? 'Szkennelj több terméket, majd nyomj Kész-t'
                      : 'Tartsd a kamerát a vonalkód fölé',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
                if (widget.batchMode && _batchCodes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _batchCodes.join('\n'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutoutWidth = 260.0;
    const cutoutHeight = 160.0;
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: cutoutWidth,
      height: cutoutHeight,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              cutoutRect, const Radius.circular(12))),
      ),
      Paint()..color = Colors.black54,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, const Radius.circular(12)),
      Paint()
        ..color = const Color(0xFF2ECC71)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
