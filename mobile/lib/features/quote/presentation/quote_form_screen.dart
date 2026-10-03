import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../assistant/presentation/widgets/ai_floating_orb.dart';
import '../data/quote_repository.dart';
import '../providers/quote_provider.dart';

class QuoteFormScreen extends ConsumerStatefulWidget {
  const QuoteFormScreen({
    super.key,
    required this.projectType,
  });

  final String projectType;

  @override
  ConsumerState<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends ConsumerState<QuoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flowController = TextEditingController();
  final _hmtController = TextEditingController();
  final _consumptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();

  int _currentStep = 0;
  bool? _pumpExisting;
  bool _submitting = false;
  bool _downloadingPdf = false;
  double? _existingPumpCv;
  String _meterType = 'numerique';
  String _phase = 'monophase';
  QuoteCalculationResult? _result;

  static const _pumpPowerOptions = <double>[
    2,
    3,
    5.5,
    7.5,
    10,
    15,
    20,
    30,
    40,
    50,
  ];

  _QuoteProjectKind get _kind {
    final value = Uri.decodeComponent(widget.projectType).trim().toLowerCase();
    switch (value) {
      case 'pompage':
      case 'pumping':
        return _QuoteProjectKind.pumping;
      case 'hybride':
      case 'hybrid':
        return _QuoteProjectKind.hybrid;
      case 'autoconsommation':
      case 'photovoltaic':
      case 'pv':
      default:
        return _QuoteProjectKind.photovoltaic;
    }
  }

  _QuoteFormSpec get _spec => _QuoteFormSpec.fromKind(_kind);

  int get _totalSteps {
    switch (_kind) {
      case _QuoteProjectKind.pumping:
      case _QuoteProjectKind.photovoltaic:
        return 3;
      case _QuoteProjectKind.hybrid:
        return 2;
    }
  }

  bool get _isLastStep => _currentStep == _totalSteps - 1;

  bool get _isCurrentStepComplete {
    switch (_kind) {
      case _QuoteProjectKind.pumping:
        if (_currentStep == 0) {
          return _pumpExisting != null;
        }
        if (_currentStep == 1) {
          if (_pumpExisting == true) {
            return _existingPumpCv != null;
          }
          return _isPositive(_flowController.text) &&
              _isPositive(_hmtController.text);
        }
        return _isContactComplete;
      case _QuoteProjectKind.photovoltaic:
        if (_currentStep == 0) {
          return _meterType.isNotEmpty && _phase.isNotEmpty;
        }
        if (_currentStep == 1) {
          return _isEnergyComplete;
        }
        return _isContactComplete;
      case _QuoteProjectKind.hybrid:
        if (_currentStep == 0) {
          return _isEnergyComplete;
        }
        return _isContactComplete;
    }
  }

  bool get _isEnergyComplete {
    return _isPositive(_consumptionController.text);
  }

