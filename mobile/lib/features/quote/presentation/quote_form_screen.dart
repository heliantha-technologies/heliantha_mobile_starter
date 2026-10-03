import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
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
  final _monthlyBillController = TextEditingController();
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
    return _isPositive(_monthlyBillController.text) ||
        _isPositive(_consumptionController.text);
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
      _monthlyBillController,
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
      _monthlyBillController,
      _consumptionController,
      _nameController,
      _phoneController,
      _cityController,
    ]) {
      controller.removeListener(_refreshWizardState);
    }
    _flowController.dispose();
    _hmtController.dispose();
    _monthlyBillController.dispose();
    _consumptionController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
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
      body: _result == null ? _buildWizard(spec) : _buildResult(spec),
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
              _WizardHeader(
                spec: spec,
                currentStep: _totalSteps - 1,
                totalSteps: _totalSteps,
                onClose: _closeWizard,
              ),
              const SizedBox(height: 16),
              _QuoteResultCard(
                result: _result!,
                kind: _kind,
                downloadingPdf: _downloadingPdf,
                onDownloadPdf: _downloadPdf,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _closeWizard,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Choisir un autre projet'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard() {
    return AppSurface(
      radius: 20,
      shadow: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: _stepTitle,
            subtitle: _stepSubtitle,
          ),
          const SizedBox(height: 16),
          _buildCurrentStepContent(),
        ],
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
          const SizedBox(height: 10),
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
      return _PumpPowerModalField(
        options: _pumpPowerOptions,
        selectedValue: _existingPumpCv,
        onChanged: (value) => setState(() {
          _existingPumpCv = value;
          _result = null;
        }),
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
          const SizedBox(height: 12),
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
            title: 'Compteur',
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
          const SizedBox(height: 16),
          _ChoiceSelector<String>(
            title: 'Réseau',
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
          const InfoPill(
            icon: Icons.battery_charging_full_rounded,
            label: 'Stockage Lithium haute performance',
            backgroundColor: AppColors.softLeaf,
            foregroundColor: AppColors.leaf,
          ),
          const SizedBox(height: 14),
          _buildEnergyFields(),
        ],
      );
    }

    return _buildContactFields();
  }

  Widget _buildEnergyFields() {
    return Column(
      children: [
        _NumberField(
          controller: _monthlyBillController,
          label: 'Facture mensuelle moyenne (MAD)',
          icon: Icons.receipt_long_outlined,
          validator: _energyValidator,
        ),
        const SizedBox(height: 12),
        _NumberField(
          controller: _consumptionController,
          label: 'Consommation (kWh/mois)',
          icon: Icons.electric_meter_outlined,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null;
            }
            return _positiveValidator(
              value,
              fieldName: 'la consommation',
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 2) {
              return 'Saisissez le nom complet.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +.-]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '06XXXXXXXX',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            final phone = _compactPhone(value ?? '');
            if (!RegExp(r'^0[567]\d{8}$').hasMatch(phone)) {
              return 'Numéro marocain valide requis : 05, 06 ou 07.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cityController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Ville',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
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
              ? 'Quelle est la puissance de votre pompe ?'
              : 'Quels sont vos besoins en eau ?';
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
          return 'Ce choix détermine les informations nécessaires au calcul.';
        }
        if (_currentStep == 1 && _pumpExisting == true) {
          return 'Sélectionnez la puissance indiquée sur la pompe.';
        }
        if (_currentStep == 1) {
          return 'Le débit et la HMT permettent de dimensionner la pompe.';
        }
        return 'Nous utilisons ces informations pour générer le devis.';
      case _QuoteProjectKind.photovoltaic:
        if (_currentStep == 0) {
          return 'Ces choix orientent le matériel adapté à votre installation.';
        }
        if (_currentStep == 1) {
          return 'Renseignez la facture ou la consommation mensuelle.';
        }
        return 'Nous utilisons ces informations pour générer le devis.';
      case _QuoteProjectKind.hybrid:
        if (_currentStep == 0) {
          return 'Renseignez la facture ou la consommation mensuelle.';
        }
        return 'Nous utilisons ces informations pour générer le devis.';
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
      final result = await ref.read(quoteRepositoryProvider).calculate(payload);
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
    final bill = _parseNumber(_monthlyBillController.text);
    final consumption = _parseNumber(_consumptionController.text);
    if (bill != null) {
      payload['monthly_bill'] = bill;
    }
    if (consumption != null) {
      payload['monthly_consumption_kwh'] = consumption;
    }
    return payload;
  }

  String? _energyValidator(String? value) {
    final bill = _parseNumber(value ?? '');
    final consumption = _parseNumber(_consumptionController.text);
    if (bill == null && consumption == null) {
      return 'Renseignez la facture ou la consommation.';
    }
    if (value != null &&
        value.trim().isNotEmpty &&
        (bill == null || bill <= 0)) {
      return 'La facture doit être un nombre positif.';
    }
    return null;
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
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
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

    return AppSurface(
      radius: 20,
      shadow: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(
                icon: spec.icon,
                color: spec.accent,
                backgroundColor: spec.soft,
                size: 50,
                iconSize: 26,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Étape ${currentStep + 1} sur $totalSteps',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.slate,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                '$percent %',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sun),
            ),
          ),
        ],
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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: currentStep > 0
                    ? OutlinedButton.icon(
                        onPressed: submitting ? null : onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Retour'),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canContinue ? onNext : null,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Icon(
                          isLastStep
                              ? Icons.calculate_outlined
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    submitting
                        ? 'Calcul...'
                        : isLastStep
                            ? 'Calculer mon devis'
                            : 'Suivant',
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

class _QuoteResultCard extends StatelessWidget {
  const _QuoteResultCard({
    required this.result,
    required this.kind,
    required this.downloadingPdf,
    required this.onDownloadPdf,
  });

  final QuoteCalculationResult result;
  final _QuoteProjectKind kind;
  final bool downloadingPdf;
  final VoidCallback onDownloadPdf;

  @override
  Widget build(BuildContext context) {
    final quoteNumber = result.quoteNumber;
    return AppSurface(
      radius: 20,
      shadow: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.task_alt_rounded,
                color: AppColors.leaf,
                backgroundColor: AppColors.softLeaf,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Synthèse du devis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TotalPanel(total: result.totalTtc),
          const SizedBox(height: 14),
          _ResultLine(
            label: 'Référence devis',
            value: quoteNumber ?? 'Non communiquée',
          ),
          _ResultLine(
            label: 'Puissance',
            value: result.powerKwc == null
                ? 'Non communiquée'
                : '${_formatCompactNumber(result.powerKwc!)} kWc',
          ),
          _ResultLine(
            label: 'Nombre de panneaux',
            value: result.panelCount?.toString() ?? 'Non communiqué',
          ),
          _ResultLine(
            label: kind == _QuoteProjectKind.pumping
                ? 'Variateur sélectionné'
                : 'Onduleur sélectionné',
            value: result.inverter ?? 'Non communiqué',
          ),
          if (kind == _QuoteProjectKind.hybrid || result.batteryStorage != null)
            _ResultLine(
              label: 'Stockage batterie',
              value: result.batteryStorage ?? 'Inclus selon dimensionnement',
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                quoteNumber == null || downloadingPdf ? null : onDownloadPdf,
            icon: downloadingPdf
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              downloadingPdf
                  ? 'Téléchargement...'
                  : 'Télécharger mon Devis Officiel (PDF)',
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalPanel extends StatelessWidget {
  const _TotalPanel({required this.total});

  final double? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Montant Total TTC',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            total == null ? 'Non communiqué' : '${_formatMoney(total!)} DH',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                selected: option.value == value,
                avatar: Icon(option.icon, size: 18),
                label: Text(option.label),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: option.value == value
                          ? AppColors.navy
                          : AppColors.slate,
                      fontWeight: FontWeight.w900,
                    ),
                selectedColor: AppColors.softSun,
                backgroundColor: AppColors.surfaceMuted,
                side: BorderSide(
                  color: option.value == value
                      ? AppColors.premiumLine
                      : AppColors.border,
                ),
                onSelected: (_) => onChanged(option.value),
              ),
          ],
        ),
      ],
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

class _PumpPowerModalField extends StatelessWidget {
  const _PumpPowerModalField({
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<double> options;
  final double? selectedValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = selectedValue == null
        ? 'Choisir une puissance'
        : '${_formatCompactNumber(selectedValue!)} CV';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPicker(context),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selectedValue == null
                ? AppColors.surfaceMuted
                : AppColors.softSun,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selectedValue == null
                  ? AppColors.border
                  : AppColors.premiumLine,
            ),
          ),
          child: Row(
            children: [
              AppIconBadge(
                icon: Icons.speed_rounded,
                size: 42,
                iconSize: 22,
                color: AppColors.blue,
                backgroundColor: AppColors.softBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Touchez pour choisir dans la liste des puissances.',
                      maxLines: 2,
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
              const Icon(Icons.keyboard_arrow_up_rounded,
                  color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AppIconBadge(
                        icon: Icons.speed_rounded,
                        color: AppColors.blue,
                        backgroundColor: AppColors.softBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Puissance de la pompe',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            Text(
                              'Sélectionnez la valeur en CV.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            constraints.maxWidth >= 420 ? 3 : 2;
                        return GridView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 58,
                          ),
                          itemBuilder: (context, index) {
                            final option = options[index];
                            final selected = option == selectedValue;
                            return _PumpPowerTile(
                              value: option,
                              selected: selected,
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(option),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      onChanged(picked);
    }
  }
}

class _PumpPowerTile extends StatelessWidget {
  const _PumpPowerTile({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final double value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppColors.softSun : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.premiumLine : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.navy : AppColors.muted,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatCompactNumber(value)} CV',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(value),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.softSun : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.premiumLine : AppColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.navy : AppColors.muted,
              ),
              const SizedBox(width: 10),
              AppIconBadge(
                icon: icon,
                size: 38,
                iconSize: 20,
                color: selected ? AppColors.navy : AppColors.blue,
                backgroundColor:
                    selected ? AppColors.surface : AppColors.softBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
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
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
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
    required this.soft,
  });

  final String apiProjectType;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color soft;

  factory _QuoteFormSpec.fromKind(_QuoteProjectKind kind) {
    switch (kind) {
      case _QuoteProjectKind.pumping:
        return const _QuoteFormSpec(
          apiProjectType: 'pompage',
          title: 'Pompage solaire',
          subtitle: 'Forage, irrigation et alimentation en eau.',
          icon: Icons.water_drop_outlined,
          accent: AppColors.blue,
          soft: AppColors.softBlue,
        );
      case _QuoteProjectKind.hybrid:
        return const _QuoteFormSpec(
          apiProjectType: 'hybride',
          title: 'Solaire avec batteries',
          subtitle: 'Système 220V avec stockage sécurisé.',
          icon: Icons.battery_charging_full_rounded,
          accent: AppColors.leaf,
          soft: AppColors.softLeaf,
        );
      case _QuoteProjectKind.photovoltaic:
        return const _QuoteFormSpec(
          apiProjectType: 'autoconsommation',
          title: 'Autoconsommation',
          subtitle: 'Réduisez votre facture avec le solaire.',
          icon: Icons.wb_sunny_outlined,
          accent: AppColors.sun,
          soft: AppColors.softSun,
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
