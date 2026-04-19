import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppMeetingScreen extends StatefulWidget {
  final String roomName;
  final String title;
  final bool isAr;
  final String? displayName;

  const InAppMeetingScreen({
    super.key,
    required this.roomName,
    required this.title,
    required this.isAr,
    this.displayName,
  });

  @override
  State<InAppMeetingScreen> createState() => _InAppMeetingScreenState();
}

class _InAppMeetingScreenState extends State<InAppMeetingScreen> {
  // ignore: unused_field
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), _launchJitsi);
  }

  Future<void> _launchJitsi() async {
    final name = Uri.encodeComponent(widget.displayName ?? (widget.isAr ? 'User' : 'User'));
    final url = 'https://meet.jit.si/${widget.roomName}'
        '#userInfo.displayName="$name"'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&config.enableWelcomePage=false'
        '&config.disableInviteFunctions=true'
        '&config.subject=${Uri.encodeComponent(widget.title)}';

    try {
      if (mounted) setState(() => _launched = true);
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );
      // Removed automatic pop! launchUrl returns immediately on Android/iOS when launching inAppWebView.
      // If we popped here, it would kick them out of the meeting screen entirely.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch meeting...'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.videocam_rounded, color: Color(0xFF4ADE80), size: 40),
              ),
              const SizedBox(height: 30),
              Text(
                widget.isAr ? 'غرفة الاجتماع جاهزة' : 'Meeting Room Ready',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isAr 
                  ? 'إذا لم تُفتح الغرفة تلقائياً، يمكنك النقر على الزر أدناه للدخول.' 
                  : 'If the room did not open automatically, tap the button below to join.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _launchJitsi,
                icon: const Icon(Icons.launch_rounded, color: Colors.black87),
                label: Text(
                  widget.isAr ? 'دخول الاجتماع الآن' : 'Join Meeting Now',
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ADE80),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String generateMeetingRoomName(String courseId) {
  final short = courseId.length >= 8 ? courseId.substring(0, 8) : courseId;
  return 'StudyHub-$short';
}
