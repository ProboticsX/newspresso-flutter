import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

      if (webClientId.isEmpty) {
        throw Exception('GOOGLE_WEB_CLIENT_ID is missing from .env file.');
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('No access/id token received from Google.');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App icon
              ClipOval(
                child: Image.asset(
                  'appicon.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Newspresso',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your Personalized News Hub',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),

              const Spacer(flex: 2),

              // Feature cards
              _FeatureCard(
                icon: Icons.feed_outlined,
                title: 'AI Curated Headlines',
                subtitle: 'Read what matters to you',
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.headphones,
                title: 'AI News Podcasts',
                subtitle: 'Listen to news on the go',
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.psychology_outlined,
                title: 'Smart Assistant',
                subtitle: 'Ask questions, Be curious',
              ),

              const Spacer(flex: 2),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Sign in button
              GestureDetector(
                onTap: _isLoading ? null : _signInWithGoogle,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFFC8936A),
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GoogleLogo(),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'By signing in, you agree to our Terms of Service and\nPrivacy Policy',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              const Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1410),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFC8936A), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final ar = r * 0.64;
    final sw = r * 0.27;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: ar);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    // Gap on the right (3 o'clock), ±0.45 rad.
    // Clockwise from gap bottom: Red → Yellow → Green → Blue
    canvas.drawArc(rect, 0.45, 0.85, false, paint..color = const Color(0xFFEA4335));
    canvas.drawArc(rect, 1.30, 1.55, false, paint..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, 2.85, 1.60, false, paint..color = const Color(0xFF34A853));
    canvas.drawArc(rect, 4.45, 1.38, false, paint..color = const Color(0xFF4285F4));

    // Horizontal crossbar at center-y, from center to arc edge
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + ar, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
