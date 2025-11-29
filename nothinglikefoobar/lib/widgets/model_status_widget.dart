import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/model_initializer.dart';

class ModelStatusWidget extends StatefulWidget {
  const ModelStatusWidget({super.key});

  @override
  State<ModelStatusWidget> createState() => _ModelStatusWidgetState();
}

class _ModelStatusWidgetState extends State<ModelStatusWidget> {
  late Stream<void> _statusStream;

  @override
  void initState() {
    super.initState();
    // Create a stream that emits every second to check status
    _statusStream = Stream.periodic(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _statusStream,
      builder: (context, snapshot) {
        final modelInit = ModelInitializer.instance;

        if (modelInit.isInitialized) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha((0.2 * 255).round()),
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'AI READY',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        }

        if (modelInit.isInitializing) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha((0.2 * 255).round()),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI LOADING...',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        }

        if (modelInit.error != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((0.2 * 255).round()),
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  'AI ERROR',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        }

        // Not initialized yet
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha((0.2 * 255).round()),
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'AI OFF',
                style: GoogleFonts.shareTechMono(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
