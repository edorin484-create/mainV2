import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/planning_provider.dart';
import '../utils/app_theme.dart';
import 'processing_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isCapturing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.max, // Résolution maximale pour petits textes
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Paramètres optimisés pour la lecture de texte
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);

      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Overlay guidage
          Positioned.fill(child: _buildOverlay()),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildHeader()),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return CustomPaint(
      painter: _ScanOverlayPainter(),
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.accentTeal,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildCorners(),
          ),
        ),
      ),
    );
  }

  Widget _buildCorners() {
    return Stack(
      children: [
        // Top-left
        Positioned(top: -2, left: -2, child: _Corner()),
        // Top-right
        Positioned(top: -2, right: -2, child: Transform.rotate(angle: 1.5708, child: _Corner())),
        // Bottom-left
        Positioned(bottom: -2, left: -2, child: Transform.rotate(angle: -1.5708, child: _Corner())),
        // Bottom-right
        Positioned(bottom: -2, right: -2, child: Transform.rotate(angle: 3.1416, child: _Corner())),
        // Center hint
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Cadrez votre planning dans ce rectangle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black38,
            ),
          ),
          const Expanded(
            child: Text(
              'Photographier le planning',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              _cameraController?.value.flashMode == FlashMode.torch
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              color: Colors.white,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _TipRow(icon: Icons.light_mode_rounded, text: 'Bonne lumière = meilleure lecture'),
                  _TipRow(icon: Icons.crop_rotate_rounded, text: 'Évitez les reflets et les ombres'),
                  _TipRow(icon: Icons.zoom_out_map_rounded, text: 'Tenez le téléphone à 30-40 cm'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Galerie
                _CircleButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  size: 56,
                  onTap: _pickFromGallery,
                ),
                // Bouton capture principal
                GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing ? Colors.grey : AppTheme.primaryBlue,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: _isCapturing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_rounded, color: Colors.white, size: 36),
                  ),
                ),
                // Retourner la caméra
                _CircleButton(
                  icon: Icons.flip_camera_android_rounded,
                  label: 'Retourner',
                  size: 56,
                  onTap: _cameras.length > 1 ? _switchCamera : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // Maximiser la netteté avant capture
      await _cameraController!.setFocusMode(FocusMode.locked);
      await Future.delayed(const Duration(milliseconds: 500));

      final file = await _cameraController!.takePicture();
      if (!mounted) return;

      _navigateToProcessing(File(file.path));
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null || !mounted) return;
    _navigateToProcessing(File(picked.path));
  }

  void _navigateToProcessing(File imageFile) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(imageFile: imageFile),
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    final current = _cameraController!.value.flashMode;
    await _cameraController!.setFlashMode(
      current == FlashMode.torch ? FlashMode.off : FlashMode.torch,
    );
    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final currentDesc = _cameraController!.description;
    final newDesc = _cameras.firstWhere((c) => c != currentDesc);
    await _cameraController!.dispose();
    _cameraController = CameraController(newDesc, ResolutionPreset.max, enableAudio: false);
    await _cameraController!.initialize();
    setState(() {});
  }
}

class _Corner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.accentTeal, width: 4),
          left: BorderSide(color: AppTheme.accentTeal, width: 4),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentTeal, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap == null ? Colors.black26 : Colors.black38,
              border: Border.all(color: Colors.white54),
            ),
            child: Icon(
              icon,
              color: onTap == null ? Colors.white38 : Colors.white,
              size: size * 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final cutoutWidth = size.width * 0.85;
    final cutoutHeight = size.height * 0.5;
    final cutoutLeft = (size.width - cutoutWidth) / 2;
    final cutoutTop = (size.height - cutoutHeight) / 2;

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutWidth, cutoutHeight),
      const Radius.circular(12),
    );

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}