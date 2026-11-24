import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';

class NoticeStatusBadge extends StatelessWidget {
  final PlacementNotice notice;

  const NoticeStatusBadge({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final label = notice.effectiveBadgeLabel;
    final Color bg;
    final Color fg;

    switch (label) {
      case 'Closed':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        break;
      case 'Closing Soon':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'Upcoming':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF6D28D9);
        break;
      case 'New':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'Open':
      default:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OpportunityTypeChip extends StatelessWidget {
  final OpportunityType type;

  const OpportunityTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.label,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class BranchChipsWrap extends StatelessWidget {
  final bool isAllBranches;
  final List<String> branches;
  final int? maxVisible;

  const BranchChipsWrap({
    super.key,
    required this.isAllBranches,
    required this.branches,
    this.maxVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (isAllBranches || branches.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'All Branches',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0369A1),
          ),
        ),
      );
    }

    final visible = maxVisible != null && branches.length > maxVisible!
        ? branches.take(maxVisible!).toList()
        : branches;
    final overflowCount = branches.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...visible.map(
          (b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.slateBorder),
            ),
            child: Text(
              b,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
        ),
        if (overflowCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$overflowCount more',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.slateMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class PlacementNoticeCard extends StatelessWidget {
  final PlacementNotice notice;
  final VoidCallback onTap;
  final bool showUnreadIndicator;
  final Widget? trailingMenu;

  const PlacementNoticeCard({
    super.key,
    required this.notice,
    required this.onTap,
    this.showUnreadIndicator = false,
    this.trailingMenu,
  });

  String _formatDeadline(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = showUnreadIndicator && !notice.isRead && !notice.isClosed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unread
              ? AppTheme.saffron
              : (notice.isClosingSoon
                    ? Colors.red.shade300
                    : (isDark ? Colors.grey.shade800 : AppTheme.slateBorder)),
          width: unread || notice.isClosingSoon ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.ink.withValues(alpha: 0.08),
                    child: Text(
                      notice.companyName.isNotEmpty
                          ? notice.companyName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (unread) ...[
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.saffron,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                notice.companyName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notice.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade300 : AppTheme.slateMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  NoticeStatusBadge(notice: notice),
                  ?trailingMenu,
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OpportunityTypeChip(type: notice.opportunityType),
                  BranchChipsWrap(
                    isAllBranches: notice.isAllBranches,
                    branches: notice.targetBranches,
                    maxVisible: 3,
                  ),
                ],
              ),
              if (notice.description != null &&
                  notice.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  notice.description!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ],
              if (notice.applicationDeadline != null ||
                  notice.attachments.isNotEmpty ||
                  (notice.applicationLink != null &&
                      notice.applicationLink!.isNotEmpty)) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (notice.applicationDeadline != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: notice.isClosingSoon
                              ? Colors.red.shade50
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: notice.isClosingSoon
                                  ? Colors.red.shade800
                                  : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Deadline: ${_formatDeadline(notice.applicationDeadline!)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: notice.isClosingSoon
                                    ? Colors.red.shade900
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (notice.attachments.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.attach_file,
                            size: 14,
                            color: AppTheme.slateMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${notice.attachments.length} attachment${notice.attachments.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    if (notice.applicationLink != null &&
                        notice.applicationLink!.isNotEmpty)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Apply link',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NoticeAttachmentTile extends StatefulWidget {
  final NoticeAttachment attachment;

  const NoticeAttachmentTile({super.key, required this.attachment});

  @override
  State<NoticeAttachmentTile> createState() => _NoticeAttachmentTileState();
}

class _NoticeAttachmentTileState extends State<NoticeAttachmentTile> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final url = await PlacementRepositoryProvider.instance
          .getAttachmentUrl(widget.attachment.filePath);
      if (url == null || url.isEmpty) {
        if (mounted) showSnack(context, 'Document URL is unavailable.', error: true);
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open attachment: $e', error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachment;
    final IconData icon = att.isPdf
        ? Icons.picture_as_pdf_outlined
        : att.isImage
            ? Icons.image_outlined
            : Icons.description_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.ink.withValues(alpha: 0.08),
          child: Icon(icon, color: AppTheme.ink),
        ),
        title: Text(
          att.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          att.fileType.toUpperCase(),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: _opening
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.open_in_new, size: 18),
        onTap: _opening ? null : _open,
      ),
    );
  }
}
