import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/brand_widgets.dart';
import '../../data/assistant_api_service.dart';

/// Modèle de données pour les devis calculés par AssistantDevisManager
class ChatDevisData {
  const ChatDevisData({
    required this.reference,
    required this.totalTtc,
    this.powerKwc,
    this.panelCount,
    this.inverter,
    this.pdfUrl,
    this.raw = const {},
  });

  final String reference;
  final double totalTtc;
  final double? powerKwc;
  final int? panelCount;
  final String? inverter;
  final String? pdfUrl;
  final Map<String, dynamic> raw;

  static final regex = RegExp(
    r'<<<DEVIS_DATA:\s*(\{.*?\})\s*>>>',
    dotAll: true,
  );

  static ({String cleanedText, ChatDevisData? devisData}) extract(
    String rawText,
  ) {
    ChatDevisData? devis;
    final match = regex.firstMatch(rawText);
    if (match != null) {
      final jsonStr = match.group(1);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr.trim());
          if (decoded is Map<String, dynamic>) {
            devis = ChatDevisData.fromJson(decoded);
          }
        } catch (e) {
          debugPrint('Erreur lors du parsing du devis IA : $e');
        }
      }
    }

    String cleaned = rawText.replaceAll(regex, '').trim();
    if (cleaned.isEmpty && devis != null) {
      cleaned = 'Voici les détails chiffrés de votre devis officiel :';
    }

    return (cleanedText: cleaned, devisData: devis);
  }

  factory ChatDevisData.fromJson(Map<String, dynamic> json) {
    final ref = (json['ref'] ??
            json['reference'] ??
            json['quote_number'] ??
            json['quote_ref'] ??
            json['id'] ??
            'H-2026-OFFICIEL')
        .toString();

    final rawTotal = json['total_ttc'] ??
        json['totalTtc'] ??
        json['total'] ??
        json['price'] ??
        json['montant_ttc'] ??
        0;
    final totalTtc = _toDouble(rawTotal);

    final rawKwc = json['kwc'] ??
        json['power_kwc'] ??
        json['powerKwc'] ??
        json['puissance'] ??
        json['power'];
    final powerKwc = rawKwc != null ? _toDouble(rawKwc) : null;

    final rawPanels = json['panels'] ??
        json['panel_count'] ??
        json['panels_count'] ??
        json['nb_panneaux'] ??
        json['modules'];
    final panelCount = rawPanels != null ? _toInt(rawPanels) : null;

    final inverter = (json['inverter'] ??
            json['onduleur'] ??
            json['variateur'] ??
            json['equipment'] ??
            json['equipement'])
        ?.toString();

    final rawPdf = (json['pdf_url'] ??
            json['pdfUrl'] ??
            json['download_url'] ??
            json['downloadUrl'] ??
            json['pdf'] ??
            json['url'])
        ?.toString();

    final pdf = AppConfig.resolvePdfUrl(
      rawPdf != null && rawPdf.trim().isNotEmpty
          ? rawPdf
          : '/api/devis/pdf/${Uri.encodeComponent(ref)}',
    );

    return ChatDevisData(
      reference: ref,
      totalTtc: totalTtc,
      powerKwc: powerKwc,
      panelCount: panelCount,
      inverter: inverter,
      pdfUrl: pdf,
      raw: json,
    );
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned =
          val.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static int? _toInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(cleaned);
    }
    return null;
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    String? displayedText,
    this.isThinking = false,
    this.thinkingStep = '',
  }) : displayedText = displayedText ?? text;

  final String role; // 'user' ou 'assistant'
  String text;
  final DateTime timestamp;
  String displayedText;
  bool isThinking;
  bool isStreaming = false;
  String thinkingStep;
  ChatDevisData? devisData;

  bool get isUser => role == 'user';
}

class _ChatSuggestion {
  const _ChatSuggestion({
    required this.label,
    required this.query,
  });

  final String label;
  final String query;
}

/// Feuille modale de discussion style Apple Intelligence / iOS Frosted Glass
/// Conseiller commercial et technique réactif, chaleureux et professionnel
class AiChatBottomSheet extends ConsumerStatefulWidget {
  const AiChatBottomSheet({
    super.key,
    this.contextPrompt,
    this.initialQuestion,
  });

  final String? contextPrompt;
  final String? initialQuestion;

  static Future<void> show(
    BuildContext context, {
    String? contextPrompt,
    String? initialQuestion,
  }) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final chat = AiChatBottomSheet(
      contextPrompt: contextPrompt,
      initialQuestion: initialQuestion,
    );

