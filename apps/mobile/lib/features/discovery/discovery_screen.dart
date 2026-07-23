import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _controller = CardSwiperController();
  List<Pet> _pets = [];
  Pet? _active;
  List<DeckCard> _deck = [];
  bool _loading = true;
  String? _error;

  // filters
  double _radius = 25;
  Species? _species;
  PetSex? _sex;
  bool _vaccinatedOnly = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final pets = await Api.myPets();
    final active = pets.where((p) => p.isActive).toList();
    setState(() {
      _pets = pets;
      _active = active.isNotEmpty ? active.first : (pets.isNotEmpty ? pets.first : null);
    });
    await _loadDeck();
  }

  Future<void> _loadDeck() async {
    if (_active == null) {
      setState(() { _loading = false; _deck = []; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final deck = await Api.deck(
        viewerPet: _active!.id,
        radiusKm: _radius,
        species: _species,
        sex: _sex,
        vaccinatedOnly: _vaccinatedOnly,
      );
      setState(() { _deck = deck; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _record(DeckCard card, String direction) async {
    try {
      final res = await Api.swipe(_active!.id, card.petId, direction);
      if (res['ok'] == false && res['error'] == 'daily_like_limit') {
        if (mounted) _showLimit();
        return;
      }
      if (res['matched'] == true && mounted) _showMatch(card);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  bool _onSwipe(int prev, int? curr, CardSwiperDirection dir) {
    if (prev < 0 || prev >= _deck.length) return true;
    final card = _deck[prev];
    if (dir == CardSwiperDirection.right) {
      _record(card, 'like');
    } else if (dir == CardSwiperDirection.left) {
      _record(card, 'pass');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PAWD', style: TextStyle(color: PawdColors.brand, fontSize: 24, fontWeight: FontWeight.w900)),
        actions: [
          if (_pets.length > 1)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _active?.id,
                onChanged: (id) {
                  setState(() => _active = _pets.firstWhere((p) => p.id == id));
                  _loadDeck();
                },
                items: [for (final p in _pets) DropdownMenuItem(value: p.id, child: Text(p.name))],
              ),
            ),
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilters),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PawdColors.brand))
          : _error != null
              ? _errorView()
              : _deck.isEmpty
                  ? _emptyView()
                  : _deckView(),
    );
  }

  Widget _deckView() {
    final shown = min(3, _deck.length);
    return Column(
      children: [
        if (_active != null && _active!.purposes.every((p) => p == PurposeFlag.breeding))
          _notice('${_active!.name} is breeding-only. Add a social purpose to appear in decks.'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CardSwiper(
              controller: _controller,
              cardsCount: _deck.length,
              numberOfCardsDisplayed: shown,
              isLoop: false,
              padding: EdgeInsets.zero,
              allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
              onSwipe: _onSwipe,
              onEnd: () => setState(() => _deck = []),
              cardBuilder: (context, index, px, py) => _PetCard(card: _deck[index], swipeX: px),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundBtn(Icons.close, PawdColors.pass, 60,
                  () => _controller.swipe(CardSwiperDirection.left)),
              const SizedBox(width: 22),
              _roundBtn(Icons.favorite, PawdColors.like, 70,
                  () => _controller.swipe(CardSwiperDirection.right)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundBtn(IconData icon, Color color, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: PawdColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: PawdColors.line),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }

  Widget _notice(String t) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: PawdColors.brandSoft, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(color: PawdColors.brand, fontWeight: FontWeight.w600)),
      );

  Widget _emptyView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🐾', style: TextStyle(fontSize: 46)),
              const SizedBox(height: 8),
              const Text('No more pets nearby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Try widening your distance filter, or check back soon.',
                  textAlign: TextAlign.center, style: TextStyle(color: PawdColors.inkSoft)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadDeck, child: const Text('Refresh')),
            ],
          ),
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('😕', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: PawdColors.inkSoft)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _loadDeck, child: const Text('Retry')),
          ]),
        ),
      );

  void _showMatch(DeckCard card) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉', style: TextStyle(fontSize: 46)),
            const SizedBox(height: 6),
            const Text("It's a match!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('You and ${card.name} liked each other.',
                textAlign: TextAlign.center, style: const TextStyle(color: PawdColors.inkSoft)),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 46,
              backgroundColor: PawdColors.surface2,
              backgroundImage: card.primaryPhoto != null
                  ? CachedNetworkImageProvider(Config.publicUrl('pet-photos', card.primaryPhoto!))
                  : null,
              child: card.primaryPhoto == null
                  ? Text(card.species == Species.dog ? '🐕' : '🐈', style: const TextStyle(fontSize: 34))
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () { Navigator.pop(c); context.go('/matches'); },
              child: const Text('Say hi 👋'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Keep swiping')),
          ]),
        ),
      ),
    );
  }

  void _showLimit() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Daily likes reached'),
        content: const Text("You've used all 25 likes for today. Come back tomorrow for more picks."),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Got it'))],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PawdColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) {
        double radius = _radius;
        Species? species = _species;
        PetSex? sex = _sex;
        bool vacc = _vaccinatedOnly;
        return StatefulBuilder(
          builder: (c, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Distance: ${radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: radius, min: 1, max: 50, activeColor: PawdColors.brand,
                onChanged: (v) => setSheet(() => radius = v),
              ),
              _filterSeg<Species?>('Species', const [null, Species.dog, Species.cat], species,
                  {null: 'Any', Species.dog: 'Dog', Species.cat: 'Cat'}, (v) => setSheet(() => species = v)),
              const SizedBox(height: 12),
              _filterSeg<PetSex?>('Sex', const [null, PetSex.male, PetSex.female], sex,
                  {null: 'Any', PetSex.male: 'Male', PetSex.female: 'Female'}, (v) => setSheet(() => sex = v)),
              const SizedBox(height: 12),
              _filterSeg<bool>('Vaccination', const [false, true], vacc,
                  {false: 'Any', true: 'Vaccinated'}, (v) => setSheet(() => vacc = v)),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  setState(() { _radius = radius; _species = species; _sex = sex; _vaccinatedOnly = vacc; });
                  Navigator.pop(c);
                  _loadDeck();
                },
                child: const Text('Apply filters'),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _filterSeg<T>(String label, List<T> values, T selected, Map<T, String> labels, void Function(T) onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: PawdColors.inkSoft)),
      const SizedBox(height: 6),
      Row(children: [
        for (final v in values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(v),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == selected ? PawdColors.brandSoft : PawdColors.surface,
                  border: Border.all(color: v == selected ? PawdColors.brand : PawdColors.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(labels[v] ?? '',
                    style: TextStyle(
                        color: v == selected ? PawdColors.brand : PawdColors.inkSoft,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (v != values.last) const SizedBox(width: 8),
        ]
      ]),
    ]);
  }
}

