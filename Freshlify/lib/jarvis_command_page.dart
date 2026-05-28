import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'product_item.dart';

class JarvisCommandPage extends StatefulWidget {
  const JarvisCommandPage({
    super.key,
    required this.onNavigate,
  });

  final ValueChanged<int> onNavigate;

  @override
  State<JarvisCommandPage> createState() => _JarvisCommandPageState();
}

class _JarvisCommandPageState extends State<JarvisCommandPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  List<ProductItem> _history = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('scan_history') ?? <String>[];

    setState(() {
      _history = historyJson
          .map((item) => ProductItem.fromMap(jsonDecode(item)))
          .toList()
        ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    });
  }

  List<ProductItem> get _expiringSoon =>
      _history.where((item) => item.status == 'Expiring Soon').toList();

  List<ProductItem> get _expired =>
      _history.where((item) => item.status == 'Expired').toList();

  List<ProductItem> get _fresh =>
      _history.where((item) => item.status == 'Fresh').toList();

  List<_JarvisMessage> get _messages {
    final nextCritical = _history.isEmpty ? null : _history.first;

    return [
      const _JarvisMessage(
        speaker: 'JARVIS',
        text: 'Good evening. Command deck online and waiting for your instructions.',
      ),
      _JarvisMessage(
        speaker: 'SYSTEM',
        text:
            'Inventory sync complete. ${_history.length} tracked assets, ${_expiringSoon.length} priority alerts, ${_expired.length} expired.',
      ),
      _JarvisMessage(
        speaker: 'JARVIS',
        text: nextCritical == null
            ? 'No consumables are being tracked yet. Recommend initializing a scan.'
            : 'Highest priority item is ${nextCritical.name}. Status: ${_statusLine(nextCritical)}.',
      ),
      const _JarvisMessage(
        speaker: 'JARVIS',
        text:
            'Available directives include barcode scanning, QR generation, and inventory review.',
      ),
    ];
  }

  String _statusLine(ProductItem item) {
    if (item.daysLeft < 0) {
      return 'expired';
    }
    if (item.daysLeft == 0) {
      return 'expires today';
    }
    if (item.daysLeft == 1) {
      return '1 day remaining';
    }
    return '${item.daysLeft} days remaining';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF03131F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              Color(0xFF0E3954),
              Color(0xFF04111B),
              Color(0xFF02070D),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFF73E9FF),
            backgroundColor: const Color(0xFF091B29),
            onRefresh: _loadHistory,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                _buildCentralOrb(),
                const SizedBox(height: 24),
                _buildOverviewGrid(),
                const SizedBox(height: 24),
                _buildConversationPanel(theme),
                const SizedBox(height: 18),
                _buildQuickActions(),
                const SizedBox(height: 18),
                _buildThreatPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JARVIS',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF9BEFFF),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Just A Rather Very Intelligent System',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF75BFD2),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2232),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF3AD8F6).withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SUIT LINK',
                style: TextStyle(
                  color: Color(0xFF7FEFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFF8CF4FF), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCentralOrb() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.9 + (math.sin(_controller.value * math.pi * 2) * 0.08);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF2CE6FF).withOpacity(0.25)),
            color: const Color(0xFF061824),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2CE6FF).withOpacity(0.16),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFC6FBFF),
                        Color(0xFF42DFFF),
                        Color(0xFF0A5F85),
                        Color(0xFF042032),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF76F3FF).withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(3, (index) {
                        final rotation = (_controller.value * 2 * math.pi) +
                            (index * 0.8);
                        return Transform.rotate(
                          angle: rotation,
                          child: Container(
                            width: 188 - (index * 28),
                            height: 188 - (index * 28),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      }),
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'VOICE CORE ACTIVE',
                style: TextStyle(
                  color: Color(0xFF9BEFFF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _history.isEmpty
                    ? 'Awaiting first directive.'
                    : 'Monitoring ${_history.length} product signatures in real time.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBEFF7),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewGrid() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _HudStatCard(
          title: 'Tracked Assets',
          value: _history.length.toString().padLeft(2, '0'),
          accent: const Color(0xFF54E6FF),
          icon: Icons.inventory_2_outlined,
        ),
        _HudStatCard(
          title: 'Fresh Systems',
          value: _fresh.length.toString().padLeft(2, '0'),
          accent: const Color(0xFF67F5B5),
          icon: Icons.verified_outlined,
        ),
        _HudStatCard(
          title: 'Priority Alerts',
          value: _expiringSoon.length.toString().padLeft(2, '0'),
          accent: const Color(0xFFFFC15B),
          icon: Icons.warning_amber_rounded,
        ),
        _HudStatCard(
          title: 'Critical Failures',
          value: _expired.length.toString().padLeft(2, '0'),
          accent: const Color(0xFFFF6E7C),
          icon: Icons.error_outline_rounded,
        ),
      ],
    );
  }

  Widget _buildConversationPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF071722),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2BE5FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Command Feed',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ..._messages.map((message) {
            final isJarvis = message.speaker == 'JARVIS';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isJarvis
                    ? const Color(0xFF0A2638)
                    : const Color(0xFF111B24),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isJarvis
                      ? const Color(0xFF34E7FF).withOpacity(0.28)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.speaker,
                    style: TextStyle(
                      color: isJarvis
                          ? const Color(0xFF93F3FF)
                          : const Color(0xFFBFC8D0),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Color(0xFFE4F7FB),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rapid Directives',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DirectiveChip(
              label: 'Run Scanner',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => widget.onNavigate(1),
            ),
            _DirectiveChip(
              label: 'Generate QR',
              icon: Icons.auto_awesome,
              onTap: () => widget.onNavigate(2),
            ),
            _DirectiveChip(
              label: 'Open Inventory',
              icon: Icons.dashboard_customize_outlined,
              onTap: () => widget.onNavigate(3),
            ),
            _DirectiveChip(
              label: 'Refresh Intel',
              icon: Icons.sync_rounded,
              onTap: _loadHistory,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThreatPanel() {
    final watchList = _history.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF09131D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2BE5FF).withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Threat Assessment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (watchList.isEmpty)
            const Text(
              'No active inventory detected. System recommends onboarding your first product.',
              style: TextStyle(color: Color(0xFFCBE5EE), height: 1.4),
            )
          else
            ...watchList.map((item) {
              final color = item.status == 'Expired'
                  ? const Color(0xFFFF6E7C)
                  : item.status == 'Expiring Soon'
                      ? const Color(0xFFFFC15B)
                      : const Color(0xFF67F5B5);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.track_changes_rounded, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expiry ${item.expiryText} • ${_statusLine(item)}',
                            style: const TextStyle(
                              color: Color(0xFFC4DFE7),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _HudStatCard extends StatelessWidget {
  const _HudStatCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 54) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071824),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFC4E5ED),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectiveChip extends StatelessWidget {
  const _DirectiveChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A2435),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF30E7FF).withOpacity(0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF92F4FF)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JarvisMessage {
  const _JarvisMessage({
    required this.speaker,
    required this.text,
  });

  final String speaker;
  final String text;
}
