import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models/itr_model.dart';
import '../../data/services/itr_service.dart';

class ItrSubmissionScreen extends StatefulWidget {
  final ItrModel itr;
  final ItrService itrService;

  const ItrSubmissionScreen({
    super.key,
    required this.itr,
    required this.itrService,
  });

  @override
  State<ItrSubmissionScreen> createState() => _ItrSubmissionScreenState();
}

class _ItrSubmissionScreenState extends State<ItrSubmissionScreen> {
  late final TextEditingController _contentController;

  PlatformFile? _projectZipFile;
  PlatformFile? _presentationFile;

  Uint8List? _projectZipBytes;
  Uint8List? _presentationBytes;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _contentController = TextEditingController(text: widget.itr.content ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickProjectZip() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (files.isEmpty) return;

      final file = files.single;

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _projectZipFile = file;
        _projectZipBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select ZIP file: $e')));
    }
  }

  Future<void> _pickPresentation() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ppt', 'pptx'],
      );

      if (files.isEmpty) return;

      final file = files.single;

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _presentationFile = file;
        _presentationBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to select presentation: $e')),
      );
    }
  }

  Future<void> _submitItr() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your internship work details.'),
        ),
      );
      return;
    }

    if (_projectZipFile == null && widget.itr.projectZipPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your project ZIP file.')),
      );
      return;
    }

    if (_presentationFile == null && widget.itr.presentationPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your project presentation.'),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      String? projectZipPath = widget.itr.projectZipPath;
      String? presentationPath = widget.itr.presentationPath;

      if (_projectZipFile != null && _projectZipBytes != null) {
        projectZipPath = await widget.itrService.uploadProjectZip(
          itrId: widget.itr.id,
          fileName: _projectZipFile!.name,
          fileBytes: _projectZipBytes!,
        );
      }

      if (_presentationFile != null && _presentationBytes != null) {
        presentationPath = await widget.itrService.uploadProjectPresentation(
          itrId: widget.itr.id,
          fileName: _presentationFile!.name,
          fileBytes: _presentationBytes!,
        );
      }

      final updatedItr = ItrModel(
        id: widget.itr.id,
        internshipId: widget.itr.internshipId,
        studentId: widget.itr.studentId,
        studentName: widget.itr.studentName,
        internshipTitle: widget.itr.internshipTitle,
        companyName: widget.itr.companyName,
        status: 'submitted',
        content: _contentController.text.trim(),
        documentPath: widget.itr.documentPath,
        projectZipPath: projectZipPath,
        presentationPath: presentationPath,
        submittedAt: DateTime.now(),
        reviewerName: widget.itr.reviewerName,
        remarks: widget.itr.remarks,
      );

      await widget.itrService.submitItr(updatedItr);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ITR submitted successfully.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to submit ITR: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _buildFileCard({
    required String title,
    required String description,
    required IconData icon,
    required String? fileName,
    required VoidCallback onPick,
    required VoidCallback? onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40),

            const SizedBox(height: 12),

            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(description, textAlign: TextAlign.center),

            const SizedBox(height: 12),

            if (fileName != null)
              Row(
                children: [
                  const Icon(Icons.attach_file),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(fileName, overflow: TextOverflow.ellipsis),
                  ),

                  if (onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onRemove,
                    ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose File'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectFileName =
        _projectZipFile?.name ??
        (widget.itr.projectZipPath != null
            ? 'Previously uploaded project'
            : null);

    final presentationFileName =
        _presentationFile?.name ??
        (widget.itr.presentationPath != null
            ? 'Previously uploaded presentation'
            : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Submit ITR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.itr.internshipTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.itr.companyName,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),

              const SizedBox(height: 24),

              const Text(
                'Work Done During Internship',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Internship Work Details',
                  hintText: 'Describe the work you completed, technologies used, features developed, learning outcomes, and your contribution...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Project Submission',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _buildFileCard(
                title: 'Project ZIP File',
                description:
                    'Upload the complete project source code in a ZIP file.',
                icon: Icons.folder_zip,
                fileName: projectFileName,
                onPick: _pickProjectZip,
                onRemove: _projectZipFile != null
                    ? () {
                        setState(() {
                          _projectZipFile = null;
                          _projectZipBytes = null;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildFileCard(
                title: 'Project Presentation',
                description: 'Upload your project PPT or PPTX presentation.',
                icon: Icons.slideshow,
                fileName: presentationFileName,
                onPick: _pickPresentation,
                onRemove: _presentationFile != null
                    ? () {
                        setState(() {
                          _presentationFile = null;
                          _presentationBytes = null;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitItr,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Submitting...' : 'Submit ITR'),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
