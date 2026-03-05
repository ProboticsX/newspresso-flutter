import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanPage extends StatefulWidget {
  final bool isPremium;

  const PlanPage({super.key, required this.isPremium});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late bool _isPremium;
  bool _isUpdating = false;

  static const _amber = Color(0xFFC8936A);

  @override
  void initState() {
    super.initState();
    _isPremium = widget.isPremium;
  }

  Future<void> _selectPlan(bool premium) async {
    if (_isPremium == premium || _isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('users')
            .update({'is_premium': premium})
            .eq('id', userId);
      }
      if (mounted) setState(() => _isPremium = premium);
    } catch (_) {
      if (mounted) setState(() => _isPremium = !premium); // revert
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Back button + Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context, _isPremium),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white24, width: 0.5),
                          color: Colors.white.withValues(alpha: 0.0),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6.0),
                          child: Icon(Icons.arrow_back_ios,
                              size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Current Plan ──────────────────────────────────
                      const Text(
                        'Current Plan',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _amber.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A1A0A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.workspace_premium,
                                  color: _amber, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPremium
                                        ? 'Newspresso Black'
                                        : 'Free Plan',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _isPremium
                                        ? 'Premium Plan'
                                        : 'Basic features included',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _amber,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Choose Plan ───────────────────────────────────
                      const Row(
                        children: [
                          Icon(Icons.credit_card, color: _amber, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Choose Your Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Free Plan Card ────────────────────────────────
                      _PlanCard(
                        selected: !_isPremium,
                        onTap: _isUpdating ? null : () => _selectPlan(false),
                        icon: Icons.star_border,
                        title: 'Free Plan',
                        subtitle: 'Basic features included',
                        price: 'Free',
                        features: const [
                          'Access to basic news feed with ads',
                          'Limited podcast episodes',
                          'Limited Assistant queries',
                          'Geo restricted news feed',
                          'Standard news categories',
                        ],
                        featureStyle: _FeatureStyle.muted,
                      ),

                      const SizedBox(height: 12),

                      // ── Black Plan Card ───────────────────────────────
                      _PlanCard(
                        selected: _isPremium,
                        onTap: _isUpdating ? null : () => _selectPlan(true),
                        icon: Icons.workspace_premium,
                        title: 'Newspresso Black',
                        subtitle: 'Premium features included',
                        price: r'$3.99/month',
                        priceNote: '(Unlimited Free Trial)',
                        features: const [
                          'No ads in podcasts and news feed',
                          'Unlimited podcast episodes',
                          'Unlimited queries from Newspresso Assistant',
                          'Travel Mode: switch location for news',
                          'Set unlimited custom news categories',
                        ],
                        featureStyle: _FeatureStyle.green,
                      ),

                      if (_isUpdating) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          color: _amber,
                          backgroundColor: Colors.white12,
                          minHeight: 2,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FeatureStyle { muted, green }

class _PlanCard extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final String? priceNote;
  final List<String> features;
  final _FeatureStyle featureStyle;

  static const _amber = Color(0xFFC8936A);

  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    this.priceNote,
    required this.features,
    required this.featureStyle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F0F0F) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _amber.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2A1A0A)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      color: selected ? _amber : Colors.white38, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: selected ? _amber : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (priceNote != null)
                      Text(
                        priceNote!,
                        style: TextStyle(
                          color: selected ? _amber : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: featureStyle == _FeatureStyle.green
                            ? Colors.greenAccent
                            : Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: featureStyle == _FeatureStyle.green
                                ? Colors.white70
                                : Colors.white38,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
