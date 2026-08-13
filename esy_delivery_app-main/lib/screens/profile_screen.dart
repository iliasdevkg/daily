import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import 'addresses_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'order_history_screen.dart';

// ─── Predefined avatars ───────────────────────────────────────────────────────
const _avatars = [
  ('🦊', Color(0xFFFF7043), Color(0xFFFFECE8)),
  ('🐨', Color(0xFF78909C), Color(0xFFECEFF1)),
  ('🦁', Color(0xFFFFA726), Color(0xFFFFF8E1)),
  ('🐸', Color(0xFF66BB6A), Color(0xFFE8F5E9)),
  ('🐼', Color(0xFF455A64), Color(0xFFECEFF1)),
  ('🦋', Color(0xFFAB47BC), Color(0xFFF3E5F5)),
  ('🐯', Color(0xFFFF8F00), Color(0xFFFFF8E1)),
  ('🦅', Color(0xFF5C6BC0), Color(0xFFE8EAF6)),
  ('🌺', Color(0xFFEC407A), Color(0xFFFCE4EC)),
  ('🚀', Color(0xFF26C6DA), Color(0xFFE0F7FA)),
  ('🦝', Color(0xFF8D6E63), Color(0xFFEFEBE9)),
  ('🐺', Color(0xFF7E57C2), Color(0xFFEDE7F6)),
];

// ─── Profile store (SharedPrefs) ─────────────────────────────────────────────
class _ProfileData {
  final String name;
  final String? imagePath; // gallery image
  final int? avatarIndex; // predefined avatar index

  const _ProfileData({this.name = '', this.imagePath, this.avatarIndex});
}

Future<_ProfileData> _loadProfile() async {
  final p = await SharedPreferences.getInstance();
  return _ProfileData(
    name: p.getString('profile.name') ?? '',
    imagePath: p.getString('profile.imagePath'),
    avatarIndex: p.containsKey('profile.avatarIndex')
        ? p.getInt('profile.avatarIndex')
        : null,
  );
}

