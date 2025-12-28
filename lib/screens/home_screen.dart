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
  // Flag de Debug para mostrar GuavaPrime (Raw Score)
  static const bool _showPrime = bool.fromEnvironment('PRIME');

  final TremorService _tremorService = TremorService();

  List<Measurement> _measurements = [];
  double? _lastScore; // [CHANGE] int -> double
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
      if (!mounted) return;
      setState(() => _isRunning = isRunning);
      if (isRunning) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.stop();
      }
    });

    _tremorService.countdownStream.listen((countdown) {
      setState(() => _countdown = countdown);
    });

    _tremorService.scoreStream.listen((score) {
      if (score == -1) {
        // -1 indica erro de sensor (nenhum dado recebido)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível ler os sensores. Verifique se seu dispositivo tem acelerômetro e se a permissão foi concedida.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() {
          _lastScore = 0.0; // Reseta para 0 visualmente
        });
      } else {
        setState(() {
          _lastScore = score;
        });
        // Service já salva automaticamente ao finalizar medição
        _loadMeasurements();
        // Não mostra diálogo aqui, apenas atualiza UI
      }
    });

    _tremorService.messageStream.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: message.contains('Erro') || message.contains('Falha')
              ? Colors.red
              : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
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

  // Ajuste nas cores para nova escala relativa (1.0 = Referência/Normal para Wanderson)
  // Assumindo:
  // < 0.5: Muito Estável
  // < 1.0: Estável (dentro da referência)
  // < 1.5: Moderado
  // < 2.5: Alto
  // >= 2.5: Extremo
  Color _getScoreColor(double score) {
    if (score < 0.5) return const Color(0xFF4CAF50);
    if (score < 1.0) return const Color(0xFF8BC34A);
    if (score < 1.5) return const Color(0xFFFFEB3B);
    if (score < 2.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getScoreLabel(double score) {
    if (score < 0.5) return 'Muito Estável';
    if (score < 1.0) return 'Estável';
    if (score < 1.5) return 'Moderado';
    if (score < 2.5) return 'Tremor Alto';
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
                'Tremedômetro',
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
                  _lastScore!.toStringAsFixed(1),
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
                if (_showPrime) ...[
                  const SizedBox(height: 4),
                  Text(
                    'GP: ${(_lastScore! * _tremorService.currentReference).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.3),
                      fontFamily: 'Monospace',
                    ),
                  ),
                ],
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
              // O score salvo agora é GuavaPrime (cru).
              // Precisamos converter para BlueGuava usando a referência ATUAL do serviço.
              // Isso garante que todo o histórico seja re-calibrado se a referência mudar.
              final currentRef = _tremorService.currentReference;
              final blueGuavaScore = currentRef > 0
                  ? measurement.score / currentRef
                  : measurement.score; // Fallback seguro

              final scoreColor = _getScoreColor(blueGuavaScore);

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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            blueGuavaScore.toStringAsFixed(1),
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (_showPrime)
                            Text(
                              measurement.score.toStringAsFixed(0),
                              style: TextStyle(
                                color: scoreColor.withValues(alpha: 0.5),
                                fontSize: 8,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  title: Text(
                    _getScoreLabel(blueGuavaScore),
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
