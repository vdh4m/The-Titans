import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/xp_service.dart';
import '../payment/paywall_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FlashcardScreen
//  • Student: create decks, add cards, delete cards (swipe or long-press)
//  • Fixes bottom overflow in the add-card dialog
// ─────────────────────────────────────────────────────────────────────────────
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;
  String? _deckId;
  String? _deckName;
  List<Map<String, dynamic>> _decks = [];

  @override void initState() { super.initState(); _loadDecks(); }

  String? get _uid => context.read<AuthProvider>().currentUser?.uid;
  bool   get _isAr => context.read<AppProvider>().isArabic;

  Future<void> _loadDecks() async {
    if (_uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('flashcard_decks')
        .where('userId', isEqualTo: _uid)
        .get();
    setState(() {
      _decks = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      _loading = false;
    });
  }

  Future<void> _loadCards(String deckId, String name) async {
    setState(() { _loading = true; _deckId = deckId; _deckName = name; });
    final snap = await FirebaseFirestore.instance
        .collection('flashcard_decks').doc(deckId)
        .collection('cards').get();
    setState(() {
      _cards = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      _currentIndex = 0; _showAnswer = false; _loading = false;
    });
  }

  // ── Create deck ─────────────────────────────────────────────────────────────
  Future<void> _createDeck() async {
    // ── Paywall check ─────────────────────────────────────────────────────
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !PaywallGate.canAccess(user, PremiumFeature.extraFlashcards)) {
      PaywallGate.showUpgradeSheet(
        context,
        feature: PremiumFeature.extraFlashcards,
        titleAr: 'وصلت للحد الأقصى من المجموعات (${user.maxDecks})',
        titleEn: 'You reached your deck limit (${user.maxDecks})',
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final isAr = _isAr;
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isAr ? 'مجموعة جديدة' : 'New Deck'),
      content: TextField(
        controller: nameCtrl, autofocus: true,
        decoration: InputDecoration(
          hintText: isAr ? 'اسم المجموعة' : 'Deck name',
          prefixIcon: const Icon(Icons.style_rounded)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            await FirebaseFirestore.instance.collection('flashcard_decks').add({
              'name': nameCtrl.text.trim(), 'userId': _uid,
              'createdAt': DateTime.now().toIso8601String(), 'cardCount': 0,
            });
            await XpService.award(_uid, XpEvent.createDeck);
            if (ctx.mounted) Navigator.pop(ctx);
            _loadDecks();

            _tryAwardBadge('flashcard_10');
          },
          child: Text(isAr ? 'إنشاء' : 'Create'),
        ),
      ],
    ));
  }

  // ── Add card (overflow fixed: use bottom sheet instead of dialog) ──────────
  Future<void> _addCard() async {
    if (_deckId == null) return;
    final isAr = _isAr;
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1730) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(ctx).padding.bottom + 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // handle
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(width: 4, height: 24,
                  decoration: BoxDecoration(color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Text(isAr ? '🃏 بطاقة جديدة' : '🃏 New Card',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor)),
            ]),
            const SizedBox(height: 18),
            TextField(
              controller: qCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isAr ? 'السؤال / الوجه الأمامي' : 'Question / Front',
                prefixIcon: const Icon(Icons.help_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isAr ? 'الإجابة / الوجه الخلفي' : 'Answer / Back',
                prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty) return;
                  final deckRef = FirebaseFirestore.instance
                      .collection('flashcard_decks').doc(_deckId);
                  await deckRef.collection('cards').add({
                    'question': qCtrl.text.trim(),
                    'answer': aCtrl.text.trim(),
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                  await deckRef.update({'cardCount': FieldValue.increment(1)});
                  await XpService.award(_uid, XpEvent.createFlashcard);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadCards(_deckId!, _deckName ?? '');
                  await XpService.award(_uid, XpEvent.createFlashcard);

                  // Badge awards
                  await _tryAwardBadge('flashcard_10');
                  final total = _cards.length + 1;
                  if (total >= 50) await _tryAwardBadge('flashcard_50');
                },
                child: Text(isAr ? 'إضافة البطاقة' : 'Add Card',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ])),
        ),
      ),
    );
  }

  // ── Delete single card ─────────────────────────────────────────────────────
  Future<void> _deleteCard(String cardId) async {
    final isAr = _isAr;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isAr ? 'حذف البطاقة؟' : 'Delete Card?'),
        content: Text(isAr ? 'لن تتمكن من استرجاعها' : 'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || _deckId == null) return;
    final deckRef = FirebaseFirestore.instance
        .collection('flashcard_decks').doc(_deckId);
    await deckRef.collection('cards').doc(cardId).delete();
    await deckRef.update({'cardCount': FieldValue.increment(-1)});
    _loadCards(_deckId!, _deckName ?? '');
  }

  // ── Delete whole deck ──────────────────────────────────────────────────────
  Future<void> _deleteDeck(String deckId, String deckName) async {
    final isAr = _isAr;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isAr ? 'حذف المجموعة؟' : 'Delete Deck?'),
        content: Text(isAr
            ? 'سيتم حذف "$deckName" وكل بطاقاتها'
            : 'This will delete "$deckName" and all its cards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deckRef = FirebaseFirestore.instance
        .collection('flashcard_decks').doc(deckId);
    // delete all cards first
    final cards = await deckRef.collection('cards').get();
    for (final c in cards.docs) {
      await c.reference.delete();
    }
    await deckRef.delete();
    _loadDecks();
  }

  Future<void> _tryAwardBadge(String badgeId) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'earnedBadges': FieldValue.arrayUnion([badgeId]),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(
        title: Text(_deckId == null
            ? (isAr ? 'الفلاش كارد' : 'Flashcards')
            : (_deckName ?? (isAr ? 'البطاقات' : 'Cards'))),
        actions: [
          if (_deckId != null)
            IconButton(
              icon: const Icon(Icons.add_card_rounded),
              onPressed: _addCard,
              tooltip: isAr ? 'إضافة بطاقة' : 'Add card',
            ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: _createDeck,
            tooltip: isAr ? 'مجموعة جديدة' : 'New deck',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deckId == null
              ? _DeckList(
                  decks: _decks, isAr: isAr,
                  onSelect: (id, name) => _loadCards(id, name),
                  onCreate: _createDeck,
                  onDelete: _deleteDeck,
                )
              : _cards.isEmpty
                  ? _EmptyCards(isAr: isAr, onAdd: _addCard)
                  : _CardStudy(
                      cards: _cards,
                      currentIndex: _currentIndex,
                      showAnswer: _showAnswer,
                      isAr: isAr,
                      onFlip: () => setState(() => _showAnswer = !_showAnswer),
                      onNext: () => setState(() {
                        _showAnswer = false;
                        _currentIndex = (_currentIndex + 1) % _cards.length;
                      }),
                      onPrev: () => setState(() {
                        _showAnswer = false;
                        _currentIndex = (_currentIndex - 1 + _cards.length) % _cards.length;
                      }),
                      onBack: () => setState(() { _deckId = null; _cards = []; _deckName = null; }),
                      onDeleteCard: _deleteCard,
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Deck list
// ─────────────────────────────────────────────────────────────────────────────
class _DeckList extends StatelessWidget {
  final List<Map<String, dynamic>> decks;
  final bool isAr;
  final Function(String id, String name) onSelect;
  final VoidCallback onCreate;
  final Future<void> Function(String id, String name) onDelete;
  const _DeckList({required this.decks, required this.isAr,
      required this.onSelect, required this.onCreate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) {
      return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🃏', style: TextStyle(fontSize: 60)),
      const SizedBox(height: 16),
      Text(isAr ? 'لا توجد مجموعات بعد' : 'No decks yet',
          style: TextStyle(color: Colors.grey[500], fontSize: 16)),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: Text(isAr ? 'إنشاء مجموعة' : 'Create Deck'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
    ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: decks.length,
      itemBuilder: (_, i) {
        final deck = decks[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, Color(0xFF7209B7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.style_rounded, color: Colors.white),
            ),
            title: Text(deck['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              isAr ? '${deck['cardCount'] ?? 0} بطاقة'
                   : '${deck['cardCount'] ?? 0} cards',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              // Delete deck button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
                tooltip: isAr ? 'حذف المجموعة' : 'Delete deck',
                onPressed: () =>
                    onDelete(deck['id'], deck['name'] ?? ''),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ]),
            onTap: () => onSelect(deck['id'], deck['name'] ?? ''),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card study view — swipe left or tap 🗑 to delete current card
// ─────────────────────────────────────────────────────────────────────────────
class _CardStudy extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final int currentIndex;
  final bool showAnswer, isAr;
  final VoidCallback onFlip, onNext, onPrev, onBack;
  final Future<void> Function(String cardId) onDeleteCard;
  const _CardStudy({
    required this.cards, required this.currentIndex,
    required this.showAnswer, required this.isAr,
    required this.onFlip, required this.onNext,
    required this.onPrev, required this.onBack,
    required this.onDeleteCard,
  });

  @override
  Widget build(BuildContext context) {
    final card = cards[currentIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(children: [
        // Progress row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(isAr ? 'المجموعات' : 'Decks'),
          ),
          Text('${currentIndex + 1} / ${cards.length}',
            style: const TextStyle(fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor)),
          // Delete current card
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 22),
            tooltip: isAr ? 'حذف البطاقة' : 'Delete card',
            onPressed: () => onDeleteCard(card['id']),
          ),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (currentIndex + 1) / cards.length,
          backgroundColor: Colors.grey.withOpacity(0.2),
          valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          borderRadius: BorderRadius.circular(4), minHeight: 6,
        ),
        const SizedBox(height: 28),

        // Flip card
        GestureDetector(
          onTap: onFlip,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(showAnswer),
              width: double.infinity, height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: showAnswer
                      ? [const Color(0xFF06D6A0), const Color(0xFF04B884)]
                      : [AppTheme.primaryColor, const Color(0xFF7209B7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                  color: (showAnswer
                      ? const Color(0xFF06D6A0) : AppTheme.primaryColor)
                      .withOpacity(0.35),
                  blurRadius: 24, offset: const Offset(0, 10),
                )],
              ),
              child: Stack(children: [
                Positioned(bottom: 12, right: 20,
                  child: Text('${currentIndex + 1}', style: const TextStyle(
                      fontSize: 80, fontWeight: FontWeight.w900,
                      color: Colors.white10))),
                Center(child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        showAnswer
                            ? (isAr ? 'الإجابة' : 'Answer')
                            : (isAr ? 'السؤال' : 'Question'),
                        style: const TextStyle(color: Colors.white70,
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      showAnswer
                          ? (card['answer'] ?? '')
                          : (card['question'] ?? ''),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 20, fontWeight: FontWeight.w700,
                          height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                )),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Text(isAr ? 'اضغط على البطاقة للتقليب' : 'Tap card to flip',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),

        const Spacer(),

        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _NavBtn(icon: Icons.arrow_back_rounded,
              label: isAr ? 'السابق' : 'Prev', onTap: onPrev, outlined: true),
          _NavBtn(icon: Icons.arrow_forward_rounded,
              label: isAr ? 'التالي' : 'Next', onTap: onNext),
        ]),
      ]),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  final bool isAr; final VoidCallback onAdd;
  const _EmptyCards({required this.isAr, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('➕', style: TextStyle(fontSize: 60)),
    const SizedBox(height: 16),
    Text(isAr ? 'المجموعة فارغة' : 'Deck is empty',
        style: TextStyle(color: Colors.grey[500], fontSize: 16)),
    const SizedBox(height: 20),
    ElevatedButton.icon(onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: Text(isAr ? 'إضافة بطاقة' : 'Add Card'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
  ]));
}

class _NavBtn extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap; final bool outlined;
  const _NavBtn({required this.icon, required this.label,
      required this.onTap, this.outlined = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : AppTheme.primaryColor,
        border: outlined
            ? Border.all(color: AppTheme.primaryColor, width: 1.5) : null,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color: outlined ? AppTheme.primaryColor : Colors.white,
            size: 20),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
          color: outlined ? AppTheme.primaryColor : Colors.white,
          fontWeight: FontWeight.w700,
        )),
      ]),
    ),
  );
}