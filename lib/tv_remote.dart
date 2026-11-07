import 'dart:async';
import 'package:android_remote_pro/android_remote_pro.dart';
import 'package:android_remote_pro/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _panel = Color(0xFF1A1830);
const _panel2 = Color(0xFF25223F);
const _mute = Color(0xFF9B97BD);
const _accent = Color(0xFFFF9A3C);

// Android key codes (android.view.KeyEvent)
const kUp = 19, kDown = 20, kLeft = 21, kRight = 22, kCenter = 23;
const kBack = 4, kHome = 3, kMenu = 82, kPower = 26;
const kVolUp = 24, kVolDown = 25, kMute = 164, kPlayPause = 85;

class TvRemoteView extends StatefulWidget {
  const TvRemoteView({super.key});
  @override
  State<TvRemoteView> createState() => _TvRemoteViewState();
}

class _TvRemoteViewState extends State<TvRemoteView> {
  final _tv = AndroidRemotePro();
  final _found = <String, Device>{};
  final _ipCtl = TextEditingController();
  StreamSubscription? _sub;
  bool scanning = false;
  bool busy = false;
  String? connectedName;
  String? error;

  Future<void> _scan() async {
    setState(() {
      scanning = true;
      error = null;
      _found.clear();
    });
    try {
      _sub ??= _tv.scanStream().listen(_onEvent, onError: (e) {
        if (mounted) setState(() => error = 'Scan error: $e');
      });
      await _tv.startScan();
      Future.delayed(const Duration(seconds: 15), () async {
        try {
          await _tv.stopScan();
        } catch (_) {}
        if (mounted) setState(() => scanning = false);
      });
    } catch (e) {
      setState(() {
        scanning = false;
        error = 'Cannot scan: $e';
      });
    }
  }

  void _onEvent(dynamic raw) {
    try {
      final obj = raw as Map;
      if (obj['event'] == 'found') {
        final d = Device.fromJsonString(obj['device'] as String);
        if (mounted) setState(() => _found[d.name] = d);
      } else if (obj['event'] == 'removed') {
        if (mounted) setState(() => _found.remove(obj['name'] as String));
      }
    } catch (_) {}
  }

  Future<void> _connect(String host, int? port, String name) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await _tv.connect(host, port: port);
      final pin = await _askPin();
      if (pin != null && pin.isNotEmpty) {
        await _tv.sendCode(pin);
      }
      if (mounted) setState(() => connectedName = name);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not connect: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _askPin() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Pairing code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Type the code shown on your TV screen. '
              'Leave empty if no code appears.',
              style: TextStyle(color: _mute, fontSize: 13)),
          TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'e.g. 1A2B3C')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  Future<void> _key(int code) async {
    HapticFeedback.selectionClick();
    try {
      await _tv.sendKey(code);
    } catch (e) {
      if (mounted) setState(() => error = 'Command failed: $e');
    }
  }

  Future<void> _open(String url) async {
    try {
      await _tv.runApp(url);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not open app: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ipCtl.dispose();
    super.dispose();
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration:
            BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (connectedName == null) _connectCard() else ..._remote(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(error!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
        ),
    ]);
  }

  Widget _connectCard() {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Connect to your TV box',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 4),
      const Text('Phone and TV box must be on the same Wi-Fi.',
          style: TextStyle(color: _mute, fontSize: 12)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: const Color(0xFF1A1020),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: scanning || busy ? null : _scan,
          child: Text(scanning ? 'Scanning...' : 'Scan for TV boxes'),
        ),
      ),
      for (final d in _found.values)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tv),
          title: Text(d.name),
          subtitle: Text('${d.host}:${d.port}',
              style: const TextStyle(color: _mute, fontSize: 12)),
          trailing: busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: () => _connect(d.host, d.port, d.name),
                  child: const Text('Connect')),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ipCtl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                hintText: 'Or enter TV IP, e.g. 192.168.1.60'),
          ),
        ),
        TextButton(
          onPressed: busy || _ipCtl.text.trim().isEmpty
              ? null
              : () => _connect(_ipCtl.text.trim(), null, 'TV Box'),
          child: const Text('Connect'),
        ),
      ]),
    ]));
  }

  List<Widget> _remote() => [
        _card(Column(children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(connectedName!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Row(children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
                  SizedBox(width: 6),
                  Text('Connected over Wi-Fi',
                      style: TextStyle(color: _mute, fontSize: 12)),
                ]),
              ]),
            ),
            _key_(const Icon(Icons.power_settings_new), kPower,
                bg: const Color(0xFFC0392B), w: 52),
          ]),
          const SizedBox(height: 18),
          _dpad(),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _key_(const Icon(Icons.undo), kBack),
              _key_(const Icon(Icons.home_outlined), kHome),
              _key_(const Text('Mute'), kMute),
              _key_(const Text('Vol −'), kVolDown),
              _key_(const Text('Menu'), kMenu),
              _key_(const Text('Vol +'), kVolUp),
              _key_(const Icon(Icons.play_arrow), kPlayPause),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => setState(() => connectedName = null),
              child: const Text('Disconnect',
                  style: TextStyle(color: _mute))),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('App shortcuts',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            _app('YouTube', const Color(0xFFFF0000), 'https://www.youtube.com'),
            const SizedBox(width: 10),
            _app('Netflix', const Color(0xFFE50914), 'https://www.netflix.com'),
          ]),
        ])),
      ];

  Widget _app(String name, Color c, String url) => Expanded(
        child: TextButton(
          style: TextButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          onPressed: () => _open(url),
          child: Text(name),
        ),
      );

  Widget _key_(Widget child, int code, {Color bg = _panel2, double? w}) {
    final b = SizedBox(
      width: w,
      height: w == null ? null : 52,
      child: TextButton(
        style: TextButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: () => _key(code),
        child: child,
      ),
    );
    return b;
  }

  Widget _dpad() {
    Widget arrow(IconData i, int code, {double? l, double? t, double? r, double? b}) =>
        Positioned(
          left: l, top: t, right: r, bottom: b,
          child: IconButton(
              iconSize: 30, onPressed: () => _key(code), icon: Icon(i)),
        );
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(children: [
        Container(
            decoration:
                const BoxDecoration(color: _panel2, shape: BoxShape.circle)),
        arrow(Icons.keyboard_arrow_up, kUp, t: 8, l: 80),
        arrow(Icons.keyboard_arrow_down, kDown, b: 8, l: 80),
        arrow(Icons.keyboard_arrow_left, kLeft, l: 8, t: 80),
        arrow(Icons.keyboard_arrow_right, kRight, r: 8, t: 80),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(70),
            child: GestureDetector(
              onTap: () => _key(kCenter),
              child: Container(
                alignment: Alignment.center,
                decoration:
                    const BoxDecoration(color: _accent, shape: BoxShape.circle),
                child: const Text('OK',
                    style: TextStyle(
                        color: Color(0xFF1A1020),
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
