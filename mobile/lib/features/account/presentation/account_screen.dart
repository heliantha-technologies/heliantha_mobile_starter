import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../shared/theme/app_vector_icons.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../notifications/services/fcm_service.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Compte client',
        actions: [NotificationBell()],
      ),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final friendly = friendlyLoadError(error);
          return ResponsivePagePadding(
            child: AppStatusPanel(
              icon: Icons.cloud_off_rounded,
              title: friendly.title,
              message: friendly.message,
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(currentUserProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
          );
        },
        data: (data) => _AccountBody(
          userData: data,
          onLogout: () async {
            await ref.read(fcmServiceProvider).unregisterCurrentDevice();
            await ref.read(authRepositoryProvider).logout();
            ref.invalidate(currentUserProvider);
            if (context.mounted) {
              AppFeedback.info(context, 'À bientôt');
            }
          },
        ),
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.userData,
    required this.onLogout,
  });

  final Map<String, dynamic>? userData;
  final VoidCallback onLogout;

  String _computeInitials(String firstname, String lastname, String email) {
    final parts = [firstname, lastname]
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => String.fromCharCode(s.runes.first).toUpperCase())
        .join();
    if (parts.isNotEmpty) return parts;
    if (email.isNotEmpty) {
      return String.fromCharCode(email.runes.first).toUpperCase();
    }
    return 'H';
  }

  @override
  Widget build(BuildContext context) {
    final data = userData;
    final loggedIn = data != null;
    final email = data?['email']?.toString().trim() ?? '';
    final firstname = data?['firstname']?.toString().trim() ?? '';
    final lastname = data?['lastname']?.toString().trim() ?? '';
    final fullName = [firstname, lastname].where((s) => s.isNotEmpty).join(' ');
    final identity = fullName.isNotEmpty
        ? fullName
        : (email.isNotEmpty ? email : 'Compte Heliantha');
    final initials = _computeInitials(firstname, lastname, email);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final isDesktop = width >= 820;
        final contactColumns = width >= 980 ? 4 : 2;

        final tileExtent = (isDesktop ? 112.0 : 94.0) +
            (textScale - 1.0).clamp(0.0, 1.0) * 34.0;

        final accountHero = loggedIn
            ? _MemberHeroCard(
                identity: identity,
                email: email,
                initials: initials,
                isWide: isDesktop,
              )
            : _GuestHeroCard(
                isWide: isDesktop,
                onLogin: () => context.push(loginLocationFor('/account')),
                onRegister: () => context.push(
                  '/register?redirect=${Uri.encodeComponent('/account')}',
                ),
              );

        final memberShortcuts = loggedIn
            ? _MemberShortcutsRow(
                onOrders: () => context.push('/orders'),
                onAddresses: () => context.push('/addresses'),
              )
            : const SizedBox.shrink();

        final contactGrid = _ContactSection(
          tileExtent: tileExtent,
          crossAxisCount: contactColumns,
        );

        final footerBar = loggedIn
            ? _MemberFooterBar(
                onPrivacy: () => context.push('/privacy'),
                onLogout: onLogout,
              )
            : _PrivacyFooterBar(
                onTap: () => context.push('/privacy'),
              );

        if (isDesktop) {
          final desktopContent = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    accountHero,
                    if (loggedIn) ...[
                      const SizedBox(height: 16),
                      memberShortcuts,
                    ],
                    const SizedBox(height: 22),
                    contactGrid,
                    const SizedBox(height: 16),
                    footerBar,
                  ],
                ),
              ),
            ),
          );

          final desktopNeedsScroll = height < 520 || textScale > 1.25;
          if (desktopNeedsScroll) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 84),
              child: desktopContent,
            );
          }
          return desktopContent;
        }

        // Mobile : pleine largeur moderne et aligné en haut, sans scroll sur formats standards (ex. 390x844),
        // et active le scroll uniquement si l'écran est très compact ou la police agrandie.
        final baseRequiredHeight = loggedIn ? 595.0 : 540.0;
        final adjustedRequired =
            baseRequiredHeight + (textScale - 1.0).clamp(0.0, 1.0) * 160.0;
        final needsScroll = height < adjustedRequired || textScale > 1.20;

        final mobileColumn = Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            needsScroll ? 12 : 20,
            10,
            needsScroll ? 88 : 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              accountHero,
              if (loggedIn) ...[
                const SizedBox(height: 12),
                memberShortcuts,
              ],
              SizedBox(height: loggedIn ? 18 : 20),
              contactGrid,
              const SizedBox(height: 16),
              footerBar,
            ],
          ),
        );

        if (needsScroll) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: mobileColumn,
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: mobileColumn,
        );
      },
    );
  }
}