    if (isDesktop) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer le conseiller solaire IA',
        barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.18),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final mediaQuery = MediaQuery.of(dialogContext);
          final availableHeight =
              mediaQuery.size.height - mediaQuery.viewInsets.bottom;
          final panelHeight = math.min(620.0, availableHeight * 0.75);

          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 24,
                bottom: 24 + mediaQuery.viewInsets.bottom,
              ),
              child: SizedBox(
                width: 420,
                height: panelHeight,
                child: Material(
                  type: MaterialType.transparency,
                  child: chat,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.45),
      builder: (sheetContext) => chat,
    );
  }

  @override
  ConsumerState<AiChatBottomSheet> createState() => _AiChatBottomSheetState();
}

class _AiChatBottomSheetState extends ConsumerState<AiChatBottomSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  Timer? _thinkingTimer;
  Timer? _streamingTimer;

  static const _defaultSuggestions = [
    _ChatSuggestion(
      label: '💧 Pompage solaire',
      query:
          'Je souhaite des conseils sur le pompage solaire pour mon forage ou mon bassin.',
    ),
    _ChatSuggestion(
      label: '☀️ Réduire ma facture',
      query:
          'Comment fonctionne l\'autoconsommation photovoltaïque pour réduire ma facture d\'électricité ?',
    ),
    _ChatSuggestion(
      label: '🔋 Solaire avec batteries',
      query:
          'Pouvez-vous m\'expliquer l\'installation solaire hybride avec stockage batteries ?',
    ),
    _ChatSuggestion(
      label: '🏠 Site sans réseau',
      query:
          'Quelles solutions proposez-vous pour un site isolé sans réseau électrique (Off-Grid) ?',
    ),
    _ChatSuggestion(
      label: '♨️ Chauffage solaire',
      query:
          'Comment fonctionne un chauffe-eau solaire thermique pour l\'eau chaude ?',
    ),
    _ChatSuggestion(
      label: '🚗 Recharge électrique',
      query:
          'Proposez-vous des bornes de recharge pour véhicules électriques ?',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Message d'accueil pro, chaleureux et concis
    const welcome = 'Bonjour ! Je suis votre conseiller solaire HeliAntha.\n\n'
        'Je suis à votre disposition pour vous orienter sur nos solutions : '
        'pompage solaire, réduction de facture, batteries, site isolé, chauffe-eau ou borne de recharge.\n\n'
        'Comment puis-je vous accompagner aujourd\'hui ?';

    _messages.add(
      _ChatMessage(
        role: 'assistant',
        text: welcome,
        displayedText: welcome,
        timestamp: DateTime.now(),
      ),
    );

    // Si une question initiale a été passée
    if (widget.initialQuestion != null &&
        widget.initialQuestion!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitUserMessage(widget.initialQuestion!.trim());
      });
    }
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _streamingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if ((_scrollController.offset - target).abs() < 4) return;

      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  /// Génère une liste d'étapes de réflexion adaptées au sujet (chaleureux et rassurant)
  List<String> _resolveThinkingSteps(String query) {
    final lower = '$query ${widget.contextPrompt ?? ''}'.toLowerCase();

    if (lower.contains('pomp') ||
        lower.contains('forage') ||
        lower.contains('débit') ||
        lower.contains('hmt') ||
        lower.contains('cv') ||
        lower.contains('eau')) {
      return [
        'Analyse de vos paramètres de pompage...',
        'Calcul du débit et du gisement solaire...',
        'Sélection des équipements solaires adaptés...',
        'Réflexion... presque prêt !',
        'Récapitulatif de votre solution...',
      ];
    } else if (lower.contains('batteri') ||
        lower.contains('lithium') ||
        lower.contains('stock') ||
        lower.contains('hybride') ||
        lower.contains('autonomi')) {
      return [
        'Étude de votre autonomie électrique...',
        'Dimensionnement du stockage batteries...',
        'Optimisation de la solution hybride...',
        'Réflexion... presque prêt !',
        'Récapitulatif de votre installation...',
      ];
    } else if (lower.contains('factur') ||
        lower.contains('onee') ||
        lower.contains('rentab') ||
        lower.contains('économi') ||
        lower.contains('consommation') ||
        lower.contains('prix') ||
        lower.contains('devis') ||
        lower.contains('tarif')) {
      return [
        'Analyse de votre consommation électrique...',
        'Calcul de vos économies solaires...',
        'Dimensionnement optimal des modules...',
        'Réflexion... presque prêt !',
        'Récapitulatif et devis adapté...',
      ];
    }

    return [
      'Analyse de votre demande...',
      'Recherche de la solution HeliAntha...',
      'Réflexion... presque prêt !',
      'Récapitulatif de vos conseils personnalisés...',
    ];
  }

  Future<void> _submitUserMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();
    HapticFeedback.lightImpact();

    final steps = _resolveThinkingSteps(query);

    // 1. Ajout immédiat de la bulle utilisateur
    final userMessage = _ChatMessage(
      role: 'user',
      text: query,
      timestamp: DateTime.now(),
    );

    // 2. Ajout IMMÉDIAT de la réponse de l'IA avec état de réflexion actif
    final assistantMessage = _ChatMessage(
      role: 'assistant',
      text: '',
      displayedText: '',
      timestamp: DateTime.now(),
      isThinking: true,
      thinkingStep: steps.first,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    // 3. Animation douce et stable des étapes
    int currentStepIndex = 0;

    _thinkingTimer?.cancel();
    _thinkingTimer =
        Timer.periodic(const Duration(milliseconds: 1700), (timer) {
      if (!mounted || !assistantMessage.isThinking) {
        timer.cancel();
        return;
      }
      currentStepIndex++;
      if (currentStepIndex < steps.length) {
        setState(() {
          assistantMessage.thinkingStep = steps[currentStepIndex];
        });
      } else {
        timer.cancel();
      }
      // Hauteur fixe et stable : l'écran reste parfaitement immobile
    });

    // 4. Construction de l'historique de discussion
    final history = _messages
        .where((m) => m != assistantMessage) // exclure le placeholder
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();

    try {
      final apiService = ref.read(assistantApiServiceProvider);
      final rawReply = await apiService.sendMessage(
        history: history,
        contextPrompt: widget.contextPrompt,
      );

      _thinkingTimer?.cancel();

      if (mounted) {
        // Extraction et nettoyage des métadonnées devis
        final parsed = ChatDevisData.extract(rawReply);
        final cleanText = parsed.cleanedText;

        setState(() {
          assistantMessage.isThinking = false;
          assistantMessage.thinkingStep = '';
          assistantMessage.text = cleanText;
          assistantMessage.devisData = parsed.devisData;
        });
        _streamResponse(assistantMessage, cleanText);
      }
    } catch (_) {
      _thinkingTimer?.cancel();
      if (mounted) {
        setState(() {
          assistantMessage.isThinking = false;
          assistantMessage.thinkingStep = '';
          assistantMessage.text =
              'Désolé, une difficulté réseau est survenue. Veuillez vérifier votre connexion ou réessayer.';
          assistantMessage.displayedText = assistantMessage.text;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Animation de frappe fluide (Typewriter) pour un affichage dynamique et apaisé
  void _streamResponse(_ChatMessage message, String fullText) {
    _streamingTimer?.cancel();
    int charIndex = 0;
    int tickCount = 0;
    final total = fullText.length;
    final step = total == 0 ? 1 : (total / 60).clamp(2, 3).round();

    setState(() {
      message.isStreaming = true;
    });

    _streamingTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final shouldFollow = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent -
                  _scrollController.offset <
              48;
      tickCount++;
      charIndex = (charIndex + step).clamp(0, total);
      setState(() {
        message.displayedText = fullText.substring(0, charIndex);
        if (charIndex >= total) {
          message.displayedText = fullText;
          message.isStreaming = false;
          _isLoading = false;
          timer.cancel();
        }
      });
      if (shouldFollow && tickCount % 4 == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 768;
    final bottomInset = isDesktop ? 0.0 : mediaQuery.viewInsets.bottom;
    final totalHeight = isDesktop
        ? math.min(620.0, mediaQuery.size.height * 0.75)
        : mediaQuery.size.height * 0.82;
    final borderRadius = isDesktop
        ? BorderRadius.circular(20)
        : const BorderRadius.vertical(top: Radius.circular(32));

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: isDesktop ? null : totalHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDesktop ? 0.88 : 0.94),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                  blurRadius: 32,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. En-tête iOS épuré
                _buildHeader(context),

                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                // 2. Suggestions rapides horizontales (Chips)
                _buildQuickSuggestions(),

                // 3. Zone de conversation défilante
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _ChatMessageTile(
                        message: msg,
                      );
                    },
                  ),
                ),

                // 4. Barre de saisie dockée
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Pill handle iOS
        Container(
          width: 38,
          height: 4.5,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            children: [
              // Logo officiel Heliantha dans l'en-tête de l'assistant
              const HelianthaLogo(
                size: 38,
                padding: 3,
                showShadow: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conseiller Solaire IA',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'En ligne • Analyse instantanée',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bouton fermer discret
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSuggestions() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _defaultSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _defaultSuggestions[index];
          return ActionChip(
            label: Text(
              item.label,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            pressElevation: 1,
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            onPressed: () => _submitUserMessage(item.query),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: _submitUserMessage,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Posez votre question technique ou tarifaire...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Bouton rond iOS d'envoi Bleu Nuit avec Soleil orbital qui tourne
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return _AiChatSendButton(
                  isLoading: _isLoading,
                  hasText: hasText,
                  onPressed: () => _submitUserMessage(_textController.text),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.message,
  });

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SelectableText(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Bulle IA HeliAntha avec streaming & carte de devis
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar officiel HeliAntha (logo de marque)
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: HelianthaLogo(
              size: 30,
              padding: 2,
              showShadow: false,
            ),
          ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Indicateur rassurant pendant la réflexion (disparaît dès l'affichage de la réponse)
                  if (message.isThinking)
                    _ThinkingIndicator(step: message.thinkingStep),

                  // 2. Texte de réponse de l'IA (avec curseur animé pendant le streaming)
                  if (message.displayedText.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: SelectableText(
                            message.displayedText,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              height: 1.42,
                            ),
                          ),
                        ),
                        if (message.isStreaming) const _BlinkingCursor(),
                      ],
                    ),

                  // 3. Carte de Devis interactif officiel (si présent et après la frappe du texte)
                  if (message.devisData != null && !message.isStreaming) ...[
                    const SizedBox(height: 14),
                    _ChatMessageQuoteCard(
                      devis: message.devisData!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur de réflexion élégant, moderne et rassurant avec le mini-soleil orbital HeliAntha
class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({this.step = ''});

  final String step;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.38),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniOrbitalSun(controller: _anim),
          const SizedBox(width: 10),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                widget.step.isNotEmpty
                    ? widget.step
                    : 'HeliAntha prépare votre réponse...',
                key: ValueKey(widget.step),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-soleil orbital HeliAntha avec rayons en rotation et satellite d'énergie en orbite
class _MiniOrbitalSun extends StatelessWidget {
  const _MiniOrbitalSun({
    super.key,
    required this.controller,
    this.size = 26,
  });

  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return CustomPaint(
          size: Size(size, size),
          painter: _MiniSunPainter(
            spin: t,
            pulse: (math.sin(t * 2 * math.pi) + 1) / 2,
          ),
        );
      },
    );
  }
}

class _MiniSunPainter extends CustomPainter {
  const _MiniSunPainter({required this.spin, required this.pulse});

  final double spin;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final coreRadius = radius * (0.34 + 0.04 * pulse);

    // 1. Halo doux doré
    canvas.drawCircle(
      center,
      radius * (0.75 + 0.08 * pulse),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDE68A).withValues(alpha: 0.55),
            const Color(0xFFFDE68A).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 2. Orbite pointillée bleue cyan
    final orbitRadius = radius * 0.88;
    final orbitPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const dashCount = 20;
    for (var i = 0; i < dashCount; i += 2) {
      final a0 = (i / dashCount) * 2 * math.pi;
      final a1 = ((i + 1) / dashCount) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: orbitRadius),
        a0,
        a1 - a0,
        false,
        orbitPaint,
      );
    }

    // 3. Rayons solaires dorés en rotation douce
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * 2 * math.pi);
    const rayCount = 8;
    for (var i = 0; i < rayCount; i++) {
      final isLong = i.isEven;
      final inner = coreRadius + 1.2;
      final outer = coreRadius + (isLong ? 3.4 : 2.4);
      final rayPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isLong ? 1.8 : 1.3
        ..color = (isLong ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24))
            .withValues(alpha: isLong ? 0.95 : 0.80);
      final angle = (i / rayCount) * 2 * math.pi;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(dir * inner, dir * outer, rayPaint);
    }
    canvas.restore();

    // 4. Cœur du soleil dégradé chaud
    final coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFFFFF7CC), Color(0xFFFCD34D), Color(0xFFF59E0B)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(coreRect),
    );

    // 5. Petit satellite d'énergie en orbite dynamique
    final satAngle = -spin * 2 * math.pi * 2 - math.pi / 2;
    final satPos = center +
        Offset(math.cos(satAngle), math.sin(satAngle)) * orbitRadius;
    canvas.drawCircle(
      satPos,
      3.2,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(
      satPos,
      2.0,
      Paint()..color = const Color(0xFF0EA5E9),
    );
    canvas.drawCircle(
      satPos,
      0.9,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MiniSunPainter oldDelegate) =>
      oldDelegate.spin != spin || oldDelegate.pulse != pulse;
}

