import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

class SingleVideoPlayer extends StatefulWidget {
  final AssetEntity asset;

  const SingleVideoPlayer({super.key, required this.asset});

  @override
  State<SingleVideoPlayer> createState() => _SingleVideoPlayerState();
}

class _SingleVideoPlayerState extends State<SingleVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  String? _errorMessage;
  double _currentSliderValue = 0.0;
  String _durationString = "00:00";
  String _positionString = "00:00";
  bool _isDraggingSlider = false; // Track if user is dragging slider

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      _controller?.dispose();

      final File? file = await widget.asset.file;

      if (file == null) throw Exception("Could not retrieve video file from gallery.");
      if (!await file.exists()) throw Exception("Video file does not exist at path: ${file.path}");

      _controller = VideoPlayerController.file(file);

      await _controller!.initialize();

      if (!mounted) return;

      // Enable looping
      _controller!.setLooping(true);

      setState(() {
        _initialized = true;
        _durationString = _formatDuration(_controller!.value.duration);
        _isPlaying = true;
      });

      _controller!.play();
      _controller!.addListener(_videoListener);

    } on PlatformException catch (e) {
      debugPrint("Video Platform Error: $e");
      if (mounted) setState(() => _errorMessage = "NATIVE ERROR: ${e.message}");
    } catch (e) {
      debugPrint("Video Initialization Error: $e");
      if (mounted) setState(() => _errorMessage = "Load Error: $e");
    }
  }

  void _videoListener() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final double position = _controller!.value.position.inMilliseconds.toDouble();
    final double duration = _controller!.value.duration.inMilliseconds.toDouble();

    if (mounted && !_isDraggingSlider) {
      setState(() {
        // Clamp the value to prevent slider from exceeding max
        _currentSliderValue = position.clamp(0.0, duration);
        _positionString = _formatDuration(_controller!.value.position);
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _togglePlay() {
    if (_controller == null || !_initialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _seekTo(double value) {
    if (_controller == null || !_initialized) return;
    _controller!.seekTo(Duration(milliseconds: value.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(child: _buildContent()),

        if (_initialized && _errorMessage == null)
          GestureDetector(
            onTap: _togglePlay,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(width: double.infinity, height: double.infinity, child: ColoredBox(color: Colors.transparent)),
          ),

        if (_initialized && _errorMessage == null) _buildControls(),

        if (!_isPlaying && _initialized && _errorMessage == null)
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD71921), size: 48),
            const SizedBox(height: 16),
            Text(
                "PLAYBACK ERROR",
                style: GoogleFonts.shareTechMono(color: Color(0xFFD71921), fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            Text(
              "$_errorMessage",
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return const CircularProgressIndicator(color: Color(0xFFD71921));
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 80, // Moved up to be above the action buttons
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [
              const Color(0xFF000000).withValues(alpha: 0.95),
              const Color(0xFF000000).withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFFFFFFFF), size: 28),
                ),
                const SizedBox(width: 8),
                Text(
                  "$_positionString / $_durationString",
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFF1E1E),
                thumbColor: const Color(0xFFFF1E1E),
                overlayColor: const Color(0xFFFF1E1E).withValues(alpha: 0.3),
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                inactiveTrackColor: const Color(0xFF1C1C1E),
              ),
              child: Slider(
                value: _currentSliderValue.clamp(0.0, _controller!.value.duration.inMilliseconds.toDouble()),
                min: 0.0,
                max: _controller!.value.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                onChanged: (value) {
                  setState(() {
                    _isDraggingSlider = true;
                    _currentSliderValue = value;
                    _positionString = _formatDuration(Duration(milliseconds: value.toInt()));
                  });
                },
                onChangeStart: (value) {
                  setState(() => _isDraggingSlider = true);
                },
                onChangeEnd: (value) {
                  _seekTo(value);
                  setState(() => _isDraggingSlider = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}