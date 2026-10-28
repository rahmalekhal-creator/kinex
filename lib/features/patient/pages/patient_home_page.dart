import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/l10n/value_labels.dart';
import 'package:reeducation/widgets/language_button.dart';
import 'package:reeducation/login_provider.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';
import 'exercise_detail_page.dart';
import 'package:reeducation/features/auth/pages/login_screen.dart';
import 'patient_messages_page.dart';
import 'package:reeducation/features/exercise_ai/core/assignment_context.dart';
import 'package:reeducation/features/exercise_ai/pages/exercise_setup_page.dart';

class PatientHomePage extends StatefulWidget {
  final int accountId;

  const PatientHomePage({super.key, required this.accountId});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
      void _toggleTheme() {
        final container = ProviderScope.containerOf(context, listen: false);
        final current = container.read(themeModeProvider);
        container.read(themeModeProvider.notifier).state =
            current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      }

  final SQLdata _db = SQLdata();
  final ImagePicker _picker = ImagePicker();

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _complaintFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _complaintDescriptionController = TextEditingController();
  final TextEditingController _complaintSymptomsController = TextEditingController();

  static const List<String> _filters = ['all', 'today', 'completed', 'pending'];

  int _selectedTab = 0;
  String _selectedExerciseFilter = 'all';

  bool _isHomeLoading = true;
  bool _isExercisesLoading = true;
  bool _isHistoryLoading = true;
  bool _isProfileLoading = true;
  bool _isSavingProfile = false;
  bool _isUploadingPhoto = false;
  bool _isSubmittingComplaint = false;
  bool _isSubmittingProgress = false;
  bool _canRecordExercise = false;
  String? _homeError;
  String? _exercisesError;
  String? _historyError;
  String? _profileError;

  // Weekly completion stats for History tab
  int _weekPercent = 0;
  int _weekTotal = 0;
  int _weekReported = 0;
  List<int> _weekDailyPercents = List.filled(7, 0);

