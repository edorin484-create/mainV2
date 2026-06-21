import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/planning_provider.dart';
import '../utils/app_theme.dart';
import 'verification_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final File imageFile;
  const ProcessingScreen({super.key, required this.imageFile});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_animController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProcessing();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startProcessing() async {
    final provider = context.read<PlanningProvider>();
    await provider.processImage(widget.imageFile);

    if (!mounted) return;

    if (provider.processingState == ProcessingState.done) {
      if (provider.lastOcrResult != null &&
          provider.lastOcrResult!.shifts.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              ocrResult: provider.lastOcrResult!,
            ),
          ),
        );
      } else {
        _showNoResultDialog();
      }
    } else if (provider.processingState == ProcessingState.error) {
      _showErrorDialog(provider.errorMessage ?? 'Erreur inconnue');
    }
  }

  void _showNoResultDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aucun résultat'),
        content: const Text(
          'L\'IA n\'a pas pu lire votre planning. '
          'Essayez avec une meilleure luminosité ou une photo plus nette.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PlanningProvider>(
        builder: (context, provider, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Preview image
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Spinner IA
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _rotateAnim,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                AppTheme.primaryBlue.withOpacity(0.0),
                                AppTheme.primaryBlue,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: AppTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status message
                  Text(
                    provider.processingMessage ?? 'Analyse en cours...',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: provider.processingProgress,
                      minHeight: 8,
                      backgroundColor:
                          Theme.of(context).colorScheme.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(provider.processingProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 48),

                  // Steps
                  _StepIndicator(
                    steps: const [
                      'Amélioration de l\'image',
                      'Détection du tableau',
                      'Lecture OCR',
                      'Analyse des données',
                      'Enregistrement',
                    ],
                    currentProgress: provider.processingProgress,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final double currentProgress;

  const _StepIndicator({required this.steps, required this.currentProgress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final stepProgress = (i + 1) / steps.length;
        final isDone = currentProgress >= stepProgress;
        final isCurrent = !isDone &&
            currentProgress >= (i / steps.length);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppTheme.successGreen
                      : isCurrent
                          ? AppTheme.primaryBlue
                          : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: isDone
                        ? AppTheme.successGreen
                        : isCurrent
                            ? AppTheme.primaryBlue
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : isCurrent
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                steps[i],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDone
                      ? AppTheme.successGreen
                      : isCurrent
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}