import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:omi/backend/preferences.dart';

/// Full-screen self-hosted setup wizard shown on first launch.
/// Collects backend URL (required) and optional custom Firebase config.
/// After saving, requires an app restart to apply the Firebase configuration.
class SelfHostedSetupPage extends StatefulWidget {
  const SelfHostedSetupPage({super.key});

  @override
  State<SelfHostedSetupPage> createState() => _SelfHostedSetupPageState();
}

class _SelfHostedSetupPageState extends State<SelfHostedSetupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1 — backend URL
  final _backendUrlController = TextEditingController();
  final _backendUrlFormKey = GlobalKey<FormState>();

  // Step 2 — Firebase config (all optional as a group)
  final _firebaseProjectIdController = TextEditingController();
  final _firebaseApiKeyController = TextEditingController();
  final _firebaseAppIdController = TextEditingController();
  final _firebaseSenderIdController = TextEditingController();
  bool _useCustomFirebase = false;

  @override
  void dispose() {
    _pageController.dispose();
    _backendUrlController.dispose();
    _firebaseProjectIdController.dispose();
    _firebaseApiKeyController.dispose();
    _firebaseAppIdController.dispose();
    _firebaseSenderIdController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() => _currentPage++);
  }

  void _prevPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() => _currentPage--);
  }

  bool _validateBackendUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  void _onStep1Next() {
    if (_backendUrlFormKey.currentState!.validate()) {
      _nextPage();
    }
  }

  void _onFinish() {
    // Ensure backend URL ends with /
    String url = _backendUrlController.text.trim();
    if (!url.endsWith('/')) url = '$url/';

    final prefs = SharedPreferencesUtil();
    prefs.customBackendUrl = url;

    if (_useCustomFirebase) {
      prefs.selfHostedFirebaseProjectId = _firebaseProjectIdController.text.trim();
      prefs.selfHostedFirebaseApiKey    = _firebaseApiKeyController.text.trim();
      prefs.selfHostedFirebaseAppId     = _firebaseAppIdController.text.trim();
      prefs.selfHostedFirebaseSenderId  = _firebaseSenderIdController.text.trim();
    }

    prefs.selfHostedSetupCompleted = true;

    // Firebase is already initialized with either the custom config (subsequent
    // launches) or Omi's default config (this first launch). A restart is needed
    // only when the user provided custom Firebase credentials for the first time.
    final needsRestart = _useCustomFirebase &&
        _firebaseProjectIdController.text.trim().isNotEmpty;

    // Always restart — ensures backend URL and Firebase config are loaded
    // cleanly from SharedPreferences in _init() on next launch.
    _showRestartDialog(needsFirebaseNote: needsRestart);
  }

  void _showRestartDialog({required bool needsFirebaseNote}) {
    final body = needsFirebaseNote
        ? 'Your settings have been saved.\n\n'
          'The app needs to restart to apply your custom Firebase authentication settings.\n\n'
          'Please close and reopen the app.'
        : 'Your backend URL has been saved.\n\n'
          'Please close and reopen the app to connect to your self-hosted backend.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Setup Complete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(body, style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => exit(0),
            child: const Text('Close App', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildBackendUrlPage(),
                  _buildFirebasePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= _currentPage ? Colors.deepPurpleAccent : Colors.grey.shade800,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Page 0: Welcome ────────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Omi\nSelf-Hosted',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your pendant. Your server. Your data.',
            style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          _bulletPoint('Audio never touches Omi\'s cloud'),
          _bulletPoint('Connect your own self-hosted backend'),
          _bulletPoint('Optional: use your own Firebase project for auth'),
          _bulletPoint('Full Omi feature set — conversations, memories, apps'),
          const Spacer(),
          _primaryButton('Get Started', _nextPage),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.deepPurpleAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ─── Page 1: Backend URL ────────────────────────────────────────────────────

  Widget _buildBackendUrlPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Form(
        key: _backendUrlFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('Backend URL', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Enter the URL of your self-hosted Omi backend. This is where all your audio and conversations will be sent.',
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _backendUrlController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _inputDecoration(
                label: 'Backend URL',
                hint: 'https://omi.example.com/',
                icon: Icons.dns_outlined,
              ),
              validator: (v) => _validateBackendUrl(v) ? null : 'Enter a valid https:// URL',
            ),
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.info_outline,
              text: 'Your backend should be running the Omi Python backend. '
                  'See github.com/BasedHardware/omi for setup instructions.',
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                _secondaryButton('Back', _prevPage),
                const SizedBox(width: 12),
                Expanded(child: _primaryButton('Next', _onStep1Next)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page 2: Firebase Config ─────────────────────────────────────────────────

  Widget _buildFirebasePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Firebase Auth', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'By default, sign-in uses Omi\'s Firebase project (based-hardware-dev). '
            'Your conversations still go to your own backend.\n\n'
            'For complete independence, bring your own Firebase project below.',
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _useCustomFirebase,
            onChanged: (v) => setState(() => _useCustomFirebase = v),
            title: const Text('Use my own Firebase project', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Requires Firebase Console setup', style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: Colors.deepPurpleAccent,
            contentPadding: EdgeInsets.zero,
          ),
          if (_useCustomFirebase) ...[
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.open_in_new,
              text: 'Find these values in Firebase Console → Project Settings → General → Your apps (iOS).',
            ),
            const SizedBox(height: 20),
            _firebaseField(_firebaseProjectIdController, 'Project ID', 'my-project-123', Icons.folder_outlined),
            const SizedBox(height: 14),
            _firebaseField(_firebaseApiKeyController, 'Web API Key', 'AIzaSy...', Icons.key_outlined),
            const SizedBox(height: 14),
            _firebaseField(_firebaseAppIdController, 'iOS App ID', '1:123456:ios:abc', Icons.phone_iphone),
            const SizedBox(height: 14),
            _firebaseField(_firebaseSenderIdController, 'Sender ID', '1031333818730', Icons.send_outlined),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              _secondaryButton('Back', _prevPage),
              const SizedBox(width: 12),
              Expanded(child: _primaryButton('Save & Continue', _onFinish)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _firebaseField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      autocorrect: false,
      enableSuggestions: false,
      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: Icon(icon, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  Widget _infoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurpleAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
