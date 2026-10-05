import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static final Uri _emailUri = AppConfig.supportEmailUri;

  static Future<void> _launchEmail(BuildContext context) async {
    final opened =
        await launchUrl(_emailUri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppFeedback.info(
        context,
        'Impossible d’ouvrir votre messagerie automatiquement. Vous pouvez nous écrire à ${AppConfig.supportEmail}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(
        subtitle: 'Politique de confidentialité',
        showBack: true,
        backFallbackLocation: '/',
        showCart: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsivePagePadding(
              maxWidth: 820,
              top: 20,
              bottom: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(onContact: () => _launchEmail(context)),
                  const SizedBox(height: 16),

                  // 1. Responsable du traitement
                  _SectionCard(
                    number: '01',
                    icon: Icons.business_rounded,
                    title: 'Responsable du traitement',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Les données sont traitées par :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Heliantha',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'N436 Route de Kenitra, Saïd Hajji, Salé 11000, Maroc',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.ink,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              _EmailButton(
                                email: AppConfig.supportEmail,
                                onTap: () => _launchEmail(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Données personnelles collectées
                  _SectionCard(
                    number: '02',
                    icon: Icons.fact_check_rounded,
                    title: 'Données personnelles collectées',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selon les fonctionnalités utilisées, Heliantha peut collecter notamment :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _BulletItem(text: 'nom et prénom ;'),
                        const _BulletItem(text: 'adresse email ;'),
                        const _BulletItem(text: 'numéro de téléphone ;'),
                        const _BulletItem(
                            text: 'informations du compte client ;'),
                        const _BulletItem(
                            text: 'adresses de livraison et de facturation ;'),
                        const _BulletItem(
                            text:
                                'informations relatives aux commandes et à leur historique ;'),
                        const _BulletItem(text: 'produits favoris ;'),
                        const _BulletItem(
                            text:
                                'informations nécessaires au suivi des commandes ;'),
                        const _BulletItem(
                            text:
                                'identifiants techniques nécessaires à l’envoi de notifications.'),
                        const SizedBox(height: 12),
                        const _HighlightBox(
                          icon: Icons.security_rounded,
                          color: AppColors.leaf,
                          backgroundColor: AppColors.softLeaf,
                          title: 'Sécurité bancaire',
                          text:
                              'Heliantha ne stocke pas les coordonnées bancaires des utilisateurs dans l’application mobile.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Utilisation des données
                  _SectionCard(
                    number: '03',
                    icon: Icons.tune_rounded,
                    title: 'Utilisation des données',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Les données collectées sont utilisées notamment pour :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _BulletItem(
                            text: 'créer et gérer le compte client ;'),
                        const _BulletItem(
                            text: 'traiter et suivre les commandes ;'),
                        const _BulletItem(
                            text:
                                'organiser la livraison ou le retrait des produits ;'),
                        const _BulletItem(text: 'gérer les favoris ;'),
                        const _BulletItem(
                            text: 'fournir le service après-vente ;'),
                        const _BulletItem(
                            text:
                                'informer le client de l’évolution de ses commandes ;'),
                        const _BulletItem(
                            text:
                                'envoyer des notifications utiles relatives au compte, aux commandes ou aux produits ;'),
                        const _BulletItem(
                            text:
                                'assurer la sécurité et le bon fonctionnement des services ;'),
                        const _BulletItem(
                            text:
                                'répondre aux demandes adressées au service client.'),
                        const SizedBox(height: 12),
                        Text(
                          'Les données ne sont pas utilisées à des fins étrangères aux services proposés par Heliantha sans information ou consentement approprié de l’utilisateur.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Notifications
                  _SectionCard(
                    number: '04',
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'L’application HELIANTHA peut envoyer des notifications concernant notamment :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _BulletItem(
                            text: 'la confirmation d’une commande ;'),
                        const _BulletItem(
                            text:
                                'la préparation ou l’évolution d’une commande ;'),
                        const _BulletItem(
                            text: 'les informations relatives au paiement ;'),
                        const _BulletItem(
                            text: 'le retour en stock de certains produits ;'),
                        const _BulletItem(
                            text:
                                'd’autres informations directement liées aux services Heliantha.'),
                        const SizedBox(height: 12),
                        const _HighlightBox(
                          icon: Icons.cloud_done_rounded,
                          color: AppColors.blue,
                          backgroundColor: AppColors.softBlue,
                          title: 'Google Firebase',
                          text:
                              'Pour permettre l’envoi de notifications sur Android, l’application utilise Firebase Cloud Messaging, un service fourni par Google.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Partage des données
                  _SectionCard(
                    number: '05',
                    icon: Icons.hub_rounded,
                    title: 'Partage des données',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Les données peuvent être traitées par les services techniques nécessaires au fonctionnement de l’application, notamment :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _BulletItem(
                            text: 'l’infrastructure e-commerce PrestaShop ;'),
                        const _BulletItem(
                            text:
                                'les infrastructures d’hébergement utilisées par Heliantha ;'),
                        const _BulletItem(
                            text:
                                'Google Firebase pour les notifications mobiles ;'),
                        const _BulletItem(
                            text:
                                'les prestataires nécessaires à la livraison des commandes lorsque cela est requis.'),
                        const SizedBox(height: 12),
                        const _HighlightBox(
                          icon: Icons.verified_user_rounded,
                          color: AppColors.leaf,
                          backgroundColor: AppColors.softLeaf,
                          title: 'Engagement de confidentialité',
                          text:
                              'Heliantha ne vend pas les données personnelles de ses utilisateurs.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. Sécurité
                  _SectionCard(
                    number: '06',
                    icon: Icons.lock_outline_rounded,
                    title: 'Sécurité',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heliantha met en œuvre des mesures techniques et organisationnelles destinées à protéger les informations personnelles contre l’accès non autorisé, la perte, la modification ou la divulgation.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _HighlightBox(
                          icon: Icons.https_rounded,
                          color: AppColors.navy,
                          backgroundColor: AppColors.surfaceMuted,
                          title: 'Chiffrement HTTPS',
                          text:
                              'Les communications avec les services en ligne Heliantha sont protégées notamment au moyen du protocole HTTPS.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7. Conservation des données
                  _SectionCard(
                    number: '07',
                    icon: Icons.timer_outlined,
                    title: 'Conservation des données',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Les données sont conservées pendant la durée nécessaire à la gestion du compte, des commandes, du service client et au respect des obligations légales et comptables applicables.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Certaines informations liées aux commandes peuvent être conservées plus longtemps lorsque la réglementation l’impose.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 8. Droits des utilisateurs
                  _SectionCard(
                    number: '08',
                    icon: Icons.gavel_rounded,
                    title: 'Droits des utilisateurs',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.softSun,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.premiumLine),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.balance_rounded,
                                color: AppColors.navy,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Loi marocaine n° 09-08',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Conformément à la loi marocaine n° 09-08 relative à la protection des personnes physiques à l’égard du traitement des données à caractère personnel, les utilisateurs disposent notamment de droits d’accès, de rectification et d’opposition concernant leurs données personnelles, dans les conditions prévues par la réglementation applicable.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.ink,
                                            height: 1.45,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Pour exercer ces droits :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _EmailButton(
                          email: AppConfig.supportEmail,
                          onTap: () => _launchEmail(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 9. Suppression du compte et des données
                  _SectionCard(
                    number: '09',
                    icon: Icons.delete_sweep_rounded,
                    title: 'Suppression du compte et des données',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Un utilisateur peut demander la suppression de son compte HELIANTHA et des données personnelles qui lui sont associées en adressant une demande à :',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        _EmailButton(
                          email: AppConfig.supportEmail,
                          onTap: () => _launchEmail(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Certaines informations peuvent toutefois être conservées lorsqu’elles sont nécessaires au respect d’une obligation légale, comptable ou à la résolution d’un litige.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 10. Services tiers
                  _SectionCard(
                    number: '10',
                    icon: Icons.extension_rounded,
                    title: 'Services tiers',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Certains services techniques peuvent traiter des informations nécessaires au fonctionnement de l’application, notamment Google Firebase pour les notifications.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ces prestataires disposent de leurs propres politiques et mesures de protection des données.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 11. Modifications
                  _SectionCard(
                    number: '11',
                    icon: Icons.history_rounded,
                    title: 'Modifications',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heliantha peut modifier la présente politique afin de tenir compte de l’évolution de ses services, de l’application ou de la réglementation applicable.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.ink,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'La date de dernière mise à jour est indiquée en haut de cette page.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 12. Contact
                  _SectionCard(
                    number: '12',
                    icon: Icons.contact_support_rounded,
                    title: 'Contact',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Heliantha',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'N436 Route de Kenitra, Saïd Hajji, Salé 11000, Maroc',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.ink,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              _EmailButton(
                                email: AppConfig.supportEmail,
                                onTap: () => _launchEmail(context),
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
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.onContact});

  final VoidCallback onContact;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const HelianthaLogo(size: 54, padding: 4, showShadow: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sun.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: AppColors.sun.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'DOCUMENT OFFICIEL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.sun,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Politique de confidentialité',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: Color(0xFFC9D7E2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Dernière mise à jour : septembre 2026',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFC9D7E2),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Heliantha accorde une grande importance à la protection des données personnelles de ses clients et utilisateurs. La présente politique explique quelles informations peuvent être collectées lors de l’utilisation du site et de l’application mobile HELIANTHA, ainsi que la manière dont elles sont utilisées et protégées.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFEDF3F8),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.child,
  });

  final String number;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadii.lg,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: icon,
                color: AppColors.blue,
                backgroundColor: AppColors.softBlue,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECTION $number',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.leaf,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightBox extends StatelessWidget {
  const _HighlightBox({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color == AppColors.navy ? AppColors.ink : color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                        height: 1.4,
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

class _EmailButton extends StatelessWidget {
  const _EmailButton({
    required this.email,
    required this.onTap,
  });

  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.softBlue,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.email_outlined, size: 16, color: AppColors.blue),
            const SizedBox(width: 8),
            Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.blue,
                  ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded,
                size: 14, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}