/// Bouton rond d'envoi HeliAntha arborant le Soleil orbital qui tourne pendant la réflexion et l'envoi
class _AiChatSendButton extends StatefulWidget {
  const _AiChatSendButton({
    required this.isLoading,
    required this.hasText,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasText;
  final VoidCallback? onPressed;

  @override
  State<_AiChatSendButton> createState() => _AiChatSendButtonState();
}

class _AiChatSendButtonState extends State<_AiChatSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isLoading) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AiChatSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        if (!_spinController.isAnimating) {
          _spinController.repeat();
        }
      } else {
        _spinController.stop();
        _spinController.reset();
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = !widget.isLoading && widget.onPressed != null;

    return Semantics(
      button: true,
      label: widget.isLoading
          ? 'Envoi et analyse en cours...'
          : 'Envoyer le message',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? widget.onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isLoading
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.75)
                    : widget.hasText
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.20),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isLoading
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                      : const Color(0xFF0F172A).withValues(alpha: 0.22),
                  blurRadius: widget.isLoading ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: widget.isLoading
                    ? _MiniOrbitalSun(
                        key: const ValueKey('spinning_sun_send'),
                        controller: _spinController,
                        size: 26,
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        key: const ValueKey('send_arrow'),
                        color: widget.hasText
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFFDE68A).withValues(alpha: 0.85),
                        size: 22,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur de frappe : mini-soleil HeliAntha qui tourne pendant l'écriture
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 1),
      child: _MiniOrbitalSun(controller: _controller, size: 18),
    );
  }
}

