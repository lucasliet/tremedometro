import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/measurement.dart';
import '../services/tremor_service.dart';
import '../utils/web_permission/web_permission.dart'; // [NEW] Import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TremorService _tremorService = TremorService();

  List<Measurement> _measurements = [];
  int? _lastScore;
  int _countdown = 5;
  bool _isRunning = false;
  bool _needsPermission = false; // [NEW]

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkPermissions(); // [NEW]
    _loadMeasurements();
    _setupListeners();
    _setupAnimations();
  }

  // [NEW]
  Future<void> _checkPermissions() async {
    if (kIsWeb && WebPermissionUtils.needsPermissionRequest) {
      // No iOS Web, precisamos pedir permissão via toque do usuário.
      // Então apenas marcamos que precisamos mostrar o botão.
      setState(() {
        _needsPermission = true;
      });
    }
  }

  // [NEW]
  Future<void> _requestPermission() async {
    final granted = await WebPermissionUtils.requestSensorPermission();
    if (granted) {
      setState(() {
        _needsPermission = false;
      });
      _tremorService.startMeasurement();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de sensores negada')),
        );
      }
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupListeners() {
    _tremorService.isRunningStream.listen((isRunning) {
      setState(() => _isRunning = isRunning);
      if (isRunning) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    _tremorService.countdownStream.listen((countdown) {
      setState(() => _countdown = countdown);
    });

    _tremorService.scoreStream.listen((score) async {
      setState(() => _lastScore = score);
      await _tremorService.saveMeasurement(score);
      await _loadMeasurements();
    });
  }

  Future<void> _loadMeasurements() async {
    final measurements = await _tremorService.loadMeasurements();
    if (!mounted) return;
    setState(() => _measurements = measurements);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tremorService.dispose();
    super.dispose();
  }

  Color _getScoreColor(int score) {
    if (score < 200) return const Color(0xFF4CAF50);
    if (score < 400) return const Color(0xFF8BC34A);
    if (score < 600) return const Color(0xFFFFEB3B);
    if (score < 800) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getScoreLabel(int score) {
    if (score < 200) return 'Muito Estável';
    if (score < 400) return 'Estável';
    if (score < 600) return 'Moderado';
    if (score < 800) return 'Tremor Alto';
    return 'Tremor Extremo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              const Color(0xFF1a1a2e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isRunning ? _buildCountdownView() : _buildScoreView(),
              ),
              _buildMeasureButton(),
              const SizedBox(height: 16),
              Expanded(child: _buildHistoryList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EFF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.vibration,
              color: Color(0xFF6B4EFF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BlueGuava',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Medidor de Tremor',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
              ),
            ],
          ),
          const Spacer(),
          if (_measurements.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: _showClearHistoryDialog,
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownView() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6B4EFF).withValues(alpha: 0.3),
                    const Color(0xFF6B4EFF).withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(color: const Color(0xFF6B4EFF), width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Mantenha firme',
                    style: TextStyle(fontSize: 14, color: Colors.white60),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreView() {
    if (_lastScore == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Toque para medir',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final scoreColor = _getScoreColor(_lastScore!);
    final scoreLabel = _getScoreLabel(_lastScore!);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scoreColor.withValues(alpha: 0.3),
                  scoreColor.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: scoreColor, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_lastScore',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                const Text(
                  'BlueGuava',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              scoreLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scoreColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _needsPermission
              ? _requestPermission
              : (_isRunning
                    ? _tremorService.stopMeasurement
                    : _tremorService.startMeasurement),
          style: ElevatedButton.styleFrom(
            backgroundColor: _needsPermission
                ? const Color(0xFF2196F3) // Azul para pedir permissão
                : (_isRunning
                      ? const Color(0xFFF44336)
                      : const Color(0xFF6B4EFF)),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor:
                (_isRunning ? const Color(0xFFF44336) : const Color(0xFF6B4EFF))
                    .withValues(alpha: 0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _needsPermission
                    ? Icons.lock_open
                    : (_isRunning ? Icons.stop : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Text(
                _needsPermission
                    ? 'Habilitar Sensores'
                    : (_isRunning ? 'Parar' : 'Iniciar Medição'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_measurements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhuma medição ainda',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Histórico',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _measurements.length,
            itemBuilder: (context, index) {
              final measurement = _measurements[index];
              final scoreColor = _getScoreColor(measurement.score);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${measurement.score}',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    _getScoreLabel(measurement.score),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(measurement.timestamp),
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inHours < 1) return 'Há ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Há ${diff.inHours}h';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';

    return '${date.day}/${date.month}/${date.year}';
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Limpar histórico?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Todas as medições serão removidas permanentemente.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _tremorService.clearHistory();
              if (!context.mounted) return;
              await _loadMeasurements();
              if (!context.mounted) return;
              setState(() => _lastScore = null);
              Navigator.pop(context);
            },
            child: const Text(
              'Limpar',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );
  }
}
