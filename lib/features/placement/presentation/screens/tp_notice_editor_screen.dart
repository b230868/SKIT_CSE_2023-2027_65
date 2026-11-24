import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';

/// Fast Company Notice Forwarding & Creation screen for T&P Cell.
/// Only Company Name, target branch selection, and notice content (text or PDF)
/// are required — all other fields are optional so T&P can publish in seconds.
class TpNoticeEditorScreen extends StatefulWidget {
  final PlacementNotice? existing;

  const TpNoticeEditorScreen({super.key, this.existing});

  @override
  State<TpNoticeEditorScreen> createState() => _TpNoticeEditorScreenState();
}

class _TpNoticeEditorScreenState extends State<TpNoticeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PlacementRepositoryProvider.instance;

  late final TextEditingController _companyCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _eligibilityCtrl;
  late final TextEditingController _processCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _notesCtrl;
  final _customBranchCtrl = TextEditingController();

  OpportunityType _opportunityType = OpportunityType.campusRecruitment;
  NoticeStatus _status = NoticeStatus.open;
  bool _isAllBranches = false;
  final Set<String> _selectedBranches = {};
  List<String> _availableBranches = [];
  List<CompanyOption> _companies = [];
  String? _selectedIndustryId;

  DateTime? _deadline;
  DateTime? _recruitmentDate;
  bool _notifyStudents = true;
  bool _showMoreDetails = false;
  bool _loadingMeta = true;
  bool _submitting = false;

  final List<PlatformFile> _pickedFiles = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _companyCtrl = TextEditingController(text: e?.companyName ?? '');
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _eligibilityCtrl = TextEditingController(text: e?.eligibility ?? '');
    _processCtrl = TextEditingController(text: e?.recruitmentProcess ?? '');
    _linkCtrl = TextEditingController(text: e?.applicationLink ?? '');
    _notesCtrl = TextEditingController(text: e?.additionalNotes ?? '');

    if (e != null) {
      _opportunityType = e.opportunityType;
      _status = e.status;
      _isAllBranches = e.isAllBranches;
      _selectedBranches.addAll(e.targetBranches);
      _selectedIndustryId = e.industryId;
      _deadline = e.applicationDeadline;
      _recruitmentDate = e.recruitmentDate;
      _notifyStudents = e.notifyStudents;
      _showMoreDetails =
          (e.eligibility?.isNotEmpty ?? false) ||
          (e.recruitmentProcess?.isNotEmpty ?? false) ||
          (e.additionalNotes?.isNotEmpty ?? false) ||
          e.recruitmentDate != null;
    }

    _loadMetadata();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _eligibilityCtrl.dispose();
    _processCtrl.dispose();
    _linkCtrl.dispose();
    _notesCtrl.dispose();
    _customBranchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final results = await Future.wait([
        _repo.getAvailableBranches(),
        _repo.getCompanies(),
      ]);
      if (!mounted) return;
      final branches = (results[0] as List<String>).toSet()
        ..addAll(_selectedBranches);
      final sorted = branches.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _availableBranches = sorted;
        _companies = results[1] as List<CompanyOption>;
        _loadingMeta = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  void _addCustomBranch() {
    final val = _customBranchCtrl.text.trim();
    if (val.isEmpty) return;
    setState(() {
      if (!_availableBranches.any((b) => b.toLowerCase() == val.toLowerCase())) {
        _availableBranches.add(val);
      }
      _selectedBranches.add(val);
      _isAllBranches = false;
      _customBranchCtrl.clear();
    });
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (res.isEmpty) return;

    for (final file in res) {
      final size = await file.length();
      if (size != null && size > 15 * 1024 * 1024) {
        if (mounted) {
          showSnack(context, '${file.name} exceeds 15 MB limit.', error: true);
        }
        continue;
      }
      if (mounted) {
        setState(() => _pickedFiles.add(file));
      }
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now.add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime(2026, 1, 1, 17, 0)),
    );
    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _pickDriveDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _recruitmentDate ?? now.add(const Duration(days: 5)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date != null) {
      setState(() => _recruitmentDate = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isAllBranches && _selectedBranches.isEmpty) {
      showSnack(
        context,
        'Select at least one target branch or enable "All Branches".',
        error: true,
      );
      return;
    }

    final hasContent = _descriptionCtrl.text.trim().isNotEmpty ||
        _titleCtrl.text.trim().isNotEmpty ||
        _linkCtrl.text.trim().isNotEmpty ||
        _pickedFiles.isNotEmpty ||
        (widget.existing?.attachments.isNotEmpty ?? false);

    if (!hasContent) {
      showSnack(
        context,
        'Paste the company notice message, attach a PDF/image, or add a title/link.',
        error: true,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_isEdit) {
        await _repo.updateNotice(
          noticeId: widget.existing!.id,
          companyName: _companyCtrl.text.trim(),
          industryId: _selectedIndustryId,
          opportunityType: _opportunityType,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          eligibility: _eligibilityCtrl.text.trim(),
          recruitmentProcess: _processCtrl.text.trim(),
          additionalNotes: _notesCtrl.text.trim(),
          applicationLink: _linkCtrl.text.trim(),
          applicationDeadline: _deadline,
          recruitmentDate: _recruitmentDate,
          isAllBranches: _isAllBranches,
          targetBranches: _selectedBranches.toList(),
          status: _status,
          notifyStudents: _notifyStudents,
          newAttachments: _pickedFiles,
        );
      } else {
        await _repo.createNotice(
          companyName: _companyCtrl.text.trim(),
          industryId: _selectedIndustryId,
          opportunityType: _opportunityType,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          eligibility: _eligibilityCtrl.text.trim(),
          recruitmentProcess: _processCtrl.text.trim(),
          additionalNotes: _notesCtrl.text.trim(),
          applicationLink: _linkCtrl.text.trim(),
          applicationDeadline: _deadline,
          recruitmentDate: _recruitmentDate,
          isAllBranches: _isAllBranches,
          targetBranches: _selectedBranches.toList(),
          status: _status,
          notifyStudents: _notifyStudents,
          attachments: _pickedFiles,
        );
      }

      if (!mounted) return;
      showSnack(
        context,
        _isEdit
            ? 'Placement notice updated.'
            : 'Notice published and targeted students notified.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Could not publish notice: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Placement Notice' : 'Publish / Forward Notice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fast Forward: Enter company name, paste the notice or attach PDF/image, select branches, and publish. All other fields are optional.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),

            // 1. Company Name (with Autocomplete from industries & past notices)
            Autocomplete<CompanyOption>(
              initialValue: TextEditingValue(text: _companyCtrl.text),
              displayStringForOption: (o) => o.name,
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) return _companies.take(8);
                return _companies.where((c) => c.name.toLowerCase().contains(q));
              },
              onSelected: (option) {
                _companyCtrl.text = option.name;
                _selectedIndustryId = option.id.isNotEmpty ? option.id : null;
              },
              fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
                ctrl.addListener(() {
                  _companyCtrl.text = ctrl.text;
                });
                return TextFormField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    hintText: 'Type or select company (e.g. TCS, ABC Technologies)',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Opportunity Type
            const Text(
              'Opportunity Type',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: OpportunityType.values.map((t) {
                final selected = _opportunityType == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  selectedColor: AppTheme.ink,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.ink,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _opportunityType = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 3. Branch Targeting
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Branches *',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Row(
                          children: [
                            const Text('All Branches', style: TextStyle(fontSize: 12)),
                            Switch(
                              value: _isAllBranches,
                              onChanged: (v) => setState(() => _isAllBranches = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_loadingMeta)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (!_isAllBranches) ...[
                      if (_availableBranches.isEmpty)
                        const Text(
                          'No branches found in existing student profiles yet. Add branches below:',
                          style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _availableBranches.map((branch) {
                            final selected = _selectedBranches.contains(branch);
                            return FilterChip(
                              label: Text(branch),
                              selected: selected,
                              selectedColor: AppTheme.ink,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : AppTheme.ink,
                                fontSize: 12,
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                              onSelected: (on) {
                                setState(() {
                                  if (on) {
                                    _selectedBranches.add(branch);
                                  } else {
                                    _selectedBranches.remove(branch);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customBranchCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Add branch (if not listed)',
                                hintText: 'e.g. CSE, IT, IoT, Civil, Mechanical',
                                isDense: true,
                              ),
                              onSubmitted: (_) => _addCustomBranch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(80, 44),
                            ),
                            onPressed: _addCustomBranch,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Company-Provided Notice / Message (As-is)
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Company Notice / Message (paste as-is)',
                hintText:
                    'e.g. ABC Technologies is hiring CSE/IT students. Apply using the attached form before 5 PM tomorrow.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),

            // 5. Attachments (PDF / Image / Doc)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Company PDFs / Documents / Images',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        TextButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Attach File'),
                        ),
                      ],
                    ),
                    if (widget.existing != null &&
                        widget.existing!.attachments.isNotEmpty)
                      ...widget.existing!.attachments.map(
                        (a) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                          title: Text(a.fileName, style: const TextStyle(fontSize: 12)),
                          subtitle: const Text('Already uploaded', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    if (_pickedFiles.isEmpty &&
                        (widget.existing?.attachments.isEmpty ?? true))
                      const Text(
                        'Optional: Attach recruitment notice PDF, JD, brochure, or poster image.',
                        style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                      ),
                    ..._pickedFiles.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final f = entry.value;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined, size: 18),
                        title: Text(f.name, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _pickedFiles.removeAt(idx)),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 6. Quick Deadline & Official Link
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDeadline,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Application Deadline (optional)',
                        prefixIcon: const Icon(Icons.schedule),
                        suffixIcon: _deadline != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _deadline = null),
                              )
                            : null,
                      ),
                      child: Text(
                        _deadline == null
                            ? 'Not specified'
                            : DateFormat('dd MMM yyyy, hh:mm a').format(_deadline!),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Official Application / Form Link (optional)',
                hintText: 'https://forms.gle/... or company careers URL',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 14),

            // 7. Optional Structured Details (Expandable so form stays fast!)
            ExpansionTile(
              initiallyExpanded: _showMoreDetails,
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Optional Details (Short Title, Eligibility, Process, Drive Date)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short Title (auto-filled if blank)',
                    hintText: 'e.g. Campus Drive 2026 - Software Engineer',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _eligibilityCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Eligibility Criteria (optional)',
                    hintText: 'e.g. 6.5 CGPA+, no active backlogs, 2027 batch',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _processCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Recruitment Process (paste as-is)',
                    hintText: 'e.g. Online Test -> Technical Interview -> HR Interview',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDriveDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Recruitment / Drive Date (optional)',
                      prefixIcon: const Icon(Icons.event),
                      suffixIcon: _recruitmentDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _recruitmentDate = null),
                            )
                          : null,
                    ),
                    child: Text(
                      _recruitmentDate == null
                          ? 'Not scheduled yet'
                          : fmtDate(_recruitmentDate!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional T&P Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NoticeStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Notice Status',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: NoticeStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Notify eligible branch students',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Sends an in-app notification only to students in the targeted branches.',
                style: TextStyle(fontSize: 12),
              ),
              value: _notifyStudents,
              onChanged: (v) => setState(() => _notifyStudents = v),
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _submitting
                    ? 'Publishing...'
                    : (_isEdit ? 'Save Notice Changes' : 'Publish Notice'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