class _PetCard extends StatelessWidget {
  final DeckCard card;
  final int swipeX; // -100..100 horizontal swipe percent
  const _PetCard({required this.card, required this.swipeX});

  @override
  Widget build(BuildContext context) {
    final img = card.primaryPhoto != null
        ? Config.publicUrl('pet-photos', card.primaryPhoto!)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: PawdColors.surface2,
          border: Border.all(color: PawdColors.line),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => _emojiBg())
            else
              _emojiBg(),
            // scrim
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
            // LIKE / NOPE stamps
            Positioned(
              top: 24, left: 20,
              child: Opacity(
                opacity: (swipeX / 100).clamp(0.0, 1.0),
                child: _stamp('LIKE', PawdColors.like),
              ),
            ),
            Positioned(
              top: 24, right: 20,
              child: Opacity(
                opacity: (-swipeX / 100).clamp(0.0, 1.0),
                child: _stamp('NOPE', PawdColors.pass),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.ageLabel.isEmpty ? card.name : '${card.name} · ${card.ageLabel}',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${card.breed} · ${card.sex == PetSex.male ? '♂' : '♀'} · ${card.distanceKm} km away',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  if (card.bio != null) ...[
                    const SizedBox(height: 6),
                    Text(card.bio!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in card.purposes.where((p) => p != PurposeFlag.breeding))
                      _tag(purposeLabels[p]!),
                    for (final t in card.temperament.take(2)) _tag(t),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiBg() => Center(
      child: Text(card.species == Species.dog ? '🐕' : '🐈', style: const TextStyle(fontSize: 72)));

  Widget _tag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white30),
        ),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _stamp(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
      );
}
