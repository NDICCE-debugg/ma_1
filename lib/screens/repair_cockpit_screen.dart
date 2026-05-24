import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';

class RepairCockpitScreen extends StatefulWidget {
  final Map<String, dynamic> assetData;

  const RepairCockpitScreen({super.key, required this.assetData});

  @override
  State<RepairCockpitScreen> createState() => _RepairCockpitScreenState();
}

class _RepairCockpitScreenState extends State<RepairCockpitScreen> {
  int _stage = 0;
  int _procedureStep = 0;
  String _riskLevel = 'Needs calibration';
  final _faultController = TextEditingController(
    text: 'Intermittent alarm during pre-use check.',
  );
  final _alarmController = TextEditingController(text: 'LOW O2 PRESSURE');
  final _readingController =
      TextEditingController(text: 'O2 pressure: 3.8 bar');
  final Set<int> _completedSteps = {};
  final Map<String, String> _verificationReadings = {
    'Leak test': '',
    'O2 cell': '',
    'Flow sensor': '',
  };

  List<_ProcedureStep> get _steps {
    final type = _assetType.toLowerCase();
    if (type.contains('anaesthetic') || type.contains('anesthetic')) {
      return const [
        _ProcedureStep(
          title: 'Make safe',
          instruction:
              'Confirm the workstation is removed from patient service, vaporizers are secured, and gas supplies are isolated before inspection.',
          expected: 'Machine labelled out-of-service and isolated.',
          tools: ['Lockout tag', 'Service key'],
        ),
        _ProcedureStep(
          title: 'Run leak check',
          instruction:
              'Connect the breathing circuit and run the low-pressure leak test from the service menu.',
          expected: 'Leakage within manufacturer limit.',
          tools: ['Breathing circuit', 'Test bag'],
        ),
        _ProcedureStep(
          title: 'Verify oxygen calibration',
          instruction:
              'Expose the O2 sensor to room air and 100% oxygen, then record stability and response time.',
          expected: 'Sensor stabilizes within accepted range.',
          tools: ['O2 source', 'Analyzer'],
        ),
        _ProcedureStep(
          title: 'Final safety check',
          instruction:
              'Confirm alarms, gas delivery, scavenging, and final readiness before return-to-service sign-off.',
          expected: 'All pre-use checks pass.',
          tools: ['Checklist', 'Engineer sign-off'],
        ),
      ];
    }

    return const [
      _ProcedureStep(
        title: 'Make safe',
        instruction:
            'Remove the ventilator from patient service, attach an out-of-service label, and connect the test lung.',
        expected: 'Patient disconnected and test lung installed.',
        tools: ['Test lung', 'Lockout tag'],
      ),
      _ProcedureStep(
        title: 'Check supply pressure',
        instruction:
            'Confirm wall oxygen and air pressures are stable before running internal tests.',
        expected: 'O2 and air supply remain within local SOP range.',
        tools: ['Pressure gauge', 'Gas source'],
      ),
      _ProcedureStep(
        title: 'Run leak test',
        instruction:
            'Start the service leak test and inspect breathing circuit, humidifier, and expiratory valve seals.',
        expected: 'Leak test passes or leak source identified.',
        tools: ['Circuit', 'Expiratory valve'],
      ),
      _ProcedureStep(
        title: 'Calibrate sensors',
        instruction:
            'Run oxygen cell and flow sensor calibration, then record final displayed values.',
        expected: 'O2 and flow readings stabilize after calibration.',
        tools: ['O2 cell', 'Flow sensor'],
      ),
      _ProcedureStep(
        title: 'Return-to-service',
        instruction:
            'Run final alarm test, document readings, attach evidence, and sign the service decision.',
        expected: 'Ready for clinical use or escalated for repair.',
        tools: ['Checklist', 'Engineer sign-off'],
      ),
    ];
  }

  String get _model =>
      widget.assetData['model_name']?.toString() ?? 'Unknown model';
  String get _serial => widget.assetData['serial_number']?.toString() ?? 'N/A';
  String get _assetType =>
      widget.assetData['asset_type']?.toString() ?? 'Equipment';
  String get _unit =>
      widget.assetData['hospital_unit']?.toString() ?? 'Unassigned';

