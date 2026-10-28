import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

class ExerciseDetailPage extends StatefulWidget {
  final String title;
  final String videoUrl;
  final String description;
  final int sets;
  final int reps;
  final String assignedBy;
  final bool canStartExercise;
  final Future<void> Function()? onStartExercise;

  const ExerciseDetailPage({
    super.key,
    required this.title,
    required this.videoUrl,
    required this.description,
    required this.sets,
    required this.reps,
    required this.assignedBy,
    required this.canStartExercise,
    this.onStartExercise,
  });

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  Future<void>? _initializeVideo;
  String? _youtubeVideoId;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final id = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (id != null) {
      _youtubeVideoId = id;
      _youtubeController = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          enableCaption: true,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      _videoController = VideoPlayerController.networkUrl(uri);
      _initializeVideo = _videoController!.initialize();
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final secondaryText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475467);
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final description = widget.description.trim().isNotEmpty
        ? widget.description.trim()
        : context.l10n.noExerciseDescription;

    return Scaffold(
      appBar: kinexAppBar(title: widget.title),
      body: KinexScreenBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlayerCard(cardBg),
                const SizedBox(height: 20),
                Text(
                  context.l10n.description,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _metaCard(
                        value: widget.sets > 0 ? '${widget.sets}' : '-',
                        label: context.l10n.sets,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metaCard(
                        value: widget.reps > 0 ? '${widget.reps}' : '-',
                        label: context.l10n.reps,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E90FA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.assignedBy,
                              style: TextStyle(color: secondaryText, fontSize: 13),
                            ),
                            Text(
                              widget.assignedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: (!widget.canStartExercise || _isStarting || widget.onStartExercise == null)
                ? null
                : () async {
                    setState(() => _isStarting = true);
                    try {
                      await widget.onStartExercise!.call();
                    } finally {
                      if (mounted) {
                        setState(() => _isStarting = false);
                      }
                    }
                  },
            icon: _isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(widget.canStartExercise ? Icons.play_arrow_rounded : Icons.lock_outline_rounded),
            label: Text(
              _isStarting
                  ? context.l10n.preparingExercise
                  : (widget.canStartExercise ? context.l10n.startExercise : context.l10n.recordingLockedSubscription),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.canStartExercise
                  ? const Color(0xFF4CAF50)
                  : (isDark ? const Color(0xFF475467) : const Color(0xFF98A2B3)),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(Color cardBg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _buildPlayerContent(),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_youtubeController != null && _youtubeVideoId != null) {
      return YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF2E90FA),
      );
    }

    if (_videoController != null && _initializeVideo != null) {
      return FutureBuilder<void>(
        future: _initializeVideo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(color: Colors.black),
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio > 0
                    ? _videoController!.value.aspectRatio
                    : (16 / 9),
                child: VideoPlayer(_videoController!),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  });
                },
                iconSize: 64,
                color: Colors.white,
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),
            ],
          );
        },
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Center(
        child: Text(
          context.l10n.invalidVideoUrl,
          style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _metaCard({required String value, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2937) : const Color(0xFFEFF2F7);
    final secondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              color: Color(0xFF2E90FA),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: secondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}






