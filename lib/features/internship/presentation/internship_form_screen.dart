import 'package:flutter/material.dart';

import '../../../core/utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/internship_service.dart';
import '../models/internship.dart';

/// Apply for a new internship, or edit one that is still pending.
class InternshipFormScreen extends StatefulWidget {
  final Internship? existing;
  const InternshipFormScreen({super.key, this.existing});

  @override
  State<InternshipFormScreen> createState() => _InternshipFormScreenState();
}

class _InternshipFormScreenState extends State<InternshipFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = InternshipService();
  late final TextEditingController _company;
  late final TextEditingController _title;
  late final TextEditingController _description;
  String _mode = 'onsite';
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _company = TextEditingController(text: e?.companyName ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _mode = e?.mode ?? 'onsite';
    _start = e?.startDate;
    _end = e?.endDate;
  }

  @override
  void dispose() {
    _company.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _start : _end) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null || _end == null) {
      showSnack(context, 'Choose the start and end dates', error: true);
      return;
    }
    if (_end!.isBefore(_start!)) {
      showSnack(context, 'End date must be on or after the start date', error: true);
      return;
    }

    setState(() => _saving = true);
    final desc = _description.text.trim().isEmpty ? null : _description.text.trim();
    try {
      if (_isEdit) {
        await _service.update(
          widget.existing!.id,
          companyName: _company.text.trim(),
          title: _title.text.trim(),
          description: desc,
          mode: _mode,
          startDate: _start!,
          endDate: _end!,
        );
      } else {
        await _service.create(
          companyName: _company.text.trim(),
          title: _title.text.trim(),
          description: desc,
          mode: _mode,
          startDate: _start!,
          endDate: _end!,
        );
      }
      if (mounted) {
        showSnack(context, _isEdit ? 'Changes saved' : 'Application submitted');
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateField(String label, DateTime? value, bool isStart) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _pickDate(isStart: isStart),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(value == null ? 'Select date' : fmtDate(value)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Edit application' : 'Apply for internship')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _company,
                      label: 'Company name',
                      icon: Icons.business_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the company name'
                          : null,
                    ),
                    AppTextField(
                      controller: _title,
                      label: 'Internship role',
                      icon: Icons.work_outline,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the role or title'
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        value: _mode,
                        decoration: const InputDecoration(
                          labelText: 'Work mode',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'onsite', child: Text('On-site')),
                          DropdownMenuItem(value: 'remote', child: Text('Remote')),
                          DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                        ],
                        onChanged: (v) => setState(() => _mode = v ?? 'onsite'),
                      ),
                    ),
                    _dateField('Start date', _start, true),
                    _dateField('End date', _end, false),
                    AppTextField(
                      controller: _description,
                      label: 'What will you work on? (optional)',
                      icon: Icons.notes_outlined,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(_isEdit ? 'Save changes' : 'Submit application'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
