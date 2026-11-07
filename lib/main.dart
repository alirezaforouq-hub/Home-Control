import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'yeelight.dart';

void main() => runApp(const HomeControlApp());

const bg = Color(0xFF0E0D1A);
const panel = Color(0xFF1A1830);
const panel2 = Color(0xFF25223F);
const mute = Color(0xFF9B97BD);

class HomeControlApp extends StatelessWidget {
  const HomeControlApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Home Control',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: bg,
          textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  Yeelight? bulb;
  String? ip;

  bool on = true;
  double bright = 80;
  Color color = const Color(0xFFFF9A3C);
  Offset knob = const Offset(0.62, 0.30); // 0..1 inside wheel

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('bulb_ip');
    if (saved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askIp());
    } else {
      _setIp(saved);
    }
  }

  void _setIp(String v) {
    bulb?.dispose();
    setState(() {
      ip = v;
      bulb = Yeelight(v);
    });
  }

  Future<void> _askIp() async {
    final c = TextEditingController(text: ip ?? '192.168.1.');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Bulb IP address'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '192.168.1.50'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString('bulb_ip', v);
      _setIp(v);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(m),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating));

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      _toast('Cannot reach the bulb. Check IP and LAN Control.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: -120, left: -120, right: -120, height: 420,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                  colors: [Color(0x669096A8), Colors.transparent]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tab == 0 ? 'Living Room' : 'TV Remote',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(ip == null ? 'Set bulb IP' : 'Bulb: $ip',
                        style: const TextStyle(color: mute, fontSize: 13)),
                  ]),
                ),
                IconButton(onPressed: _askIp, icon: const Icon(Icons.settings_outlined)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: tab == 0 ? _lampCard() : _tvPlaceholder(),
              ),
            ),
            _nav(),
          ]),
        ),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  Widget _lampCard() {
    return _card(Column(children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yeelight Color Bulb',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text(on ? 'On, ${bright.round()}%' : 'Off',
                style: const TextStyle(color: mute, fontSize: 12)),
          ]),
        ),
        Switch(
          value: on,
          activeColor: Colors.white,
          activeTrackColor: color,
          onChanged: (v) {
            setState(() => on = v);
            _run(() => bulb!.setPower(v));
          },
        ),
      ]),
      const SizedBox(height: 16),
      Icon(Icons.lightbulb,
          size: 90,
          color: on ? color : const Color(0xFF3A3758),
          shadows: on ? [Shadow(color: color, blurRadius: 30)] : null),
      const SizedBox(height: 12),
      _wheel(),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Brightness', style: TextStyle(color: mute, fontSize: 13)),
        Text('${bright.round()}%', style: const TextStyle(color: mute, fontSize: 13)),
      ]),
      Slider(
        value: bright, min: 1, max: 100,
        activeColor: Colors.white, inactiveColor: panel2,
        onChanged: (v) {
          setState(() => bright = v);
          bulb?.setBrightness(v.round());
        },
        onChangeEnd: (v) => bulb?.setBrightness(v.round()),
      ),
      Row(children: [
        _chip('Warm', const Color(0xFFFFB45E), 2700),
        const SizedBox(width: 8),
        _chip('Neutral', const Color(0xFFFFF1DC), 4000),
        const SizedBox(width: 8),
        _chip('Cool', const Color(0xFFCFE4FF), 6000),
      ]),
    ]));
  }

  Widget _chip(String label, Color c, int kelvin) => Expanded(
        child: TextButton(
          style: TextButton.styleFrom(
              backgroundColor: panel2,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () {
            setState(() {
              color = c;
              on = true;
              knob = const Offset(0.5, 0.5);
            });
            _run(() async {
              await bulb!.setPower(true);
              await bulb!.setColorTemp(kelvin);
            });
          },
          child: Text(label),
        ),
      );

  Widget _wheel() {
    const size = 200.0;
    void pick(Offset p) {
      final c = const Offset(size / 2, size / 2);
      final d = p - c;
      final r = size / 2;
      final dist = math.min(d.distance, r);
      final a = math.atan2(d.dy, d.dx);
      final hue = (a * 180 / math.pi + 90 + 360) % 360;
      final sat = math.max(0.15, math.min(1.0, dist / (r * 0.65)));
      final col = HSVColor.fromAHSV(1, hue, sat, 1).toColor();
      setState(() {
        color = col;
        on = true;
        knob = Offset((r + math.cos(a) * dist) / size, (r + math.sin(a) * dist) / size);
      });
      bulb?.setRgb(col.value & 0xFFFFFF);
    }

    return GestureDetector(
      onPanDown: (d) => pick(d.localPosition),
      onPanUpdate: (d) => pick(d.localPosition),
      child: SizedBox(
        width: size, height: size,
        child: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(-math.pi / 2),
                colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan,
                  Colors.blue, Color(0xFFFF00FF), Colors.red],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  stops: [0, 0.65], colors: [Colors.white, Color(0x00FFFFFF)]),
            ),
          ),
          Positioned(
            left: knob.dx * size - 13, top: knob.dy * size - 13,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tvPlaceholder() => _card(const Column(children: [
        Icon(Icons.tv, size: 48, color: mute),
        SizedBox(height: 12),
        Text('TV remote comes in the next step',
            style: TextStyle(color: mute)),
      ]));

  Widget _nav() => Container(
        color: panel,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          _tab('Bulb', 0),
          const SizedBox(width: 6),
          _tab('TV Box', 1),
        ]),
      );

  Widget _tab(String label, int i) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: tab == i ? panel2 : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    color: tab == i ? Colors.white : mute,
                    fontWeight: tab == i ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
      );

  @override
  void dispose() {
    bulb?.dispose();
    super.dispose();
  }
}