  int _todayTotal = 0;
  int _todayCompleted = 0;
  int _todayPercent = 0;
  List<Map<String, dynamic>> _todayExercises = [];
  List<Map<String, dynamic>> _filteredExercises = [];
  List<Map<String, dynamic>> _historyExercises = [];
  Map<String, dynamic> _profileData = <String, dynamic>{};
  Map<String, dynamic> _therapistData = <String, dynamic>{};
  int _photoRefreshToken = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => _isDark ? const Color(0xFF111827) : Colors.white;
  Color get _primaryText => Theme.of(context).colorScheme.onSurface;
  Color get _secondaryText => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);

  DateTime _historyMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedHistoryDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _complaintDescriptionController.dispose();
    _complaintSymptomsController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadHome(),
      _loadExercises(),
      _loadHistory(),
      _loadProfileData(),
    ]);
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });

    try {
      final data = await _db.fetchPatientProfileTab(widget.accountId);
      if (!mounted) {
        return;
      }

      final profile = (data['profile'] is Map<String, dynamic>)
          ? data['profile'] as Map<String, dynamic>
          : <String, dynamic>{};
      final therapist = (data['therapist'] is Map<String, dynamic>)
          ? data['therapist'] as Map<String, dynamic>
          : <String, dynamic>{};

      _nameController.text = (profile['name'] ?? '').toString();
      _phoneController.text = (profile['phone'] ?? '').toString();

      setState(() {
        _profileData = profile;
        _therapistData = therapist;
        _photoRefreshToken++;
        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profileError = localizeError(e);
        _isProfileLoading = false;
      });
    }
  }

  Future<bool> _saveProfileChanges() async {
    if (!(_profileFormKey.currentState?.validate() ?? false) || _isSavingProfile) {
      return false;
    }

    setState(() => _isSavingProfile = true);
    try {
      await _db.updatePatientProfileTab(
        accountId: widget.accountId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
      );
      if (!mounted) {
        return false;
      }

      _passwordController.clear();
      await _loadProfileData();
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileUpdatedSuccessfully)),
      );
      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) {
      return;
    }

    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) {
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      await _db.uploadPatientPhoto(accountId: widget.accountId, photo: File(picked.path));
      if (!mounted) {
        return;
      }
      await _loadProfileData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profilePhotoUpdated)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<bool> _submitComplaint() async {
    if (!(_complaintFormKey.currentState?.validate() ?? false) || _isSubmittingComplaint) {
      return false;
    }

    setState(() => _isSubmittingComplaint = true);
    try {
      await _db.submitComplaintForm(
        accountId: widget.accountId,
        description: _complaintDescriptionController.text.trim(),
        symptoms: _complaintSymptomsController.text.trim(),
      );
      if (!mounted) {
        return false;
      }
      _complaintDescriptionController.clear();
      _complaintSymptomsController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.complaintSentSuccessfully)),
      );
      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComplaint = false);
      }
    }
  }

  Future<void> _showProgressDialog(Map<String, dynamic> exercise) async {
    final exerciseId = int.tryParse((exercise['exercise_id'] ?? exercise['id'] ?? 0).toString()) ?? 0;
    final patientExerciseId = int.tryParse((exercise['ppid'] ?? exercise['id'] ?? 0).toString()) ?? 0;
    final assignedReps = int.tryParse((exercise['reps'] ?? 0).toString()) ?? 0;
    final assignedSets = int.tryParse((exercise['sets'] ?? 0).toString()) ?? 0;

    // Total target reps = sets × reps (per set)
    final totalTarget = (assignedSets > 0 && assignedReps > 0) ? assignedSets * assignedReps : assignedReps;

    // Reconstruct current session from existing logged data
    final existingTotal = exercise['reps_done'] != null
        ? int.tryParse(exercise['reps_done'].toString()) ?? 0
        : 0;
    final initSetsDone = (assignedReps > 0 && assignedSets > 0)
        ? (existingTotal ~/ assignedReps).clamp(0, assignedSets)
        : 0;

    int setsDone = initSetsDone;

    final repsController = TextEditingController(text: existingTotal.toString());
    final notesController = TextEditingController(text: (exercise['progress_notes'] ?? '').toString());
    final existingPain = exercise['pain_level'] != null
        ? int.tryParse(exercise['pain_level'].toString()) ?? 5
        : 5;
    double painLevel = existingPain.toDouble().clamp(1.0, 10.0);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final currentTotal = int.tryParse(repsController.text.trim()) ?? 0;
          final percent = totalTarget > 0 ? (currentTotal * 100 ~/ totalTarget).clamp(0, 100) : 0;

            return AlertDialog(
              backgroundColor: _cardBg,
            title: Text(context.l10n.logProgressFor((exercise['name'] ?? context.l10n.exercise).toString())),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target info banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isDark ? const Color(0xFF10233D) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF2E90FA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              assignedSets > 0
                                  ? context.l10n.targetSetsReps('$assignedSets', '$assignedReps', '$totalTarget')
                                  : context.l10n.targetReps('$assignedReps'),
                              style: const TextStyle(color: Color(0xFF1570EF), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sets stepper (shown only when sets are assigned)
                    if (assignedSets > 0) ...[
                      Text(context.l10n.setsCompleted, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _primaryText)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: setsDone > 0
                                  ? () {
                                      setDialogState(() {
                                        setsDone--;
                                        repsController.text = (setsDone * assignedReps).toString();
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF2E90FA)),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '$setsDone / $assignedSets',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    setsDone == assignedSets ? context.l10n.allSetsDone : context.l10n.setsDoneLower,
                                    style: TextStyle(
                                      fontSize: 12,
                                        color: setsDone == assignedSets ? const Color(0xFF4CAF50) : _secondaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: setsDone < assignedSets
                                  ? () {
                                      setDialogState(() {
                                        setsDone++;
                                        repsController.text = (setsDone * assignedReps).toString();
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E90FA)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Total reps field (editable override)
                    TextFormField(
                      controller: repsController,
                      style: TextStyle(color: _primaryText),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        assignedSets > 0 ? context.l10n.totalRepsCompleted : context.l10n.repsCompleted,
                        Icons.repeat_rounded,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return context.l10n.required;
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return context.l10n.enterValidNumber;
                        return null;
                      },
                    ),

                    // Progress summary
                    if (totalTarget > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.progressReps('$currentTotal', '$totalTarget'),
                            style: TextStyle(fontSize: 12, color: _secondaryText, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            context.l10n.percentValue('$percent'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: percent >= 100 ? const Color(0xFF4CAF50) : const Color(0xFF2E90FA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (percent / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percent >= 100 ? const Color(0xFF4CAF50) : const Color(0xFF2E90FA),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Pain level
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.l10n.painLevel, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _painColor(painLevel.round()).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.l10n.painOutOfTenSpaced('${painLevel.round()}'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _painColor(painLevel.round()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: painLevel,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: _painColor(painLevel.round()),
                      onChanged: (v) => setDialogState(() => painLevel = v),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: notesController,
                      style: TextStyle(color: _primaryText),
                      maxLines: 3,
                      decoration: _inputDecoration(context.l10n.notesOptional, Icons.notes_rounded),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: _isSubmittingProgress
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        if (!mounted) return;
                        setState(() => _isSubmittingProgress = true);
                        try {
                          await _db.submitProgressReport(
                            accountId: widget.accountId,
                            exerciseId: exerciseId,
                            patientExerciseId: patientExerciseId,
                            repsDone: int.tryParse(repsController.text.trim()) ?? 0,
                            painLevel: painLevel.round(),
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          );
                          if (mounted) Navigator.pop(ctx);
                          await Future.wait([
                            _loadHome(),
                            _loadExercises(_selectedExerciseFilter),
                            _loadHistory(),
                          ]);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(localizeError(e))),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSubmittingProgress = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E90FA),
                  foregroundColor: Colors.white,
                ),
                child: _isSubmittingProgress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.l10n.save),
              ),
            ],
          );
        });
      },
    );
  }

  Color _painColor(int level) {
    if (level <= 3) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  Future<void> _loadHome() async {
    setState(() {
      _isHomeLoading = true;
      _homeError = null;
    });

    try {
      final data = await _db.fetchPatientHome(widget.accountId, filter: 'today');
      if (!mounted) {
        return;
      }

      final summary = (data['summary'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final access = (data['access'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final exercises = (data['exercises'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          <Map<String, dynamic>>[];

      // Subscription flag: PHP sends 1 (int) when active; DB_API.dart converts
      // it to bool true. Accept both representations to be safe.
      final rawFlag = access['can_record_video'];
      final canRecord = rawFlag == true || rawFlag == 1 || rawFlag.toString() == '1';

      setState(() {
        _todayTotal = int.tryParse((summary['total'] ?? 0).toString()) ?? 0;
        _todayCompleted = int.tryParse((summary['completed'] ?? 0).toString()) ?? 0;
        _todayPercent = int.tryParse((summary['percent'] ?? 0).toString()) ?? 0;
        _canRecordExercise = canRecord;
        _todayExercises = exercises;
        _isHomeLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _homeError = localizeError(e);
        _canRecordExercise = false;
        _isHomeLoading = false;
      });
    }
  }

  Future<void> _loadExercises([String? filter]) async {
    final nextFilter = filter ?? _selectedExerciseFilter;

    setState(() {
      _selectedExerciseFilter = nextFilter;
      _isExercisesLoading = true;
      _exercisesError = null;
    });

    try {
      final data = await _db.fetchPatientHome(widget.accountId, filter: nextFilter);
      if (!mounted) {
        return;
      }

      final exercises = (data['exercises'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          <Map<String, dynamic>>[];
      // NOTE: _canRecordExercise is managed exclusively by _loadHome to avoid
      // race-condition overwrites when concurrent requests fail.

      setState(() {
        _filteredExercises = exercises;
        _isExercisesLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _exercisesError = localizeError(e);
        _isExercisesLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isHistoryLoading = true;
      _historyError = null;
    });

    try {
      final results = await Future.wait([
        _db.fetchPatientHome(widget.accountId, filter: 'all'),
        _db.fetchWeeklyCompletion(widget.accountId),
      ]);

      if (!mounted) return;

      final data = results[0];
      final weekly = results[1];

      final exercises = (data['exercises'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          <Map<String, dynamic>>[];

      final dailyRaw = weekly['daily_percents'];
      final dailyPercents = dailyRaw is List
          ? dailyRaw
              .map((e) => (int.tryParse(e.toString()) ?? 0).clamp(0, 100))
              .map((e) => e)
              .toList()
          : List.filled(7, 0);

      setState(() {
        _historyExercises = exercises;
        _weekPercent = (int.tryParse((weekly['week_percent'] ?? 0).toString()) ?? 0).clamp(0, 100);
        _weekTotal = int.tryParse((weekly['total'] ?? 0).toString()) ?? 0;
        _weekReported = int.tryParse((weekly['reported'] ?? 0).toString()) ?? 0;
        _weekDailyPercents = dailyPercents.length == 7 ? dailyPercents : List.filled(7, 0);
        _isHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = localizeError(e);
        _isHistoryLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _pageBg,
      floatingActionButton: FloatingActionButton.small(
        tooltip: l10n.toggleTheme,
        onPressed: _toggleTheme,
        child: Icon(
          Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() => _selectedTab = index);
          if (index == 2 && _historyExercises.isEmpty && !_isHistoryLoading) {
            _loadHistory();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _cardBg,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: _secondaryText,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: l10n.home),
          BottomNavigationBarItem(icon: const Icon(Icons.fitness_center_outlined), label: l10n.exercises),
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_outlined), label: l10n.history),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: l10n.profile),
        ],
      ),
      body: KinexScreenBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedTab),
              child: _buildSelectedTab(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildExercisesTab();
      case 2:
        return _buildHistoryTab();
      default:
        return _buildProfileTab();
    }
  }

  Widget _buildProfileTab() {
    if (_isProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profileError != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildErrorCard(_profileError!, _loadProfileData),
        ],
      );
    }

    final photoUrl = _withCacheBuster(_normalizePhotoUrl((_profileData['photo_url'] ?? '').toString()));
    final l10n = context.l10n;
    final displayName = (_profileData['name'] ?? l10n.patient).toString();
    final therapistName = (_therapistData['name'] ?? l10n.noAssignedTherapist).toString();
    final therapistSpecialization = (_therapistData['specialization'] ?? '').toString();

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 30, color: Color(0xFF2E90FA)),
              const SizedBox(width: 8),
              Text(
                l10n.profile,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _primaryText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.manageProfileAndSupport,
            style: TextStyle(color: _secondaryText),
          ),
          const SizedBox(height: 14),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: _isDark ? const Color(0xFF1F2937) : const Color(0xFFDDE3EC),
                  child: photoUrl.trim().isEmpty
                      ? const Icon(Icons.person_rounded, size: 56, color: Color(0xFF64748B))
                      : ClipOval(
                          child: Image.network(
                            photoUrl,
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person_rounded, size: 56, color: Color(0xFF64748B));
                            },
                          ),
                        ),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E90FA),
                        shape: BoxShape.circle,
                      ),
                      child: _isUploadingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              displayName,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _primaryText),
            ),
          ),
          const SizedBox(height: 18),
          _buildTherapistCard(
            therapistName: therapistName,
            therapistSpecialization: therapistSpecialization,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.settings,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _primaryText),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: l10n.notifications,
                  onTap: () => _showInfoDialog(l10n.notifications, l10n.notificationsComingSoon),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: l10n.editInformationTitle,
                  onTap: _showEditProfileDialog,
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.support_agent_outlined,
                  title: l10n.submitComplaint,
                  onTap: _showComplaintDialog,
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: l10n.logOut,
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.editProfile),
          content: Form(
            key: _profileFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(context.l10n.name, Icons.person_outline_rounded),
                    validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.nameRequired : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(context.l10n.phone, Icons.phone_outlined),
                    validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.phoneRequired : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecoration(context.l10n.newPasswordOptional, Icons.lock_outline_rounded),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty && value.trim().length < 6) {
                        return context.l10n.passwordMinLength;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await _saveProfileChanges();
                if (ok && mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showComplaintDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBg,
          title: Text(context.l10n.submitComplaint),
          content: Form(
            key: _complaintFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _complaintDescriptionController,
                    maxLines: 3,
                    decoration: _inputDecoration(context.l10n.describeYourComplaint, Icons.support_agent_rounded),
                    validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.descriptionRequired : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _complaintSymptomsController,
                    maxLines: 2,
                    decoration: _inputDecoration(context.l10n.symptomsOptional, Icons.monitor_heart_outlined),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await _submitComplaint();
                if (ok && mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(context.l10n.send),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingLabel,
  }) {
    return ListTile(
      leading: Icon(icon, color: _primaryText),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: _primaryText)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingLabel != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                trailingLabel,
                style: TextStyle(color: _primaryText, fontWeight: FontWeight.w600),
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: _primaryText),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _showInfoDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Color(0xFF2E90FA)),
                const SizedBox(width: 8),
                Text(context.l10n.editProfile, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(context.l10n.name, Icons.person_outline_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.nameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(context.l10n.phone, Icons.phone_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.phoneRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration(context.l10n.newPasswordOptional, Icons.lock_outline_rounded),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty && value.trim().length < 6) {
                  return context.l10n.passwordMinLength;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingProfile ? null : _saveProfileChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E90FA),
                  foregroundColor: Colors.white,
                ),
                child: _isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.l10n.saveChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapistCard({
    required String therapistName,
    required String therapistSpecialization,
  }) {
    final hasTherapist = therapistName != context.l10n.noAssignedTherapist;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, color: Color(0xFF2E90FA)),
              const SizedBox(width: 8),
              Text(context.l10n.myTherapist, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F1FF),
                child: Text(
                  hasTherapist && therapistName.isNotEmpty ? therapistName.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFF2E90FA), fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(therapistName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _primaryText)),
                    if (therapistSpecialization.trim().isNotEmpty)
                      Text(
                        therapistSpecialization,
                        style: TextStyle(color: _primaryText, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: hasTherapist
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientMessagesPage(
                              accountId: widget.accountId,
                              therapistName: therapistName,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(context.l10n.message),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E90FA),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _complaintFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.submitComplaint, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintDescriptionController,
              maxLines: 3,
              decoration: _inputDecoration(context.l10n.describeYourComplaint, Icons.support_agent_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.descriptionRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _complaintSymptomsController,
              maxLines: 2,
              decoration: _inputDecoration(context.l10n.symptomsOptional, Icons.monitor_heart_outlined),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingComplaint ? null : _submitComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: _isSubmittingComplaint
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.l10n.sendComplaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadHome,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        children: [
          _buildTopBar(context.l10n.hiPatient),
          const SizedBox(height: 12),
          _buildAiRehabBanner(),
          const SizedBox(height: 16),
          _buildPlanCard(),
          const SizedBox(height: 24),
          Text(
            context.l10n.todaysExercises,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_isHomeLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_homeError != null)
            const SizedBox.shrink()
          else if (_todayExercises.isEmpty)
            _buildEmptyCard(context.l10n.noExercisesToday)
          else
            ..._todayExercises.map((item) => _buildExerciseCard(item, compact: true)),
        ],
      ),
    );
  }

  Widget _buildAiRehabBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E90FA), Color(0xFF7C4DFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E90FA).withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_alt_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.aiCoachBanner,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesTab() {
    return RefreshIndicator(
      onRefresh: () => _loadExercises(_selectedExerciseFilter),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.exercises,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.search_rounded, color: _secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = filter == _selectedExerciseFilter;
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _isExercisesLoading ? null : () => _loadExercises(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2E90FA)
                          : (_isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F2F5)),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      _filterLabel(filter),
                      style: TextStyle(
                        color: selected ? Colors.white : _secondaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemCount: _filters.length,
            ),
          ),
          const SizedBox(height: 18),
          if (_isExercisesLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_exercisesError != null)
            _buildErrorCard(_exercisesError!, () => _loadExercises(_selectedExerciseFilter))
          else if (_filteredExercises.isEmpty)
            _buildEmptyCard(context.l10n.noExercisesForFilter)
          else
            ..._filteredExercises.map((item) => _buildExerciseCard(item, compact: false)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(
            context.l10n.progress,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // Weekly completion summary card
          _buildWeeklyCompletionCard(),
          const SizedBox(height: 16),
          Text(
            context.l10n.sessionHistory,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _isSameDay(_selectedHistoryDay, DateTime.now())
                ? context.l10n.todayUpper
                : _formatShortDate(_selectedHistoryDay),
            style: TextStyle(
              color: _secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildSelectedDayExercises(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isHistoryLoading
                ? const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _historyError != null
                    ? _buildErrorCard(_historyError!, _loadHistory)
                    : _buildCalendarCard(),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildWeekChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCompletionCard() {
    if (_isHistoryLoading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E90FA).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.thisWeek,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.exercisesLoggedOf('$_weekReported', '$_weekTotal'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_weekPercent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (_weekPercent / 100).clamp(0.0, 1.0),
                  strokeWidth: 7,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Center(
                  child: Text(
                    context.l10n.percentValue('$_weekPercent'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final monthLabel = _monthYearLabel(_historyMonth);
    final dayHeaders = context.l10n.weekdayInitials.split(',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _historyMonth = DateTime(_historyMonth.year, _historyMonth.month - 1, 1);
                });
              },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              monthLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _historyMonth = DateTime(_historyMonth.year, _historyMonth.month + 1, 1);
                });
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: dayHeaders
              .map((header) => Expanded(
                    child: Center(
                      child: Text(
                        header,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        ..._buildCalendarRows(_historyMonth),
      ],
    );
  }

  List<Widget> _buildCalendarRows(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDay.weekday;
    final startDate = firstDay.subtract(Duration(days: firstWeekday - 1));

    final List<Widget> rows = [];
    for (int week = 0; week < 6; week++) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (index) {
              final day = startDate.add(Duration(days: week * 7 + index));
              final inMonth = day.month == month.month;
              final selected = _isSameDay(day, _selectedHistoryDay);
              final hasExercises = _dayExercises(day).isNotEmpty;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _selectedHistoryDay = DateTime(day.year, day.month, day.day);
                      _historyMonth = DateTime(day.year, day.month, 1);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2E90FA)
                          : hasExercises
                              ? const Color(0xFFEAF4EA)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : inMonth
                                    ? _primaryText
                                    : const Color(0xFF98A2B3),
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (hasExercises && !selected)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildWeekChart() {
    // Use real daily percents from backend if available, else fall back to count-based
    final List<int> percents = _weekDailyPercents.isNotEmpty && _weekDailyPercents.length == 7
        ? _weekDailyPercents
        : _weekCompletedCounts(_selectedHistoryDay).map((c) => c > 0 ? 100 : 0).toList();

    final labels = context.l10n.weekdayShortNames.split(',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.dailyCompletionPercent,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final value = percents[index].clamp(0, 100);
              final barHeight = (value / 100) * 90;
              final isToday = index == (DateTime.now().weekday - 1);
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      value > 0 ? context.l10n.percentValue('$value') : '',
                      style: TextStyle(color: _secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: barHeight < 4 && value > 0 ? 4 : barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: value >= 100
                            ? const Color(0xFF4CAF50)
                            : isToday
                                ? const Color(0xFF2E90FA)
                                : const Color(0xFF93C5FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: isToday ? const Color(0xFF2E90FA) : _secondaryText,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSelectedDayExercises() {
    final items = _dayExercises(_selectedHistoryDay);
    if (items.isEmpty) {
      return [_buildEmptyCard(context.l10n.noExercisesForDay)];
    }

    return items.map((item) {
      final title = (item['name'] ?? context.l10n.exercise).toString();
      final status = (item['status'] ?? '').toString();
      final reps = int.tryParse((item['reps'] ?? 0).toString()) ?? 0;
      final sets = int.tryParse((item['sets'] ?? 0).toString()) ?? 0;
      final completed = _isCompletedStatus(status);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sets > 0 ? context.l10n.setsCount('$sets') : context.l10n.noSets} ${reps > 0 ? context.l10n.repsBullet('$reps') : ''}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: completed ? const Color(0xFFEAF8EC) : const Color(0xFFFFF1E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                completed ? context.l10n.done : _capitalizeStatus(status),
                style: TextStyle(
                  color: completed ? const Color(0xFF2F9E44) : const Color(0xFFFF9800),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTopBar(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LanguageButton(),
            Stack(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded, size: 28),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                      color: Color(0xFFFF4D4F),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _isHomeLoading
          ? const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.8,
                ),
              ),
            )
          : _homeError != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.todaysPlan,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(_homeError!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadHome,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2E90FA)),
                        foregroundColor: const Color(0xFF2E90FA),
                      ),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.todaysPlan,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_todayCompleted/$_todayTotal',
                            style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            context.l10n.completeLabel,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.weeklyGoalPercent('$_todayPercent'),
                            style: const TextStyle(color: Color(0xFF2E90FA), fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (_todayPercent.clamp(0, 100)) / 100,
                            strokeWidth: 9,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E90FA)),
                          ),
                          Center(
                            child: Text(
                              context.l10n.percentValue('$_todayPercent'),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> item, {required bool compact}) {
    final String title = (item['name'] ?? context.l10n.exercise).toString();
    final String videoUrl = (item['video_url'] ?? '').toString();
    final int sets = int.tryParse((item['sets'] ?? 0).toString()) ?? 0;
    final int reps = int.tryParse((item['reps'] ?? 0).toString()) ?? 0;
    final String status = (item['status'] ?? (item['is_completed'] == true ? 'Completed' : 'Pending')).toString();
    final String normalizedStatus = status.toLowerCase().trim();
    final bool completed = item['is_completed'] == true || normalizedStatus == 'completed' || normalizedStatus == 'done';
    final String thumb = _resolveThumbnail(videoUrl);
    final int completionPercent = int.tryParse((item['completion_percent'] ?? 0).toString()) ?? 0;
    final int? repsDone = item['reps_done'] != null ? int.tryParse(item['reps_done'].toString()) : null;
    final int totalTarget = (sets > 0 && reps > 0) ? sets * reps : reps;

    final List<String> metaParts = [];
    if (sets > 0) metaParts.add(sets == 1 ? context.l10n.oneSet('$sets') : context.l10n.setsCount('$sets'));
    if (reps > 0) metaParts.add(context.l10n.repsCount('$reps'));
    if (metaParts.isEmpty) metaParts.add(context.l10n.exerciseAssigned);

    // Build a meaningful progress label
    final String progressLabel;
    if (completed) {
      progressLabel = repsDone != null
          ? context.l10n.completedRepsOf('$repsDone', totalTarget > 0 ? ' / $totalTarget' : '')
          : context.l10n.exerciseCompletedCheck;
    } else if (repsDone != null) {
      progressLabel = context.l10n.progressRepsOf('$repsDone', totalTarget > 0 ? ' / $totalTarget' : '');
    } else {
      progressLabel = context.l10n.tapToStartLogging;
    }

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 12 : 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main tap area
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () => _openExerciseDetail(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: compact ? 72 : 84,
                      height: compact ? 72 : 84,
                      child: thumb.isNotEmpty
                          ? Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _videoPlaceholder(),
                            )
                          : _videoPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 17 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!compact) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildInfoChip(context.l10n.video, const Color(0xFFE9F2FF), const Color(0xFF2E90FA)),
                              _buildInfoChip(
                                _capitalizeStatus(status),
                                completed ? const Color(0xFFEAF8EC) : const Color(0xFFFFF1E6),
                                completed ? const Color(0xFF3FA34D) : const Color(0xFFFF9800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          metaParts.join(' × '),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Completion % circle
                  _buildCompletionCircle(completionPercent),
                ],
              ),
            ),
          ),
          // Completion progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          progressLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: completed ? const Color(0xFF4CAF50) : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.percentValue('$completionPercent'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: completionPercent >= 100
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF2E90FA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (completionPercent / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionPercent >= 100
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2E90FA),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Log Progress button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: completionPercent >= 100 || completed ? null : () => _showProgressDialog(item),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(
                  completionPercent >= 100 || completed
                      ? context.l10n.completed
                      : (repsDone != null ? context.l10n.updateProgress : context.l10n.logProgress),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: completionPercent >= 100 || completed
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF2E90FA),
                  side: BorderSide(
                    color: completionPercent >= 100 || completed
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF2E90FA),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCircle(int percent) {
    final color = percent >= 100
        ? const Color(0xFF4CAF50)
        : percent > 0
            ? const Color(0xFF2E90FA)
            : const Color(0xFFE5E7EB);
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            strokeWidth: 5,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: Text(
              context.l10n.percentValue('$percent'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: percent > 0 ? color : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      color: const Color(0xFFE8EEF7),
      child: const Icon(Icons.ondemand_video_outlined, color: Color(0xFF7D8796)),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: _primaryText)),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _secondaryText),
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E90FA), width: 1.2),
      ),
    );
  }

  List<Map<String, dynamic>> _dayExercises(DateTime day) {
    return _historyExercises.where((exercise) {
      final assigned = _parseAssignedDate((exercise['assigned_date'] ?? '').toString());
      if (assigned == null) {
        return false;
      }
      return _isSameDay(assigned, day);
    }).toList();
  }

  List<int> _weekCompletedCounts(DateTime reference) {
    final start = reference.subtract(Duration(days: reference.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final counts = List<int>.filled(7, 0);

    for (final exercise in _historyExercises) {
      final assigned = _parseAssignedDate((exercise['assigned_date'] ?? '').toString());
      if (assigned == null) {
        continue;
      }
      if (!assigned.isBefore(start) && assigned.isBefore(end) && _isCompletedStatus((exercise['status'] ?? '').toString())) {
        counts[assigned.weekday - 1] = counts[assigned.weekday - 1] + 1;
      }
    }

    return counts;
  }

  DateTime? _parseAssignedDate(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  bool _isCompletedStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed' || normalized == 'done';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthYearLabel(DateTime month) {
    final monthNames = context.l10n.monthNames.split(',');
    return context.l10n.monthYear(monthNames[month.month - 1], '${month.year}');
  }

  String _formatShortDate(DateTime value) {
    final monthNames = context.l10n.monthShortNames.split(',');
    return context.l10n.shortDate(monthNames[value.month - 1], '${value.day}', '${value.year}');
  }


  Future<void> _startExerciseCapture(Map<String, dynamic> exercise) async {
    if (!_canRecordExercise) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.videoRecordingLocked)),
        );
      }
      return;
    }
    // the physiotherapist decides which tracked exercise this is and which arm (set when assigning it)
    final ai = (exercise['ai_exercise'] ?? '').toString();
    final side = (exercise['side'] ?? '').toString();
    if (!const ['e1', 'e2', 'e3'].contains(ai) || !const ['left', 'right'].contains(side)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trackingNotSet)),
        );
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseSetupPage(
          exerciseId: ai,
          side: side,
          assignment: AssignmentContext(
            accountId: widget.accountId,
            patientExerciseId: int.tryParse((exercise['ppid'] ?? exercise['id'] ?? 0).toString()) ?? 0,
            targetReps: int.tryParse((exercise['reps'] ?? 0).toString()) ?? 0,
          ),
        ),
      ),
    );
  }

  Future<bool> _refreshCanRecordAccess() async {
    // If already unlocked in current state, avoid a network round-trip that may timeout
    // and incorrectly hide the button.
    if (_canRecordExercise) {
      return true;
    }

    try {
      final data = await _db.fetchPatientHome(widget.accountId, filter: 'today');
      final access = (data['access'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final rawFlag = access['can_record_video'];
      final canRecord = rawFlag == true || rawFlag == 1 || rawFlag.toString() == '1';
      if (mounted) {
        setState(() => _canRecordExercise = canRecord);
      }
      return canRecord;
    } catch (_) {
      return _canRecordExercise;
    }
  }

  Future<void> _openExerciseDetail(Map<String, dynamic> exercise) async {
    final title = (exercise['name'] ?? context.l10n.exercise).toString();
    final videoUrl = (exercise['video_url'] ?? '').toString();
    final description = (exercise['description'] ?? '').toString();
    final sets = int.tryParse((exercise['sets'] ?? 0).toString()) ?? 0;
    final reps = int.tryParse((exercise['reps'] ?? 0).toString()) ?? 0;
    final assignedByFromExercise = (exercise['assigned_by_name'] ?? '').toString().trim();
    final assignedByFromProfile = (_therapistData['name'] ?? '').toString().trim();
    final assignedBy = assignedByFromExercise.isNotEmpty
        ? assignedByFromExercise
        : (assignedByFromProfile.isNotEmpty ? assignedByFromProfile : context.l10n.physiotherapist);

    final canRecordNow = await _refreshCanRecordAccess();

    if (!mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailPage(
          title: title,
          videoUrl: videoUrl,
          description: description,
          sets: sets,
          reps: reps,
          assignedBy: assignedBy,
          canStartExercise: canRecordNow,
          onStartExercise: () => _startExerciseCapture(exercise),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Text(
        context.l10n.comingSoon(title),
        style: const TextStyle(fontSize: 18, color: Color(0xFF697386)),
      ),
    );
  }

  String _resolveThumbnail(String videoUrl) {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      return '';
    }

    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      String? id;
      if (uri.host.contains('youtu.be')) {
        id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      } else {
        id = uri.queryParameters['v'];
      }
      if (id != null && id.isNotEmpty) {
        return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      }
    }

    return '';
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'today':
        return context.l10n.today;
      case 'completed':
        return context.l10n.completed;
      case 'pending':
        return context.l10n.pending;
      default:
        return context.l10n.all;
    }
  }

  String _normalizePhotoUrl(String rawUrl) {
    final raw = rawUrl.trim().replaceAll('\\', '/');
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('C:/wamp64/www/reed/')) {
      return _db.convertLocalPathToUrl(raw);
    }

    if (raw.startsWith('uploads/')) {
      return '${_db.phpapi}${raw.replaceFirst(RegExp('^/+'), '')}';
    }

    if (raw.startsWith('/uploads/')) {
      return '${_db.phpapi}${raw.replaceFirst(RegExp('^/+'), '')}';
    }

    final uri = Uri.tryParse(raw);
    final apiUri = Uri.tryParse(_db.phpapi);
    if (uri != null && apiUri != null && uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return uri
            .replace(
              scheme: apiUri.scheme,
              host: apiUri.host,
              port: apiUri.hasPort ? apiUri.port : null,
            )
            .toString();
      }
      return raw;
    }

    return raw;
  }

  String _withCacheBuster(String url) {
    if (url.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['v'] = _photoRefreshToken.toString();
    return uri.replace(queryParameters: qp).toString();
  }

  String _capitalizeStatus(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return context.l10n.pending;
    }
    final label = statusLabel(context.l10n, trimmed);
    if (label != trimmed) {
      return label;
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }
}




