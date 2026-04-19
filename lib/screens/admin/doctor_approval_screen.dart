import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../home/notification_center_screen.dart';

class DoctorApprovalScreen extends StatefulWidget {
  const DoctorApprovalScreen({super.key});
  @override State<DoctorApprovalScreen> createState() => _DoctorApprovalScreenState();
}

class _DoctorApprovalScreenState extends State<DoctorApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Text('🔐 ', style: TextStyle(fontSize: 20)),
          Text('Doctor Requests', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '⏳ Pending'),
            Tab(text: '✅ Approved'),
            Tab(text: '❌ Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DoctorList(status: 'pending', isDark: isDark),
          _DoctorList(status: 'approved', isDark: isDark),
          _DoctorList(status: 'rejected', isDark: isDark),
        ],
      ),
    );
  }
}

class _DoctorList extends StatelessWidget {
  final String status; final bool isDark;
  const _DoctorList({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('verificationStatus', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: SelectableText('Database setup required. Please create the index:\n\n${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(status == 'pending' ? '🎉' : status == 'approved' ? '✅' : '📭',
              style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            status == 'pending' ? 'No pending requests'
                : status == 'approved' ? 'No approved doctors yet' : 'No rejected requests',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _DoctorCard(uid: docs[i].id, data: d, isDark: isDark, status: status);
          },
        );
      },
    );
  }
}

class _DoctorCard extends StatefulWidget {
  final String uid, status; final Map<String, dynamic> data; final bool isDark;
  const _DoctorCard({required this.uid, required this.data, required this.isDark, required this.status});
  @override State<_DoctorCard> createState() => _DoctorCardState();
}

class _DoctorCardState extends State<_DoctorCard> {
  bool _loading = false;

  Future<void> _approve() async {
    final scaffold = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'isVerified': true, 'verificationStatus': 'approved',
        'verifiedAt': DateTime.now().toIso8601String(),
      });
      await NotificationHelper.send(
        uid: widget.uid, type: 'doctor_approved',
        titleAr: '✅ تم قبول حسابك كدكتور!',
        titleEn: '✅ Your doctor account is approved!',
        bodyAr: 'مرحباً دكتور ${widget.data['fullName'] ?? ''}! تم التحقق من حسابك. يمكنك الآن إنشاء الكورسات ورفع المواد.',
        bodyEn: 'Welcome Dr. ${widget.data['fullName'] ?? ''}! Your account is verified. You can now create courses and upload materials.',
      );
      scaffold.showSnackBar(const SnackBar(
        content: Text('✅ Doctor approved and notified'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      scaffold.showSnackBar(SnackBar(
        content: Text('❌ Error: $e'), backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rejection Reason'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Reason will be sent to the doctor:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Missing credentials, invalid information...',
                  border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    final scaffold = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'isVerified': false, 'verificationStatus': 'rejected',
        'rejectionReason': reason, 'rejectedAt': DateTime.now().toIso8601String(),
      });
      await NotificationHelper.send(
        uid: widget.uid, type: 'doctor_rejected',
        titleAr: '❌ تم رفض طلب التحقق', titleEn: '❌ Doctor verification rejected',
        bodyAr: reason.isNotEmpty ? 'السبب: $reason' : 'تم رفض طلبك. يرجى التواصل مع الدعم.',
        bodyEn: reason.isNotEmpty ? 'Reason: $reason' : 'Your request was rejected. Please contact support.',
      );
      scaffold.showSnackBar(const SnackBar(
        content: Text('❌ Doctor rejected and notified'), 
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      scaffold.showSnackBar(SnackBar(
        content: Text('❌ Error: $e'), backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = d['fullName'] ?? 'Unknown';
    final teaching = (d['teachingAt'] as List?)?.map((t) {
      final uni = t['universityAr'] ?? t['uniAr'] ?? '';
      final fac = t['facultyAr'] ?? t['facAr'] ?? '';
      return '$uni · $fac';
    }).join('\n') ?? '${d['universityAr'] ?? ''} · ${d['facultyAr'] ?? ''}';
    final createdAt = d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null;
    final rejReason = d['rejectionReason'] as String?;

    final statusColor = widget.status == 'approved' ? Colors.green
        : widget.status == 'pending' ? Colors.orange : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1730) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24, backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  widget.status == 'approved' ? '✅ Approved' : widget.status == 'pending' ? '⏳ Pending' : '❌ Rejected',
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
            Text(d['email'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ])),
          if (createdAt != null)
            Text('${createdAt.day}/${createdAt.month}/${createdAt.year}',
                style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.school_outlined, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 7),
          Expanded(child: Text(teaching.isNotEmpty ? teaching : 'No teaching info',
              style: const TextStyle(fontSize: 13, height: 1.5))),
        ]),
        if (rejReason != null && rejReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text('Reason: $rejReason', style: const TextStyle(color: Colors.red, fontSize: 12))),
            ]),
          ),
        ],
        if (widget.status == 'pending') ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loading ? null : _approve,
              icon: _loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loading ? null : _reject,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ],
      ])),
    );
  }
}