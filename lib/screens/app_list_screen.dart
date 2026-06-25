import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../services/apps_channel.dart';
import 'app_detail_screen.dart';

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  List<AppInfo> _allApps = [];
  List<AppInfo> _filteredApps = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  bool _shizukuRunning = false;
  bool _shizukuAvailable = false;
  bool _whitelistingAll = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
    _checkShizukuStatus();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await AppsChannel.getInstalledApps();
      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _checkShizukuStatus() async {
    try {
      final running = await AppsChannel.isShizukuRunning();
      final available = await AppsChannel.isShizukuAvailable();
      setState(() {
        _shizukuRunning = running;
        _shizukuAvailable = available;
      });
    } catch (_) {}
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _allApps
          .where(
            (app) =>
                app.name.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query),
          )
          .toList();
    });
  }

  Future<void> _whitelistAll() async {
    setState(() => _whitelistingAll = true);
    try {
      final res = await AppsChannel.whitelistAllApps();
      if (!mounted) return;
      final total = res?['total'] ?? 0;
      final done = res?['whitelisted'] ?? 0;
      final failed = res?['failed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completato: $done/$total esentate, $failed fallite.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
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
      if (mounted) setState(() => _whitelistingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Installate'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca app...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento app...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadApps, child: const Text('Riprova')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadApps(), _checkShizukuStatus()]);
      },
      child: CustomScrollView(
        slivers: [
          // --- Banner Shizuku ---
          SliverToBoxAdapter(
            child: _ShizukuBanner(
              isRunning: _shizukuRunning,
              isAvailable: _shizukuAvailable,
              whitelistingAll: _whitelistingAll,
              onRefresh: _checkShizukuStatus,
              onWhitelistAll: _shizukuAvailable ? _whitelistAll : null,
            ),
          ),

          // --- Lista app ---
          if (_filteredApps.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Nessuna app trovata.')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final app = _filteredApps[index];
                return Column(
                  children: [
                    ListTile(
                      leading: app.icon != null
                          ? Image.memory(app.icon!, width: 48, height: 48)
                          : const Icon(Icons.android, size: 48),
                      title: Text(
                        app.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        app.packageName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AppDetailScreen(app: app),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],
                );
              }, childCount: _filteredApps.length),
            ),
        ],
      ),
    );
  }
}

// ─── Shizuku Banner ──────────────────────────────────────────────────────────

class _ShizukuBanner extends StatelessWidget {
  final bool isRunning;
  final bool isAvailable;
  final bool whitelistingAll;
  final VoidCallback onRefresh;
  final VoidCallback? onWhitelistAll;

  const _ShizukuBanner({
    required this.isRunning,
    required this.isAvailable,
    required this.whitelistingAll,
    required this.onRefresh,
    required this.onWhitelistAll,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;
    final String sublabel;

    if (isAvailable) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      label = 'Shizuku attivo';
      sublabel = 'Puoi gestire l\'esenzione di qualsiasi app.';
    } else if (isRunning) {
      color = Colors.orange;
      icon = Icons.warning_amber_rounded;
      label = 'Shizuku — permesso mancante';
      sublabel = 'Apri Shizuku e concedi il permesso all\'app.';
    } else {
      color = Colors.grey;
      icon = Icons.power_off_outlined;
      label = 'Shizuku non attivo';
      sublabel = 'Avvia Shizuku per gestire tutte le app.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            // Pulsante refresh
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              color: color,
              tooltip: 'Aggiorna stato Shizuku',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}
