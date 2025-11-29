import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class EditVideoView extends StatefulWidget {
  final AssetEntity asset;

  const EditVideoView({super.key, required this.asset});

  @override
  State<EditVideoView> createState() => _EditVideoViewState();
}

class _EditVideoViewState extends State<EditVideoView> {
  VideoPlayerController? _controller;
  File? _videoFile;
  bool _isLoading = true;
  bool _isProcessing = false;

  // Trim state
  double _startTrim = 0.0;
  double _endTrim = 1.0;
  Duration _videoDuration = Duration.zero;

  // Playback state
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    setState(() => _isLoading = true);

    try {
      final file = await widget.asset.file;
      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load video")),
          );
          Navigator.pop(context);
        }
        return;
      }

      _videoFile = file;
      _controller = VideoPlayerController.file(file);

      await _controller!.initialize();

      _videoDuration = _controller!.value.duration;

      _controller!.addListener(() {
        if (mounted) {
          setState(() {
            _currentPosition = _controller!.value.position;
            _isPlaying = _controller!.value.isPlaying;
          });

          // Loop within trim bounds
          if (_controller!.value.position >= Duration(milliseconds: (_endTrim * _videoDuration.inMilliseconds).toInt())) {
            _controller!.seekTo(Duration(milliseconds: (_startTrim * _videoDuration.inMilliseconds).toInt()));
            if (!_isPlaying) {
              _controller!.pause();
            }
          }
        }
      });

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading video: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading video: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_isPlaying) {
      _controller!.pause();
    } else {
      // Seek to start trim position if at the end
      if (_currentPosition >= Duration(milliseconds: (_endTrim * _videoDuration.inMilliseconds).toInt())) {
        _controller!.seekTo(Duration(milliseconds: (_startTrim * _videoDuration.inMilliseconds).toInt()));
      }
      _controller!.play();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _saveTrimmedVideo() async {
    if (_videoFile == null || _controller == null) return;

    setState(() => _isProcessing = true);

    try {
      // If no trimming, just save the original
      if (_startTrim == 0.0 && _endTrim == 1.0) {
        await PhotoManager.editor.saveVideo(
          _videoFile!,
          relativePath: "DCIM/Camera",
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Video saved to gallery"),
              backgroundColor: Color(0xFFD71921),
            ),
          );
        }
        return;
      }

      // Actual FFmpeg trimming
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Calculate trim times in seconds
      final startTime = _startTrim * _videoDuration.inSeconds;
      final duration = (_endTrim - _startTrim) * _videoDuration.inSeconds;

      // FFmpeg command: trim video with copy codec (fast, no re-encoding)
      final command = '-i "${_videoFile!.path}" -ss $startTime -t $duration -c copy "$outputPath"';

      debugPrint("FFmpeg command: $command");

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Save trimmed video to gallery
        await PhotoManager.editor.saveVideo(
          File(outputPath),
          relativePath: "DCIM/Camera",
        );

        // Cleanup temp file
        try {
          await File(outputPath).delete();
        } catch (e) {
          debugPrint("Error deleting temp file: $e");
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Trimmed video saved successfully!"),
              backgroundColor: Color(0xFFD71921),
            ),
          );
        }
      } else {
        final output = await session.getOutput();
        debugPrint("FFmpeg failed: $output");
        throw Exception("Video trimming failed");
      }
    } catch (e) {
      debugPrint("Error saving video: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "EDIT VIDEO",
          style: GoogleFonts.shareTechMono(fontSize: 18, color: Colors.white),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFD71921),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFFD71921)),
              onPressed: (_startTrim != 0.0 || _endTrim != 1.0) ? _saveTrimmedVideo : null,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD71921)),
            )
          : Column(
              children: [
                Expanded(child: _buildVideoPlayer()),
                _buildControls(),
                _buildTrimmer(),
              ],
            ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD71921)));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            if (!_isPlaying)
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                onPressed: _togglePlayPause,
                iconSize: 32,
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white),
                onPressed: () {
                  final newPosition = _currentPosition - const Duration(seconds: 5);
                  _controller?.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white),
                onPressed: () {
                  final newPosition = _currentPosition + const Duration(seconds: 5);
                  _controller?.seekTo(newPosition > _videoDuration ? _videoDuration : newPosition);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
              ),
              const Text(" / ", style: TextStyle(color: Colors.grey)),
              Text(
                _formatDuration(_videoDuration),
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TRIM",
                style: GoogleFonts.shareTechMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD71921),
                ),
              ),
              if (_startTrim != 0.0 || _endTrim != 1.0)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _startTrim = 0.0;
                      _endTrim = 1.0;
                    });
                    _controller?.seekTo(Duration.zero);
                  },
                  child: Text(
                    "RESET",
                    style: GoogleFonts.shareTechMono(fontSize: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "START",
                      style: GoogleFonts.shareTechMono(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(Duration(milliseconds: (_startTrim * _videoDuration.inMilliseconds).toInt())),
                      style: GoogleFonts.shareTechMono(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "END",
                      style: GoogleFonts.shareTechMono(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(Duration(milliseconds: (_endTrim * _videoDuration.inMilliseconds).toInt())),
                      style: GoogleFonts.shareTechMono(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: RangeValues(_startTrim, _endTrim),
            onChanged: (values) {
              setState(() {
                _startTrim = values.start;
                _endTrim = values.end;
              });
            },
            onChangeEnd: (values) {
              _controller?.seekTo(Duration(milliseconds: (values.start * _videoDuration.inMilliseconds).toInt()));
            },
            activeColor: const Color(0xFFD71921),
            inactiveColor: Colors.grey[700],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Duration: ${_formatDuration(Duration(milliseconds: ((_endTrim - _startTrim) * _videoDuration.inMilliseconds).toInt()))}",
              style: GoogleFonts.shareTechMono(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