/// Carte interactive de résultat de devis officiel intégrée dans le chat
class _ChatMessageQuoteCard extends StatefulWidget {
  const _ChatMessageQuoteCard({required this.devis});

  final ChatDevisData devis;

  @override
  State<_ChatMessageQuoteCard> createState() => _ChatMessageQuoteCardState();
}

class _ChatMessageQuoteCardState extends State<_ChatMessageQuoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatPrice(double amount) {
    if (amount <= 0) return '0';
    final rounded = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < rounded.length; i++) {
      if (i > 0 && (rounded.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(rounded[i]);
    }
    return buffer.toString();
  }

  Future<void> _handleDownload(BuildContext context) async {
    final pdfUrl = widget.devis.pdfUrl;
    final targetUrl = AppConfig.resolvePdfUrl(
      pdfUrl != null && pdfUrl.isNotEmpty
          ? pdfUrl
          : '/api/devis/pdf/${Uri.encodeComponent(widget.devis.reference)}',
    );

    if (targetUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL du devis PDF non disponible.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(targetUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le lien du PDF.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'ouverture du devis PDF.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devis = widget.devis;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. En-tête : Badge vert discret & Référence
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFA7F3D0),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '✓ Devis officiel calculé',
                          style: TextStyle(
                            color: Color(0xFF047857),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      devis.reference,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. Prix : Grand montant Bleu Nuit + DH TTC en ambre
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatPrice(devis.totalTtc),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'DH TTC',
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Estimation certifiée HeliAntha Solaire Maroc',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              // 3. Métriques techniques (Puissance, Panneaux, Équipement)
              if (devis.powerKwc != null || devis.panelCount != null)
                Row(
                  children: [
                    if (devis.powerKwc != null)
                      Expanded(
                        child: _MetricChip(
                          icon: Icons.solar_power_rounded,
                          label: 'Puissance',
                          value:
                              '${devis.powerKwc!.toStringAsFixed(devis.powerKwc! % 1 == 0 ? 0 : 2)} kWc',
                        ),
                      ),
                    if (devis.powerKwc != null && devis.panelCount != null)
                      const SizedBox(width: 8),
                    if (devis.panelCount != null)
                      Expanded(
                        child: _MetricChip(
                          icon: Icons.grid_view_rounded,
                          label: 'Panneaux',
                          value: '${devis.panelCount} modules',
                        ),
                      ),
                  ],
                ),

              if (devis.inverter != null &&
                  devis.inverter!.trim().isNotEmpty) ...[
                if (devis.powerKwc != null || devis.panelCount != null)
                  const SizedBox(height: 8),
                _MetricChip(
                  icon: Icons.memory_rounded,
                  label: 'Équipement',
                  value: devis.inverter!.trim(),
                ),
              ],

              const SizedBox(height: 14),

              // 4. Bouton d'action principal : Télécharger mon Devis PDF
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleDownload(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFFF59E0B),
                          size: 19,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Télécharger mon Devis PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.open_in_new_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                      ],
                    ),
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: const Color(0xFFD97706)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
