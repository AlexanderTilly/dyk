import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/flag_icon.dart';

import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../theme/dyk_theme.dart';
import '../widgets/category_badge.dart';
import 'auth_screen.dart';
import 'support_screen.dart';
import '../i18n/i18n.dart';

/// User settings: profile (name + avatar), notifications & interests,
/// about, and account actions (sign out / delete account).
class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final AppState appState;
  final VoidCallback onToggleExploring;
  final VoidCallback onAuthChanged;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.appState,
    required this.onToggleExploring,
    required this.onAuthChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  String _gender = 'male';
  bool _saving = false;

  static const _interestKeys = [
    'history', 'otium', 'headline', 'hotdeal',
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.authService.currentUser;
    _nameCtrl = TextEditingController(
        text: (u?.userMetadata?['display_name'] as String?) ?? '');
    _gender = (u?.userMetadata?['gender'] as String?) ?? 'male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final err = await widget.authService.updateProfile(
      displayName: _nameCtrl.text,
      gender: _gender,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? tr('profile_saved'))),
    );
    if (err == null) widget.onAuthChanged();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_confirm_title')),
        content: Text(tr('delete_confirm_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final err = await widget.authService.deleteAccount();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    widget.onAuthChanged();
    Navigator.of(context).pop();
  }

  Widget _section(String title, List<Widget> children) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: PassimColors.brand)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _avatarChoice(String gender, String asset, String label) {
    final selected = _gender == gender;
    return GestureDetector(
      onTap: () => setState(() => _gender = gender),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? DykColors.yellow : Colors.transparent,
                width: 3,
              ),
            ),
            child: CircleAvatar(radius: 34, backgroundImage: AssetImage(asset)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.authService.isSignedIn;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(tr('settings'), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          color: dark
              ? Colors.black.withValues(alpha: 0.72)
              : PassimColors.sand.withValues(alpha: 0.85),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Profile ---
              if (signedIn)
                _section(tr('profile'), [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _avatarChoice(
                          'male', 'assets/images/avatar_male.png', 'Explorer'),
                      _avatarChoice('female', 'assets/images/avatar_female.png',
                          'Explorer'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: tr('display_name'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: Text(_saving ? tr('sending') : tr('save_profile')),
                    ),
                  ),
                ])
              else
                _section(tr('profile'), [
                  Text(tr('guest_settings'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(tr('guest_settings_sub')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                AuthScreen(authService: widget.authService),
                          ),
                        );
                        if (ok == true && mounted) {
                          widget.onAuthChanged();
                          setState(() {
                            final u = widget.authService.currentUser;
                            _nameCtrl.text =
                                (u?.userMetadata?['display_name'] as String?) ??
                                    '';
                            _gender =
                                (u?.userMetadata?['gender'] as String?) ??
                                    'male';
                          });
                        }
                      },
                      child: Text(tr('sign_in_create')),
                    ),
                  ),
                ]),

              // --- Notifications ---
              AnimatedBuilder(
                animation: widget.appState,
                builder: (context, _) => _section(tr('notifications'), [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: widget.appState.isExploring,
                    activeColor: DykColors.yellow,
                    title: Text(tr('exploring'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(tr('exploring_sub'),
                        style: const TextStyle(fontSize: 12)),
                    onChanged: (_) => widget.onToggleExploring(),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('active_interests'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in _interestKeys)
                        FilterChip(
                          selected:
                              widget.appState.interests.contains(k),
                          selectedColor: DykColors.yellow,
                          checkmarkColor: Colors.white,
                          avatar: CategoryBadge(category: k, size: 24),
                          label: Text(tr('cat_$k')),
                          onSelected: (_) =>
                              widget.appState.toggleInterest(k),
                        ),
                    ],
                  ),
                ]),
              ),

              // --- Language ---
              _section(tr('language'), [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in I18n.supported)
                      ChoiceChip(
                        selected: I18n.instance.code == code,
                        selectedColor: DykColors.yellow,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FlagIcon(code: code, width: 24),
                            const SizedBox(width: 7),
                            Text(I18n.names[code]!),
                          ],
                        ),
                        onSelected: (_) async {
                          await I18n.instance.setCode(code);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              ]),

              // --- About ---
              _section(tr('about'), [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.info_outline, color: PassimColors.brand),
                  title: const Text('Did You Know?'),
                  subtitle: Text(tr('tagline')),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.new_releases_outlined,
                        color: PassimColors.brand),
                    title: Text(tr('app_version')),
                    subtitle: Text(snap.hasData
                        ? '${snap.data!.version} (build ${snap.data!.buildNumber})'
                        : '…'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.help_outline, color: PassimColors.brand),
                  title: Text(tr('help_support')),
                  subtitle: Text(tr('help_reply')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        SupportScreen(authService: widget.authService),
                  )),
                ),
              ]),

              // --- Account ---
              if (signedIn)
                _section(tr('account'), [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.logout, color: PassimColors.brand),
                    title: Text(tr('sign_out')),
                    onTap: () async {
                      await widget.authService.signOut();
                      widget.onAuthChanged();
                      if (mounted) Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever,
                        color: Colors.redAccent),
                    title: Text(tr('delete_account'),
                        style: const TextStyle(color: Colors.redAccent)),
                    subtitle: Text(tr('delete_account_sub'),
                        style: const TextStyle(fontSize: 12)),
                    onTap: _confirmDelete,
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