Future<void> _saveProfile(_ProfileData d) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('profile.name', d.name);
  if (d.imagePath != null) {
    await p.setString('profile.imagePath', d.imagePath!);
    await p.remove('profile.avatarIndex');
  } else if (d.avatarIndex != null) {
    await p.setInt('profile.avatarIndex', d.avatarIndex!);
    await p.remove('profile.imagePath');
  } else {
    await p.remove('profile.imagePath');
    await p.remove('profile.avatarIndex');
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _ProfileData _data = const _ProfileData();
  bool _loadingImage = false;
  int? _orderCount;
  int? _addressCount;

  @override
  void initState() {
    super.initState();
    _loadProfile().then((d) => setState(() => _data = d));
    _loadStats();
  }

  Future<void> _loadStats() async {
    final api = context.read<Api>();
    try {
      final orders = await api.myOrders();
      if (mounted) setState(() => _orderCount = orders.length);
    } catch (_) {}
    try {
      final addresses = await api.myAddresses();
      if (mounted) setState(() => _addressCount = addresses.length);
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    setState(() => _loadingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        final nd = _ProfileData(name: _data.name, imagePath: picked.path);
        await _saveProfile(nd);
        setState(() {
          _data = nd;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() => _loadingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        final nd = _ProfileData(name: _data.name, imagePath: picked.path);
        await _saveProfile(nd);
        setState(() {
          _data = nd;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  Future<void> _selectAvatar(int index) async {
    final nd = _ProfileData(name: _data.name, avatarIndex: index);
    await _saveProfile(nd);
    setState(() {
      _data = nd;
    });
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _data.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Ваше имя', style: Theme.of(ctx).textTheme.titleLarge),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Введите имя',
            filled: true,
            fillColor: AppColors.zinc100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      final nd = _ProfileData(
        name: result.trim(),
        imagePath: _data.imagePath,
        avatarIndex: _data.avatarIndex,
      );
      await _saveProfile(nd);
      setState(() {
        _data = nd;
      });
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _AvatarPickerSheet(
        current: _data,
        onGallery: () {
          Navigator.pop(context);
          _pickFromGallery();
        },
        onCamera: () {
          Navigator.pop(context);
          _pickFromCamera();
        },
        onAvatar: (i) {
          Navigator.pop(context);
          _selectAvatar(i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).top;
    final authUser = context.watch<AuthStore>().user;
    final name = _data.name.isNotEmpty
        ? _data.name
        : (authUser?.name ?? 'Гость');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, pad, 0, 140),
        children: [
          // ── Header card ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brand500.withValues(alpha: 0.12),
                  AppColors.brand100.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.brand200.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    children: [
                      _AvatarWidget(
                        data: _data,
                        size: 80,
                        loading: _loadingImage,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.brand500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '/ профиль',
                        style: AppTypography.mono(
                          size: 10,
                          color: AppColors.brand700,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: _editName,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppColors.zinc400,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand500,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'D',
                              style: GoogleFonts.pacifico(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Daily',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Stats ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _StatCard(
                  label: 'Заказов',
                  value: '${_orderCount ?? '—'}',
                  icon: Icons.shopping_bag_outlined,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Бонусы',
                  value: '0 с',
                  icon: Icons.bolt_rounded,
                  accent: true,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Адресов',
                  value: '${_addressCount ?? '—'}',
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
          ),

          // ── Menu ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '/ меню',
                  style: AppTypography.mono(
                    size: 10,
                    color: AppColors.zinc400,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...[
                  (
                    Icons.history_rounded,
                    'История заказов',
                    'Ваши прошлые заказы',
                    AppColors.brand500,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OrderHistoryScreen(),
                      ),
                    ),
                  ),
                  (
                    Icons.location_on_outlined,
                    'Адреса',
                    'Сохранённые адреса доставки',
                    AppColors.brand500,
                    () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const AddressesScreen(),
                          ),
                        )
                        .then((_) => _loadStats()),
                  ),
                  (
                    Icons.favorite_border_rounded,
                    'Избранное',
                    'Любимые товары',
                    const Color(0xFFEC407A),
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    ),
                  ),
                  (
                    Icons.notifications_none_rounded,
                    'Уведомления',
                    'Статус заказа и акции',
                    const Color(0xFFFFA726),
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  (
                    Icons.headset_mic_outlined,
                    'Поддержка',
                    'Связаться с нами',
                    const Color(0xFF5C6BC0),
                    null,
                  ),
                  (
                    Icons.logout_rounded,
                    'Чыгуу',
                    authUser?.email ?? '',
                    const Color(0xFFEF4444),
                    () => context.read<AuthStore>().logout(),
                  ),
                ].map(
                  (it) => _MenuTile(
                    icon: it.$1,
                    title: it.$2,
                    subtitle: it.$3,
                    color: it.$4,
                    onTap: it.$5,
                  ),
                ),
              ],
            ),
          ),

          // ── Bonus card ────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'БОНУСНЫЕ БАЛЛЫ',
                        style: AppTypography.mono(
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.5),
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '1 240',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '= 124 сома на следующий заказ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.brand500,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand500.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar widget ────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final _ProfileData data;
  final double size;
  final bool loading;
  const _AvatarWidget({
    required this.data,
    required this.size,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (loading) {
      inner = const CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.brand500,
      );
    } else if (data.imagePath != null && File(data.imagePath!).existsSync()) {
      inner = ClipOval(
        child: Image.file(
          File(data.imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (data.avatarIndex != null) {
      final av = _avatars[data.avatarIndex! % _avatars.length];
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: av.$3, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(av.$1, style: TextStyle(fontSize: size * 0.48)),
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.zinc100,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          color: AppColors.zinc400,
          size: size * 0.55,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.brand300.withValues(alpha: 0.5),
          width: 2.5,
        ),
      ),
      child: ClipOval(child: inner),
    );
  }
}

// ─── Avatar picker sheet ──────────────────────────────────────────────────────
class _AvatarPickerSheet extends StatelessWidget {
  final _ProfileData current;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<int> onAvatar;
  const _AvatarPickerSheet({
    required this.current,
    required this.onGallery,
    required this.onCamera,
    required this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.zinc200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Фото профиля',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите из галереи или наш аватар',
            style: TextStyle(color: AppColors.zinc500, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Gallery / Camera
          Row(
            children: [
              Expanded(
                child: _SourceBtn(
                  icon: Icons.photo_library_outlined,
                  label: 'Галерея',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onGallery();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SourceBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Камера',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCamera();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            '/ наши аватары',
            style: AppTypography.mono(
              size: 10,
              color: AppColors.zinc400,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // Avatar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _avatars.length,
            itemBuilder: (_, i) {
              final av = _avatars[i];
              final selected =
                  current.avatarIndex == i && current.imagePath == null;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAvatar(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: av.$3,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: av.$2, width: 3)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: av.$2.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(av.$1, style: const TextStyle(fontSize: 26)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.zinc100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.zinc200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.brand600),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool accent;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: accent ? AppColors.brand500 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: accent ? null : Border.all(color: AppColors.zinc100),
          boxShadow: accent
              ? [
                  BoxShadow(
                    color: AppColors.brand500.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: accent
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.brand500,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: accent ? Colors.white : AppColors.ink,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: accent
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.zinc500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu tile ────────────────────────────────────────────────────────────────
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.zinc100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.zinc500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.zinc400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
