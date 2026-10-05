import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/services/fcm_service.dart';
import '../../notifications/presentation/notification_bell.dart';

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
        data: (data) {
          if (data == null) {
            return const _GuestView();
          }
          final email = data['email']?.toString().trim() ?? '';
          final firstname = data['firstname']?.toString().trim() ?? '';
          final lastname = data['lastname']?.toString().trim() ?? '';
          final fullName = [firstname, lastname]
              .where((value) => value.isNotEmpty)
              .join(' ');
          final identity = fullName.isNotEmpty
              ? fullName
              : (email.isNotEmpty ? email : 'Compte Heliantha');

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsivePagePadding(
                bottom: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountHeader(
                      email: email,
                      identity: identity,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Espace client',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _AccountActions(
                      onOrders: () => context.push('/orders'),
                      onAddresses: () => context.push('/addresses'),
                      onPrivacy: () => context.push('/privacy'),
                      onLogout: () async {
                        await ref
                            .read(fcmServiceProvider)
                            .unregisterCurrentDevice();
                        await ref.read(authRepositoryProvider).logout();
                        ref.invalidate(currentUserProvider);
                        if (context.mounted) {
                          AppFeedback.info(context, 'À bientôt');
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    const _ContactSection(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.email,
    required this.identity,
  });

  final String email;
  final String identity;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      backgroundColor: AppColors.navy,
      borderColor: AppColors.navy,
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HelianthaLogo(size: 58, padding: 5, showShadow: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (email.isNotEmpty && email != identity) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFC9D7E2),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({
    required this.onOrders,
    required this.onAddresses,
    required this.onPrivacy,
    required this.onLogout,
  });

  final VoidCallback onOrders;
  final VoidCallback onAddresses;
  final VoidCallback onPrivacy;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSurface(
          padding: EdgeInsets.zero,
          radius: AppRadii.lg,
          shadow: true,
          child: AppActionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Mes commandes',
            subtitle: 'Suivi, montants et statuts',
            onTap: onOrders,
          ),
        ),
        const SizedBox(height: 10),
        AppSurface(
          padding: EdgeInsets.zero,
          radius: AppRadii.lg,
          shadow: true,
          child: AppActionTile(
            icon: Icons.location_on_outlined,
            title: 'Mes adresses',
            subtitle: 'Livraison et facturation',
            onTap: onAddresses,
          ),
        ),
        const SizedBox(height: 10),
        AppSurface(
          padding: EdgeInsets.zero,
          radius: AppRadii.lg,
          shadow: true,
          child: AppActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            subtitle: 'Protection des données et vie privée',
            onTap: onPrivacy,
          ),
        ),
        const SizedBox(height: 10),
        AppSurface(
          padding: EdgeInsets.zero,
          radius: AppRadii.lg,
          child: AppActionTile(
            icon: Icons.logout_rounded,
            title: 'Déconnexion',
            subtitle: 'Quitter ce compte sur l’appareil',
            danger: true,
            onTap: onLogout,
          ),
        ),
      ],
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 96,
          child: Column(
            children: [
              const HelianthaLogo(size: 92, padding: 6, showShadow: true),
              const SizedBox(height: 16),
              AppStatusPanel(
                icon: Icons.person_outline_rounded,
                title: 'Bienvenue chez Heliantha',
                message:
                    'Connectez-vous ou créez votre compte pour retrouver vos commandes.',
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          context.push(loginLocationFor('/account')),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Se connecter'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/register?redirect=${Uri.encodeComponent('/account')}',
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Créer un compte'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Vous pouvez aussi parcourir les produits et commander sans compte.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _ContactSection(),
              const _LegalSection(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection();

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Notre équipe vous répond rapidement.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        _ContactTile(
          icon: Icons.phone_rounded,
          title: 'Appeler',
          value: AppConfig.supportPhoneDisplay,
          subtitle: 'Numéro direct',
          color: AppColors.danger,
          onTap: () => _open(context, _phone),
        ),
        const SizedBox(height: 10),
        _ContactTile(
          icon: Icons.chat_bubble_rounded,
          title: 'WhatsApp',
          value: AppConfig.supportWhatsAppDisplay,
          subtitle: 'Message rapide',
          color: AppColors.leaf,
          onTap: () => _open(context, _whatsapp),
        ),
        const SizedBox(height: 18),
        Text(
          'Email',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        _ContactTile(
          icon: Icons.mail_rounded,
          title: 'E-mail',
          value: AppConfig.supportEmail,
          subtitle: 'Réponse par mail',
          color: AppColors.blue,
          onTap: () => _open(context, _email),
        ),
        const SizedBox(height: 18),
        Text(
          'Localisation',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        _ContactTile(
          icon: Icons.location_on_rounded,
          title: 'Nous trouver',
          value: 'Ouvrir dans Google Maps',
          subtitle: 'Itinéraire vers Heliantha',
          color: AppColors.sun,
          onTap: () => _open(context, _location),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = color == AppColors.sun ? AppColors.navy : color;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadii.lg,
      onTap: onTap,
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            color: iconColor,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          'Informations légales',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        AppSurface(
          padding: EdgeInsets.zero,
          radius: AppRadii.lg,
          child: AppActionTile(
            icon: Icons.policy_outlined,
            title: 'Politique de confidentialité',
            subtitle: 'Protection des données et vie privée',
            onTap: () => context.push('/privacy'),
          ),
        ),
      ],
    );
  }
}