  bool get _isContactComplete {
    final name = _nameController.text.trim();
    final phone = _compactPhone(_phoneController.text);
    final city = _cityController.text.trim();
    return name.length >= 2 &&
        RegExp(r'^0[567]\d{8}$').hasMatch(phone) &&
        city.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _flowController,
      _hmtController,
      _consumptionController,
      _nameController,
      _phoneController,
      _cityController,
    ]) {
      controller.addListener(_refreshWizardState);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _flowController,
      _hmtController,
      _consumptionController,
      _nameController,
      _phoneController,
      _cityController,
    ]) {
      controller.removeListener(_refreshWizardState);
    }
    _flowController.dispose();
    _hmtController.dispose();
    _consumptionController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String _buildAssistantContext(_QuoteFormSpec spec) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Contexte client : Devis Heliantha Solaire (${spec.title} - ${spec.subtitle}).',
    );
    buffer.writeln(
      'Étape actuelle dans le formulaire : ${_currentStep + 1}/$_totalSteps.',
    );

    switch (_kind) {
      case _QuoteProjectKind.pumping:
        buffer.writeln('Type : Pompage Solaire (Forage / Irrigation / Bassin).');
        if (_pumpExisting != null) {
          buffer.writeln(
            _pumpExisting == true
                ? 'Pompe déjà installée : Oui.'
                : 'Projet de nouvelle pompe : Oui.',
          );
        }
        if (_existingPumpCv != null) {
          buffer.writeln(
            'Puissance pompe sélectionnée : ${_existingPumpCv!.toStringAsFixed(1)} CV.',
          );
        }
        if (_flowController.text.trim().isNotEmpty) {
          buffer.writeln(
            'Débit d\'eau souhaité : ${_flowController.text.trim()} m³/h.',
          );
        }
        if (_hmtController.text.trim().isNotEmpty) {
          buffer.writeln(
            'Profondeur / HMT : ${_hmtController.text.trim()} m.',
          );
        }
        break;

      case _QuoteProjectKind.photovoltaic:
        buffer.writeln('Type : Autoconsommation Photovoltaïque (Réduction de facture ONEE).');
        if (_consumptionController.text.trim().isNotEmpty) {
          buffer.writeln(
            'Consommation mensuelle : ${_consumptionController.text.trim()} kWh/mois.',
          );
        }
        if (_meterType.isNotEmpty) {
          buffer.writeln('Compteur : $_meterType.');
        }
        if (_phase.isNotEmpty) {
          buffer.writeln('Réseau électrique : $_phase.');
        }
        break;

      case _QuoteProjectKind.hybrid:
        buffer.writeln('Type : Solaire Hybride avec Stockage Batteries (Off-Grid / Secours).');
        if (_consumptionController.text.trim().isNotEmpty) {
          buffer.writeln(
            'Consommation mensuelle : ${_consumptionController.text.trim()} kWh.',
          );
        }
        if (_phase.isNotEmpty) {
          buffer.writeln('Réseau électrique : $_phase.');
        }
        break;
    }

    if (_cityController.text.trim().isNotEmpty) {
      buffer.writeln('Localisation / Ville : ${_cityController.text.trim()}.');
    }

    if (_result != null) {
      final res = _result!;
      buffer.writeln('--- Dimensionnement calculé par l\'algorithme Heliantha ---');
      if (res.quoteNumber != null) {
        buffer.writeln('Numéro de devis : ${res.quoteNumber}.');
      }
      if (res.powerKwc != null) {
        buffer.writeln(
          'Puissance solaire recommandée : ${res.powerKwc!.toStringAsFixed(2)} kWc.',
        );
      }
      if (res.panelCount != null) {
        buffer.writeln('Nombre de panneaux solaires : ${res.panelCount} panneaux.');
      }
      if (res.inverter != null) {
        buffer.writeln('Onduleur ou variateur solaire : ${res.inverter}.');
      }
      if (res.batteryStorage != null) {
        buffer.writeln('Stockage batteries : ${res.batteryStorage}.');
      }
      if (res.totalTtc != null) {
        buffer.writeln(
          'Prix total estimé : ${res.totalTtc!.toStringAsFixed(0)} MAD TTC.',
        );
      }
    }

    buffer.writeln(
      'Mission de l\'assistant : Répondre avec expertise technique et commerciale au client marocain, '
      'l\'aider à comprendre son devis, la rentabilité, les composants matériels et les garanties Heliantha.',
    );

    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Étude • Installation • Maintenance',
        showBack: true,
        backFallbackLocation: '/quote',
      ),
      body: Stack(
        children: [
          // 1. Fond d'écran avec technicien solaire HeliAntha + texture satinée Apple
          Positioned.fill(
            child: Image.asset(
              helianthaBackgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFF8FAFC).withValues(alpha: 0.88),
                    const Color(0xFFF1F5F9).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          // Halos lumineux subtils (Aurora blur)
          Positioned(
            top: -40,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          // 2. Contenu scrollable (Wizard ou Résultat)
          Positioned.fill(
            child: _result == null ? _buildWizard(spec) : _buildResult(spec),
          ),
          // 3. Orbe IA flottant déplaçable avec contexte projet dynamique
          Positioned.fill(
            child: AiFloatingOrb(
              initialBottomMargin: _result == null ? 18 : 24,
              contextPrompt: _buildAssistantContext(spec),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _result == null
          ? _WizardBottomBar(
              currentStep: _currentStep,
              isLastStep: _isLastStep,
              canContinue: _isCurrentStepComplete && !_submitting,
              submitting: _submitting,
              onBack: _goBack,
              onNext: _goNext,
            )
          : null,
    );
  }

  Widget _buildWizard(_QuoteFormSpec spec) {
    return ListView(
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ResponsivePagePadding(
          bottom: 28,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WizardHeader(
                  spec: spec,
                  currentStep: _currentStep,
                  totalSteps: _totalSteps,
                  onClose: _closeWizard,
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('${_kind.name}-$_currentStep'),
                    child: _buildStepCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(_QuoteFormSpec spec) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ResultHeader(spec: spec, onClose: _closeWizard),
              const SizedBox(height: 16),
              _QuoteResultCard(
                result: _result!,
                kind: _kind,
                selectedPumpCv: _existingPumpCv,
                downloadingPdf: _downloadingPdf,
                onDownloadPdf: _downloadPdf,
                onRestart: _restartEstimate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(
                  title: _stepTitle,
                  subtitle: _stepSubtitle,
                ),
                const SizedBox(height: 18),
                _buildCurrentStepContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_kind) {
      case _QuoteProjectKind.pumping:
        return _buildPumpingStepContent();
      case _QuoteProjectKind.photovoltaic:
        return _buildPhotovoltaicStepContent();
      case _QuoteProjectKind.hybrid:
        return _buildHybridStepContent();
    }
  }

  Widget _buildPumpingStepContent() {
    if (_currentStep == 0) {
      return Column(
        children: [
          _RadioCard<bool>(
            value: true,
            groupValue: _pumpExisting,
            title: 'Oui, une pompe existe déjà',
            subtitle: 'Je connais sa puissance en chevaux.',
            icon: Icons.settings_input_component_outlined,
            onChanged: _setPumpExisting,
          ),
          const SizedBox(height: 12),
          _RadioCard<bool>(
            value: false,
            groupValue: _pumpExisting,
            title: 'Non, j’ai besoin d’une recommandation',
            subtitle: 'Je renseigne le débit et la profondeur.',
            icon: Icons.water_drop_outlined,
            onChanged: _setPumpExisting,
          ),
        ],
      );
    }

    if (_currentStep == 1 && _pumpExisting == true) {
      // Grille de capsules tactiles élégantes (chips) 2 ou 3 colonnes pour les 10 puissances
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Puissance de la pompe (CV) :',
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 400 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pumpPowerOptions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 46,
                ),
                itemBuilder: (context, index) {
                  final option = _pumpPowerOptions[index];
                  final isSelected = option == _existingPumpCv;
                  return _TactileChip(
                    label: '${_formatCompactNumber(option)} CV',
                    selected: isSelected,
                    onTap: () => setState(() {
                      _existingPumpCv = option;
                      _result = null;
                    }),
                  );
                },
              );
            },
          ),
        ],
      );
    }

    if (_currentStep == 1) {
      return Column(
        children: [
          _NumberField(
            controller: _flowController,
            label: 'Débit souhaité (m³/h)',
            icon: Icons.water_outlined,
            validator: (value) => _positiveValidator(
              value,
              fieldName: 'le débit souhaité',
            ),
          ),
          const SizedBox(height: 14),
          _NumberField(
            controller: _hmtController,
            label: 'Profondeur / HMT (mètres)',
            icon: Icons.height_rounded,
            validator: (value) => _positiveValidator(
              value,
              fieldName: 'la profondeur / HMT',
            ),
          ),
        ],
      );
    }

    return _buildContactFields();
  }

  Widget _buildPhotovoltaicStepContent() {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSelector<String>(
            title: 'Type de compteur',
            value: _meterType,
            options: const [
              _ChoiceOption(
                value: 'numerique',
                label: 'Numérique',
                icon: Icons.electric_meter_outlined,
              ),
              _ChoiceOption(
                value: 'mecanique',
                label: 'Mécanique (à disque)',
                icon: Icons.radio_button_checked_rounded,
              ),
            ],
            onChanged: (value) => setState(() {
              _meterType = value;
              _result = null;
            }),
          ),
          const SizedBox(height: 18),
          _ChoiceSelector<String>(
            title: 'Type de réseau',
            value: _phase,
            options: const [
              _ChoiceOption(
                value: 'monophase',
                label: 'Monophasé (220V)',
                icon: Icons.looks_one_rounded,
              ),
              _ChoiceOption(
                value: 'triphase',
                label: 'Triphasé (380V)',
                icon: Icons.looks_3_rounded,
              ),
            ],
            onChanged: (value) => setState(() {
              _phase = value;
              _result = null;
            }),
          ),
        ],
      );
    }

    if (_currentStep == 1) {
      return _buildEnergyFields();
    }

    return _buildContactFields();
  }

  Widget _buildHybridStepContent() {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFA7F3D0),
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.battery_charging_full_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stockage Lithium haute performance inclus',
                    style: TextStyle(
                      color: const Color(0xFF065F46),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildEnergyFields(),
        ],
      );
    }

    return _buildContactFields();
  }

  Widget _buildEnergyFields() {
    return _NumberField(
      controller: _consumptionController,
      label: 'Consommation mensuelle (kWh/mois)',
      icon: Icons.electric_meter_outlined,
      validator: (value) => _positiveValidator(
        value,
        fieldName: 'la consommation mensuelle (kWh/mois)',
      ),
    );
  }

  Widget _buildContactFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputField(
          controller: _nameController,
          label: 'Nom complet',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 2) {
              return 'Saisissez le nom complet.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _phoneController,
          label: 'Numéro de téléphone',
          hintText: '06XXXXXXXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +.-]')),
          ],
          validator: (value) {
            final phone = _compactPhone(value ?? '');
            if (!RegExp(r'^0[567]\d{8}$').hasMatch(phone)) {
              return 'Numéro marocain valide requis : 05, 06 ou 07.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _cityController,
          label: 'Ville',
          icon: Icons.location_city_outlined,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Saisissez la ville.';
            }
            return null;
          },
          onFieldSubmitted: (_) {
            if (_isLastStep && _isCurrentStepComplete && !_submitting) {
              _submit();
            }
          },
        ),
      ],
    );
  }

  String get _stepTitle {
    switch (_kind) {
      case _QuoteProjectKind.pumping:
        if (_currentStep == 0) {
          return 'Avez-vous déjà une pompe ?';
        }
        if (_currentStep == 1) {
          return _pumpExisting == true
              ? 'Puissance de votre pompe'
              : 'Vos besoins en eau';
        }
        return 'Vos coordonnées';
      case _QuoteProjectKind.photovoltaic:
        if (_currentStep == 0) {
          return 'Compteur et réseau';
        }
        if (_currentStep == 1) {
          return 'Votre consommation';
        }
        return 'Vos coordonnées';
      case _QuoteProjectKind.hybrid:
        if (_currentStep == 0) {
          return 'Votre consommation';
        }
        return 'Vos coordonnées';
    }
  }

  String get _stepSubtitle {
    switch (_kind) {
      case _QuoteProjectKind.pumping:
        if (_currentStep == 0) {
          return 'Ce choix oriente les données requises pour le calcul.';
        }
        if (_currentStep == 1 && _pumpExisting == true) {
          return 'Sélectionnez la puissance indiquée sur la plaque pompe.';
        }
        if (_currentStep == 1) {
          return 'Le débit et la HMT permettent un dimensionnement exact.';
        }
        return 'Ces informations permettent de générer votre devis.';
      case _QuoteProjectKind.photovoltaic:
        if (_currentStep == 0) {
          return 'Configurez votre type de compteur et d\'alimentation.';
        }
        if (_currentStep == 1) {
          return 'Renseignez votre consommation mensuelle en kWh.';
        }
        return 'Ces informations permettent de générer votre devis.';
      case _QuoteProjectKind.hybrid:
        if (_currentStep == 0) {
          return 'Renseignez votre consommation mensuelle en kWh.';
        }
        return 'Ces informations permettent de générer votre devis.';
    }
  }

  void _refreshWizardState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _result = null;
    });
  }

  void _setPumpExisting(bool value) {
    setState(() {
      _pumpExisting = value;
      _result = null;
    });
  }

  void _goBack() {
    if (_currentStep == 0 || _submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _currentStep -= 1);
  }

  void _goNext() {
    FocusScope.of(context).unfocus();
    if (!_isCurrentStepComplete) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_isLastStep) {
      _submit();
      return;
    }
    setState(() => _currentStep += 1);
  }

  void _closeWizard() {
    context.go('/quote');
  }

  void _restartEstimate() {
    setState(() {
      _result = null;
      _currentStep = 0;
    });
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_isCurrentStepComplete ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _result = null;
    });

    final payload = QuoteRequestPayload(
      projectType: _spec.apiProjectType,
      data: _buildPayloadData(),
      contact: QuoteContact(
        name: _nameController.text.trim(),
        phone: _compactPhone(_phoneController.text),
        city: _cityController.text.trim(),
      ),
    );

    try {
      final result =
          await ref.read(quoteRepositoryProvider).calculate(payload);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
      AppFeedback.success(context, 'Devis calculé avec succès.');
    } on QuoteApiException catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, 'Impossible de calculer le devis.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    final quoteNumber = _result?.quoteNumber;
    if (quoteNumber == null || quoteNumber.isEmpty) {
      AppFeedback.warning(context, 'Référence devis indisponible.');
      return;
    }

    setState(() => _downloadingPdf = true);
    try {
      await ref.read(quoteRepositoryProvider).downloadAndOpenPdf(quoteNumber);
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, 'PDF enregistré.');
    } on QuoteApiException catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, 'Impossible de télécharger le PDF.');
    } finally {
      if (mounted) {
        setState(() => _downloadingPdf = false);
      }
    }
  }

  Map<String, dynamic> _buildPayloadData() {
    switch (_kind) {
      case _QuoteProjectKind.pumping:
        if (_pumpExisting == true) {
          return {
            'pump_existing': true,
            'existing_pump_cv': _existingPumpCv,
          };
        }
        return {
          'pump_existing': false,
          'flow_m3_h': _parseNumber(_flowController.text),
          'hmt_m': _parseNumber(_hmtController.text),
        };
      case _QuoteProjectKind.photovoltaic:
        return {
          'meter_type': _meterType,
          'phase': _phase,
          'network_type': _phase,
          ..._energyPayload(),
        };
      case _QuoteProjectKind.hybrid:
        return {
          'meter_type': 'numerique',
          'phase': 'monophase',
          'network_type': 'monophase',
          ..._energyPayload(),
        };
    }
  }

  Map<String, dynamic> _energyPayload() {
    final payload = <String, dynamic>{};
    final consumption = _parseNumber(_consumptionController.text);
    if (consumption != null) {
      payload['monthly_consumption_kwh'] = consumption;
    }
    return payload;
  }

  String? _positiveValidator(String? value, {required String fieldName}) {
    final number = _parseNumber(value ?? '');
    if (number == null || number <= 0) {
      return 'Renseignez $fieldName.';
    }
    return null;
  }

  static bool _isPositive(String value) {
    final number = _parseNumber(value);
    return number != null && number > 0;
  }

  static double? _parseNumber(String value) {
    final normalized =
        value.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  static String _compactPhone(String value) {
    return value.replaceAll(RegExp(r'[\s+.-]'), '');
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.spec,
    required this.currentStep,
    required this.totalSteps,
    required this.onClose,
  });

  final _QuoteFormSpec spec;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;
    final percent = (progress * 100).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        spec.icon,
                        color: spec.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spec.title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            spec.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF0F172A),
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Badge "Étape X sur Y" : capsule Bleu Nuit & Or
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFF59E0B),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Étape ${currentStep + 1} sur $totalSteps',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$percent %',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barre de progression dégradé Jaune Solaire HeliAntha (hauteur 4px, rayon 10px)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    color: const Color(0xFFE2E8F0),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WizardBottomBar extends StatelessWidget {
  const _WizardBottomBar({
    required this.currentStep,
    required this.isLastStep,
    required this.canContinue,
    required this.submitting,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final bool isLastStep;
  final bool canContinue;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  if (currentStep > 0) ...[
                    _TactilePressScale(
                      enabled: !submitting,
                      child: OutlinedButton.icon(
                        onPressed: submitting ? null : onBack,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(100, 56),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.85),
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 19,
                        ),
                        label: const Text(
                          'Retour',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _TactilePressScale(
                      enabled: canContinue,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: canContinue
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF0F172A),
                                    Color(0xFF1E293B),
                                  ],
                                )
                              : null,
                          color: canContinue
                              ? null
                              : const Color(0xFFCBD5E1),
                          boxShadow: canContinue
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: canContinue ? onNext : null,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (submitting) ...[
                                    const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Calcul en cours...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      isLastStep
                                          ? Icons.calculate_rounded
                                          : Icons.arrow_forward_rounded,
                                      color: const Color(0xFFF59E0B),
                                      size: 21,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isLastStep
                                          ? 'Calculer mon devis'
                                          : 'Suivant',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.spec,
    required this.onClose,
  });

  final _QuoteFormSpec spec;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    spec.icon,
                    color: spec.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimation Personnalisée',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Text(
                              'Prêt',
                              style: TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              spec.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF0F172A),
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteResultCard extends StatefulWidget {
  const _QuoteResultCard({
    required this.result,
    required this.kind,
    required this.selectedPumpCv,
    required this.downloadingPdf,
    required this.onDownloadPdf,
    required this.onRestart,
  });

  final QuoteCalculationResult result;
  final _QuoteProjectKind kind;
  final double? selectedPumpCv;
  final bool downloadingPdf;
  final VoidCallback onDownloadPdf;
  final VoidCallback onRestart;

  @override
  State<_QuoteResultCard> createState() => _QuoteResultCardState();
}

class _QuoteResultCardState extends State<_QuoteResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _heroAnimation;
  late final List<Animation<double>> _specificationAnimations;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heroAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.48, curve: Curves.easeOutCubic),
    );
    _specificationAnimations = List.generate(4, (index) {
      final start = 0.20 + index * 0.18;
      final end = (start + 0.34).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final kind = widget.kind;
    final quoteNumber = result.quoteNumber;
    final power = result.powerKwc;
    final panels = result.panelCount;
    final deviceLabel = result.inverter ??
        (kind == _QuoteProjectKind.pumping
            ? _fallbackPumpDriveLabel(widget.selectedPumpCv)
            : 'Onduleur inclus');
    final fourthSpec = switch (kind) {
      _QuoteProjectKind.hybrid => _ResultSpecification(
          icon: Icons.battery_charging_full_rounded,
          title: 'Stockage',
          value: result.batteryStorage ?? 'Lithium dimensionné',
          color: const Color(0xFF059669),
        ),
      _QuoteProjectKind.pumping => _ResultSpecification(
          icon: Icons.water_drop_outlined,
          title: 'Pompe',
          value: widget.selectedPumpCv == null
              ? 'Selon étude'
              : '${_formatCompactNumber(widget.selectedPumpCv!)} CV',
          color: const Color(0xFF0284C7),
        ),
      _QuoteProjectKind.photovoltaic => const _ResultSpecification(
          icon: Icons.verified_user_outlined,
          title: 'Particularité',
          value: 'Démarches & pose incluses',
          color: Color(0xFF059669),
        ),
    };
    final specifications = <_ResultSpecification>[
      _ResultSpecification(
        icon: Icons.bolt_rounded,
        title: 'Puissance solaire',
        value:
            power == null ? 'Selon étude' : '${power.toStringAsFixed(2)} kWc',
        color: const Color(0xFFF59E0B),
      ),
      _ResultSpecification(
        icon: Icons.solar_power_rounded,
        title: 'Modules solaires',
        value: panels == null ? 'Sur mesure' : '$panels panneaux',
        color: const Color(0xFF0284C7),
      ),
      _ResultSpecification(
        icon: kind == _QuoteProjectKind.pumping
            ? Icons.settings_input_component_rounded
            : Icons.sync_alt_rounded,
        title: kind == _QuoteProjectKind.pumping ? 'Variateur' : 'Onduleur',
        value: deviceLabel,
        color: const Color(0xFF0284C7),
      ),
      fourthSpec,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _heroAnimation,
          child: _TotalPanel(
            total: result.totalTtc,
            quoteNumber: quoteNumber,
          ),
          builder: (context, child) => FadeTransition(
            opacity: _heroAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1).animate(_heroAnimation),
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSpecification(0, specifications[0])),
            const SizedBox(width: 10),
            Expanded(child: _buildSpecification(1, specifications[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSpecification(2, specifications[2])),
            const SizedBox(width: 10),
            Expanded(child: _buildSpecification(3, specifications[3])),
          ],
        ),
        const SizedBox(height: 20),
        _TactilePressScale(
          enabled: quoteNumber != null && !widget.downloadingPdf,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: quoteNumber == null || widget.downloadingPdf
                    ? null
                    : widget.onDownloadPdf,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.downloadingPdf) ...[
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Génération en cours...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Télécharger mon Devis Officiel (PDF)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _TactilePressScale(
          enabled: !widget.downloadingPdf,
          child: TextButton.icon(
            onPressed: widget.downloadingPdf ? null : widget.onRestart,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFF475569),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.replay_rounded, size: 19),
            label: const Text(
              'Refaire une estimation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecification(int index, _ResultSpecification specification) {
    final animation = _specificationAnimations[index];
    return AnimatedBuilder(
      animation: animation,
      child: _SpecificationCapsule(specification: specification),
      builder: (context, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    );
  }

  static String _fallbackPumpDriveLabel(double? pumpCv) {
    if (pumpCv == null) {
      return 'Variateur solaire adapté';
    }
    return 'Variateur solaire ${_formatCompactNumber(pumpCv)} CV';
  }
}

class _ResultSpecification {
  const _ResultSpecification({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
}

class _TotalPanel extends StatelessWidget {
  const _TotalPanel({
    required this.total,
    required this.quoteNumber,
  });

  final double? total;
  final String? quoteNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34D399),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Devis validé',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (quoteNumber != null)
                Flexible(
                  child: Text(
                    quoteNumber!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'INVESTISSEMENT CLÉ EN MAIN',
            style: TextStyle(
              color: const Color(0xFFF59E0B),
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    total == null ? 'Non communiqué' : _formatMoney(total!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DH TTC',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFFF59E0B),
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Matériel garanti • Installation & démarches incluses',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecificationCapsule extends StatelessWidget {
  const _SpecificationCapsule({required this.specification});

  final _ResultSpecification specification;

  @override
  Widget build(BuildContext context) {
    final spec = specification;
    return Container(
      constraints: const BoxConstraints(minHeight: 136),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    spec.icon,
                    color: spec.color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  spec.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TactilePressScale extends StatefulWidget {
  const _TactilePressScale({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_TactilePressScale> createState() => _TactilePressScaleState();
}

class _TactilePressScaleState extends State<_TactilePressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp:
          widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel:
          widget.enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed && widget.enabled ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _ChoiceSelector<T> extends StatelessWidget {
  const _ChoiceSelector({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<_ChoiceOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile<T>(
                  option: options[i],
                  isSelected: options[i].value == value,
                  onTap: () => onChanged(options[i].value),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _ChoiceOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TactilePressScale(
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFFBEB).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : option.icon,
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF475569),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF334155),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption<T> {
  const _ChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class _TactileChip extends StatelessWidget {
  const _TactileChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TactilePressScale(
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF0F172A)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
                width: selected ? 1.6 : 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFF59E0B),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioCard<T> extends StatelessWidget {
  const _RadioCard({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return _TactilePressScale(
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onChanged(value),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFFBEB).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
                width: selected ? 1.8 : 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF94A3B8),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? const Color(0xFFD97706)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
        fontSize: 14.5,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.90),
        prefixIcon: Icon(icon, color: const Color(0xFF0F172A), size: 21),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFF59E0B),
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.8,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.90),
        prefixIcon: Icon(icon, color: const Color(0xFF0F172A), size: 21),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFF59E0B),
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.8,
          ),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

enum _QuoteProjectKind { pumping, photovoltaic, hybrid }

class _QuoteFormSpec {
  const _QuoteFormSpec({
    required this.apiProjectType,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String apiProjectType;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  factory _QuoteFormSpec.fromKind(_QuoteProjectKind kind) {
    switch (kind) {
      case _QuoteProjectKind.pumping:
        return const _QuoteFormSpec(
          apiProjectType: 'pompage',
          title: 'Pompage solaire',
          subtitle: 'Forage, irrigation et alimentation en eau.',
          icon: Icons.water_drop_outlined,
          accent: Color(0xFF0284C7),
        );
      case _QuoteProjectKind.hybrid:
        return const _QuoteFormSpec(
          apiProjectType: 'hybride',
          title: 'Solaire avec batteries',
          subtitle: 'Système 220V avec stockage sécurisé.',
          icon: Icons.battery_charging_full_rounded,
          accent: Color(0xFF059669),
        );
      case _QuoteProjectKind.photovoltaic:
        return const _QuoteFormSpec(
          apiProjectType: 'autoconsommation',
          title: 'Autoconsommation',
          subtitle: 'Réduisez votre facture avec le solaire.',
          icon: Icons.wb_sunny_outlined,
          accent: Color(0xFFD97706),
        );
    }
  }
}

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final buffer = StringBuffer();
  for (var index = 0; index < parts.first.length; index++) {
    final remaining = parts.first.length - index;
    buffer.write(parts.first[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '${buffer.toString()},${parts.last}';
}

String _formatCompactNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