  @override
  void dispose() {
    _faultController.dispose();
    _alarmController.dispose();
    _readingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Repair Cockpit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _showReportPreview,
              icon: const Icon(Icons.article_outlined, size: 17),
              label: const Text('Report'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _assetHeader(),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      SizedBox(width: 286, child: _stageRail()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _stageBody()),
                      SizedBox(width: 310, child: _contextPanel()),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _stageRail(compact: true),
                      const SizedBox(height: 14),
                      _stageBody(),
                      const SizedBox(height: 14),
                      _contextPanel(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _assetHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _iconBox(Icons.precision_manufacturing_rounded, dark: true),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SN $_serial | $_unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(label: _riskLevel, color: AppTheme.warning),
          _StatusPill(
              label: '${_completedSteps.length}/${_steps.length} steps',
              color: AppTheme.secondary),
        ],
      ),
    );
  }

  Widget _stageRail({bool compact = false}) {
    const stages = [
      _Stage('Fault intake', 'Capture alarm, symptoms, readings',
          Icons.error_outline_rounded),
      _Stage('AI triage', 'Risk, likely causes, next checks',
          Icons.auto_awesome_rounded),
      _Stage('Calibration', 'Guided procedure and tools', Icons.tune_rounded),
      _Stage('Verification', 'Pass/fail readings and evidence',
          Icons.fact_check_outlined),
      _Stage('Return decision', 'Generate service outcome',
          Icons.verified_outlined),
    ];

    return Container(
      color: compact ? Colors.transparent : AppTheme.surface,
      padding: EdgeInsets.all(compact ? 0 : 16),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < stages.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StageTile(
                stage: stages[i],
                selected: _stage == i,
                complete: i < _stage,
                onTap: () => setState(() => _stage = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stageBody() {
    final child = switch (_stage) {
      0 => _faultIntake(),
      1 => _triageView(),
      2 => _calibrationView(),
      3 => _verificationView(),
      _ => _returnDecisionView(),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  Widget _faultIntake() {
    return _CockpitCard(
      title: 'Fault Capture',
      description:
          'Start with the observable problem. The cockpit uses this context to guide the repair path.',
      child: Column(
        children: [
          TextField(
            controller: _alarmController,
            decoration: const InputDecoration(
              labelText: 'Alarm code / fault message',
              prefixIcon: Icon(Icons.warning_amber_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _faultController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observed symptom',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _readingController,
            decoration: const InputDecoration(
              labelText: 'Measured readings',
              prefixIcon: Icon(Icons.speed_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Attach image'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text('Audio note'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _nextButton('Run triage', () => setState(() => _stage = 1)),
        ],
      ),
    );
  }

  Widget _triageView() {
    final causes = _alarmController.text.toLowerCase().contains('o2')
        ? [
            'Low supply pressure',
            'Aging O2 cell',
            'Flow sensor drift',
            'Circuit leak'
          ]
        : [
            'Sensor drift',
            'Expired calibration',
            'Loose connector',
            'Service interval overdue'
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CockpitCard(
          title: 'AI Triage Snapshot',
          description:
              'Decision support only. Engineer remains responsible for final verification.',
          child: Column(
            children: [
              _InsightRow(
                icon: Icons.health_and_safety_outlined,
                label: 'Safety recommendation',
                value:
                    'Remove from service until calibration and final leak/alarm checks pass.',
                color: AppTheme.error,
              ),
              _InsightRow(
                icon: Icons.query_stats_rounded,
                label: 'Likely urgency',
                value:
                    'Medium-high because the fault affects clinical readiness.',
                color: AppTheme.warning,
              ),
              _InsightRow(
                icon: Icons.inventory_2_outlined,
                label: 'Parts to check',
                value: 'O2 cell, flow sensor, expiratory valve seal, gas hose.',
                color: AppTheme.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CockpitCard(
          title: 'Likely Causes',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: causes.map((cause) => Chip(label: Text(cause))).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _nextButton(
            'Start guided calibration', () => setState(() => _stage = 2)),
      ],
    );
  }

  Widget _calibrationView() {
    final step = _steps[_procedureStep];

    return _CockpitCard(
      title: 'Guided Calibration',
      description:
          'Follow each checkpoint, record results, and only return equipment after final verification.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_steps.length, (index) {
              final selected = index == _procedureStep;
              final done = _completedSteps.contains(index);
              return ChoiceChip(
                label: Text('${index + 1}. ${_steps[index].title}'),
                selected: selected,
                avatar: done ? const Icon(Icons.check_rounded, size: 16) : null,
                onSelected: (_) => setState(() => _procedureStep = index),
              );
            }),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.muted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 10),
                Text(step.instruction),
                const SizedBox(height: 14),
                _InfoStrip(label: 'Expected result', value: step.expected),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: step.tools
                      .map((tool) => Chip(label: Text(tool)))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _procedureStep == 0
                      ? null
                      : () => setState(() => _procedureStep--),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _completedSteps.add(_procedureStep);
                      if (_procedureStep < _steps.length - 1) {
                        _procedureStep++;
                      } else {
                        _stage = 3;
                      }
                    });
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_procedureStep == _steps.length - 1
                      ? 'Verify'
                      : 'Mark done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verificationView() {
    return _CockpitCard(
      title: 'Verification Readings',
      description:
          'Record final measured values. Failed checks should keep the asset out of service.',
      child: Column(
        children: [
          for (final key in _verificationReadings.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                onChanged: (value) => _verificationReadings[key] = value,
                decoration: InputDecoration(
                  labelText: key,
                  hintText: 'Enter measured value / pass note',
                  prefixIcon: const Icon(Icons.fact_check_outlined),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _riskLevel = 'Escalate repair';
                    _stage = 4;
                  }),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Fail / escalate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() {
                    _riskLevel = 'Ready for service';
                    _stage = 4;
                  }),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Pass checks'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _returnDecisionView() {
    final ready = _riskLevel == 'Ready for service';

    return _CockpitCard(
      title: 'Return-To-Service Decision',
      description:
          'The app prepares the record. The engineer signs the decision.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightRow(
            icon: ready ? Icons.verified_rounded : Icons.block_rounded,
            label: ready ? 'Recommended status' : 'Recommended restriction',
            value: ready
                ? 'Ready for clinical use after engineer sign-off.'
                : 'Keep out of service and escalate to senior technician or supplier.',
            color: ready ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(height: 14),
          _InfoStrip(label: 'Fault', value: _faultController.text),
          const SizedBox(height: 10),
          _InfoStrip(label: 'Alarm', value: _alarmController.text),
          const SizedBox(height: 10),
          _InfoStrip(
              label: 'Calibration',
              value:
                  '${_completedSteps.length}/${_steps.length} steps completed'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _stage = 2),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Review steps'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showReportPreview,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Preview report'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contextPanel() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Machine Context',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          _InfoStrip(label: 'Asset type', value: _assetType),
          const SizedBox(height: 10),
          _InfoStrip(
              label: 'Last service',
              value:
                  widget.assetData['last_service_date']?.toString() ?? 'N/A'),
          const SizedBox(height: 10),
          _InfoStrip(
              label: 'Service interval',
              value: widget.assetData['service_interval']?.toString() ?? 'N/A'),
          const SizedBox(height: 18),
          const Text(
            'Manual-aware prompts',
            style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 10),
          const _PromptButton(label: 'Show relevant manual section'),
          const _PromptButton(label: 'Explain failed calibration check'),
          const _PromptButton(label: 'Suggest spare parts to inspect'),
          const _PromptButton(label: 'Draft technician report note'),
        ],
      ),
    );
  }

  Widget _nextButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(label),
      ),
    );
  }

  Widget _iconBox(IconData icon, {bool dark = false}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: dark ? AppTheme.primary : AppTheme.muted,
        borderRadius: BorderRadius.circular(10),
        border: dark ? null : Border.all(color: AppTheme.divider),
      ),
      child: Icon(icon, color: dark ? Colors.white : AppTheme.secondary),
    );
  }

  void _showReportPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Service Report Preview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 14),
            _InfoStrip(label: 'Machine', value: _model),
            const SizedBox(height: 10),
            _InfoStrip(label: 'Serial', value: _serial),
            const SizedBox(height: 10),
            _InfoStrip(label: 'Fault', value: _faultController.text),
            const SizedBox(height: 10),
            _InfoStrip(label: 'Decision', value: _riskLevel),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Close preview'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcedureStep {
  final String title;
  final String instruction;
  final String expected;
  final List<String> tools;

  const _ProcedureStep({
    required this.title,
    required this.instruction,
    required this.expected,
    required this.tools,
  });
}

class _Stage {
  final String title;
  final String subtitle;
  final IconData icon;

  const _Stage(this.title, this.subtitle, this.icon);
}

class _StageTile extends StatelessWidget {
  final _Stage stage;
  final bool selected;
  final bool complete;
  final VoidCallback onTap;

  const _StageTile({
    required this.stage,
    required this.selected,
    required this.complete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: selected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(
          children: [
            Icon(
              complete ? Icons.check_circle_rounded : stage.icon,
              color: selected ? Colors.white : AppTheme.secondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(
                    stage.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white70 : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
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

class _CockpitCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const _CockpitCard({
    required this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Outfit',
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.14)),
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
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit')),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoStrip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit')),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

class _PromptButton extends StatelessWidget {
  final String label;

  const _PromptButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.auto_awesome_outlined, size: 16),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