/// Surface architecturale Marine & Or partagée par les cartes d'en-tête compte.
class _ExecutiveHeroSurface extends StatelessWidget {
  const _ExecutiveHeroSurface({
    required this.padding,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.55, 1.0],
          colors: [
            Color(0xFF071728),
            Color(0xFF0E2949),
            Color(0xFF17406D),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFF4C33D).withValues(alpha: 0.36),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF071728).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SolarHeroArcsPainter(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SolarHeroArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.92, size.height * 0.14);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF4C33D).withValues(alpha: 0.22),
          const Color(0xFF38BDF8).withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 135));
    canvas.drawCircle(center, 135, glowPaint);

    final arcGold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFF4C33D).withValues(alpha: 0.16);
    canvas.drawCircle(center, 58, arcGold);

    final arcBlue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, 98, arcBlue);

    // Liseré lumineux subtil en bordure supérieure façon verre 2026.
    final rimPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.28),
          const Color(0xFFF4C33D).withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GuestHeroCard extends StatelessWidget {
  const _GuestHeroCard({
    required this.isWide,
    required this.onLogin,
    required this.onRegister,
  });

  final bool isWide;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4C33D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFF4C33D).withValues(alpha: 0.42),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 2.8,
                    backgroundColor: Color(0xFFF4C33D),
                  ),
                  SizedBox(width: 5.5),
                  Flexible(
                    child: Text(
                      'ESPACE HELIANTHA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 11.5,
                    color: Color(0xFF6EE7B7),
                  ),
                  SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Sans compte possible',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isWide ? 12 : 11),
        Row(
          children: [
            Container(
              width: isWide ? 44 : 40,
              height: isWide ? 44 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF4C33D).withValues(alpha: 0.24),
                    const Color(0xFFF4C33D).withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFF4C33D).withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: Color(0xFFF4C33D),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Espace client Heliantha',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWide ? 20 : 17.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Suivez vos commandes, adresses et devis.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFCBD5E1),
                      fontSize: isWide ? 13 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final buttonsRow = Row(
      children: [
        Expanded(
          child: _HeroActionButton(
            label: 'Se connecter',
            icon: Icons.login_rounded,
            primary: true,
            onTap: onLogin,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HeroActionButton(
            label: 'Créer un compte',
            icon: Icons.person_add_alt_1_rounded,
            primary: false,
            onTap: onRegister,
          ),
        ),
      ],
    );

    return _ExecutiveHeroSurface(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 24 : 16,
        vertical: isWide ? 20 : 15,
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: headerContent),
                const SizedBox(width: 24),
                SizedBox(width: 390, child: buttonsRow),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerContent,
                const SizedBox(height: 15),
                buttonsRow,
              ],
            ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: widget.primary
                ? LinearGradient(
                    colors: _hovered
                        ? const [Color(0xFFFDE047), Color(0xFFF4C33D)]
                        : const [Color(0xFFF4C33D), Color(0xFFE5A93C)],
                  )
                : null,
            color: widget.primary
                ? null
                : Colors.white.withValues(alpha: _hovered ? 0.16 : 0.10),
            border: widget.primary
                ? null
                : Border.all(
                    color:
                        Colors.white.withValues(alpha: _hovered ? 0.45 : 0.28),
                  ),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: const Color(0xFFF4C33D)
                          .withValues(alpha: _hovered ? 0.34 : 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: 16,
                        color:
                            widget.primary ? const Color(0xFF0B2239) : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: widget.primary
                              ? const Color(0xFF0B2239)
                              : Colors.white,
                          fontWeight: widget.primary
                              ? FontWeight.w900
                              : FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberHeroCard extends StatelessWidget {
  const _MemberHeroCard({
    required this.identity,
    required this.email,
    required this.initials,
    required this.isWide,
  });

  final String identity;
  final String email;
  final String initials;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return _ExecutiveHeroSurface(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 24 : 16,
        vertical: isWide ? 18 : 15,
      ),
      child: Row(
        children: [
          Container(
            width: isWide ? 50 : 46,
            height: isWide ? 50 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF4C33D).withValues(alpha: 0.25),
                  const Color(0xFFF4C33D).withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFF4C33D).withValues(alpha: 0.65),
                width: 1.3,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFFF4C33D),
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWide ? 18.5 : 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (email.isNotEmpty && email != identity) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFCBD5E1),
                        fontSize: isWide ? 12.8 : 11.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.45),
              ),
            ),
            child: const Text(
              'Actif',
              style: TextStyle(
                color: Color(0xFF6EE7B7),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberShortcutsRow extends StatelessWidget {
  const _MemberShortcutsRow({
    required this.onOrders,
    required this.onAddresses,
  });

  final VoidCallback onOrders;
  final VoidCallback onAddresses;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            icon: Icons.receipt_long_rounded,
            title: 'Mes commandes',
            subtitle: 'Suivi & factures',
            iconColor: const Color(0xFF0A6097),
            iconBg: const Color(0xFFEAF3FA),
            onTap: onOrders,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.location_on_rounded,
            title: 'Mes adresses',
            subtitle: 'Livraison & facture',
            iconColor: const Color(0xFFB45309),
            iconBg: const Color(0xFFFFF5D6),
            onTap: onAddresses,
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ExecutiveCardBox(
      onTap: onTap,
      hoverBorderColor: iconColor.withValues(alpha: 0.45),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0B2239),
              fontSize: 13.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.tileExtent,
    this.crossAxisCount = 2,
  });

  final double tileExtent;
  final int crossAxisCount;

  static final Uri _phone = AppConfig.supportPhoneUri;
  static final Uri _whatsapp = AppConfig.supportWhatsAppUri();
  static final Uri _email = AppConfig.supportEmailUri;
  static final Uri _location = Uri.parse(
    'https://maps.app.goo.gl/NjXA6uSfcy4WEFMu6',
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppFeedback.info(
        context,
        'Impossible d’ouvrir l’application externe. Retrouvez nos coordonnées directes ci-dessous.',
      );
    }
  }

  Future<void> _copyValue(
    BuildContext context, {
    required String label,
    required String value,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    await HapticFeedback.selectionClick();
    if (context.mounted) {
      AppFeedback.success(context, '$label copié : $value');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact & assistance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF0B2239),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Appui long ou sélection pour copier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6EF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 2.8,
                    backgroundColor: Color(0xFF10B981),
                  ),
                  SizedBox(width: 4.5),
                  Text(
                    'Réponse rapide',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: tileExtent,
          children: [
            _ContactMiniTile(
              label: 'APPELER',
              value: AppConfig.supportPhoneDisplay,
              subtitle: 'Ligne directe',
              iconBg: const Color(0xFFFEF2F2),
              iconColor: const Color(0xFFDC2626),
              icon: Icons.phone_rounded,
              onTap: () => _open(context, _phone),
              onLongPress: () => _copyValue(
                context,
                label: 'Numéro',
                value: AppConfig.supportPhoneDisplay,
              ),
            ),
            _ContactMiniTile(
              label: 'WHATSAPP',
              value: AppConfig.supportWhatsAppDisplay,
              subtitle: 'Échange immédiat',
              iconBg: const Color(0xFF0B2239),
              iconColor: const Color(0xFF25D366),
              svgIcon: AppVectorIcons.whatsapp,
              onTap: () => _open(context, _whatsapp),
              onLongPress: () => _copyValue(
                context,
                label: 'WhatsApp',
                value: AppConfig.supportWhatsAppDisplay,
              ),
            ),
            _ContactMiniTile(
              label: 'E-MAIL',
              value: AppConfig.supportEmail,
              subtitle: 'Réponse sous 24h',
              iconBg: const Color(0xFFEAF3FA),
              iconColor: const Color(0xFF0A6097),
              icon: Icons.mail_rounded,
              onTap: () => _open(context, _email),
              onLongPress: () => _copyValue(
                context,
                label: 'E-mail',
                value: AppConfig.supportEmail,
              ),
            ),
            _ContactMiniTile(
              label: 'NOUS TROUVER',
              value: 'Ouvrir Google Maps',
              subtitle: 'Itinéraire Heliantha',
              iconBg: const Color(0xFFFFF5D6),
              iconColor: const Color(0xFFB45309),
              icon: Icons.location_on_rounded,
              onTap: () => _open(context, _location),
              onLongPress: () => _copyValue(
                context,
                label: 'Lien Maps',
                value: _location.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContactMiniTile extends StatelessWidget {
  const _ContactMiniTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.svgIcon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final String? svgIcon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cliquer pour ouvrir • Maintenir pour copier',
      waitDuration: const Duration(milliseconds: 550),
      child: _ExecutiveCardBox(
        onTap: onTap,
        onLongPress: onLongPress,
        hoverBorderColor: iconColor.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: svgIcon != null
                      ? AppSvgIcon(svgIcon!, size: 16, color: iconColor)
                      : Icon(icon, size: 16.5, color: iconColor),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0A6097),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectionArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B2239),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyFooterBar extends StatelessWidget {
  const _PrivacyFooterBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ExecutiveCardBox(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: const Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: Color(0xFF0A6097),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Politique de confidentialité & données',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF0B2239),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}

class _MemberFooterBar extends StatelessWidget {
  const _MemberFooterBar({
    required this.onPrivacy,
    required this.onLogout,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ExecutiveCardBox(
            onTap: onPrivacy,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16.5,
                  color: Color(0xFF0A6097),
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Confidentialité',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF0B2239),
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ExecutiveCardBox(
            onTap: onLogout,
            radius: 14,
            backgroundColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFCA5A5).withValues(alpha: 0.7),
            hoverBorderColor: const Color(0xFFEF4444),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 16.5,
                  color: Color(0xFFDC2626),
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Déconnexion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte nacrée exécutive réutilisable avec état de survol et clic propre.
class _ExecutiveCardBox extends StatefulWidget {
  const _ExecutiveCardBox({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.backgroundColor,
    this.borderColor,
    this.hoverBorderColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;

  @override
  State<_ExecutiveCardBox> createState() => _ExecutiveCardBoxState();
}

class _ExecutiveCardBoxState extends State<_ExecutiveCardBox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.radius);
    final baseBg =
        widget.backgroundColor ?? Colors.white.withValues(alpha: 0.94);
    final baseBorder = widget.borderColor ?? const Color(0xFFD7E2EE);
    final hoverBorder =
        widget.hoverBorderColor ?? const Color(0xFF0A6097).withValues(alpha: 0.45);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: borderRadius,
          border: Border.all(
            color: _hovered ? hoverBorder : baseBorder,
            width: _hovered ? 1.25 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2239).withValues(
                alpha: _hovered ? 0.10 : 0.05,
              ),
              blurRadius: _hovered ? 16 : 12,
              offset: Offset(0, _hovered ? 6 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
