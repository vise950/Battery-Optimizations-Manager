import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../services/apps_channel.dart';

class AppDetailScreen extends StatefulWidget {
  final AppInfo app;

  const AppDetailScreen({super.key, required this.app});

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  bool? _isIgnoring;
  bool _loadingStatus = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final ignoring = await AppsChannel.isIgnoringBatteryOptimizations(widget.app.packageName);
      setState(() {
        _isIgnoring = ignoring;
        _loadingStatus = false;
      });
    } catch (_) {
      setState(() => _loadingStatus = false);
    }
  }

  Future<void> _toggleExemption() async {
    setState(() => _actionInProgress = true);
    try {
      if (_isIgnoring == true) {
        // Rimuovi esenzione
        final success = await AppsChannel.removeFromWhitelist(widget.app.packageName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Esenzione rimossa.' : 'Impossibile rimuovere l\'esenzione.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Richiedi esenzione
        final mode = await AppsChannel.requestIgnoreBatteryOptimization(widget.app.packageName);
        if (!mounted) return;

        String message;
        switch (mode) {
          case 'shizuku_success':
            message = 'Esenzione concessa tramite Shizuku!';
            break;
          case 'shizuku_failed':
            message = 'Shizuku: operazione fallita. Riprova.';
            break;
          case 'shizuku_permission_needed':
            message = 'Concedi il permesso a Shizuku e riprova.';
            break;
          case 'direct':
            message = 'Richiesta inviata al sistema.';
            break;
          case 'fallback':
            message = 'Cerca manualmente l\'app e disattiva l\'ottimizzazione.';
            break;
          default:
            message = 'Risultato: $mode';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 1));
      await _checkBatteryStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(app.name),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Icon
            if (app.icon != null)
              Image.memory(app.icon!, width: 96, height: 96)
            else
              const Icon(Icons.android, size: 96),
            const SizedBox(height: 16),

            // App Name
            Text(
              app.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(label: 'Package', value: app.packageName),
                    const Divider(),
                    _InfoRow(
                      label: 'Versione',
                      value: app.versionName.isNotEmpty ? app.versionName : '-',
                    ),
                    const Divider(),
                    _InfoRow(label: 'Build', value: app.versionCode.toString()),
                    const Divider(),
                    _InfoRow(
                      label: 'Ottimizzazione batteria',
                      value: _loadingStatus
                          ? 'Verifica in corso...'
                          : _isIgnoring == null
                          ? 'Non disponibile'
                          : _isIgnoring!
                          ? '✅ Disattivata (ignorata)'
                          : '⚡ Attiva',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Pulsante principale: cambia testo e colore in base allo stato
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: _isIgnoring == true
                    ? FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                )
                    : null,
                icon: _actionInProgress
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  _isIgnoring == true
                      ? Icons.remove_circle_outline
                      : Icons.bolt,
                ),
                label: Text(
                  _loadingStatus
                      ? 'Verifica in corso...'
                      : _isIgnoring == true
                      ? 'Rimuovi esenzione'
                      : 'Richiedi esenzione per questa app',
                ),
                onPressed: (_actionInProgress || _loadingStatus) ? null : _toggleExemption,
              ),
            ),
            const SizedBox(height: 12),

            // Apri impostazioni batteria
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.battery_saver),
                label: const Text('Apri impostazioni ottimizzazione batteria'),
                onPressed: () async {
                  await AppsChannel.openBatteryOptimizationSettings();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Refresh
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Aggiorna stato'),
              onPressed: _checkBatteryStatus,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
