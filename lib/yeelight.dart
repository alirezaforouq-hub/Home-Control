import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Talks to a Yeelight bulb over the LAN (TCP port 55443).
/// "LAN Control" must be enabled in the Yeelight app.
class Yeelight {
  Yeelight(this.ip);

  final String ip;
  Socket? _socket;
  int _id = 0;
  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pending;
  List<dynamic>? _pendingCmd;

  Future<void> _ensureConnected() async {
    if (_socket != null) return;
    final s = await Socket.connect(ip, 55443,
        timeout: const Duration(seconds: 3));
    s.listen((_) {}, onDone: () => _socket = null, onError: (_) => _socket = null);
    _socket = s;
  }

  Future<void> send(String method, List<dynamic> params) async {
    try {
      await _ensureConnected();
      final msg = jsonEncode({'id': ++_id, 'method': method, 'params': params});
      _socket!.write('$msg\r\n');
    } catch (_) {
      _socket?.destroy();
      _socket = null;
      rethrow;
    }
  }

  /// The bulb allows ~60 commands per minute, so live slider/wheel
  /// updates are throttled to one per second (the last one always goes out).
  void sendThrottled(String method, List<dynamic> params) {
    _pendingCmd = [method, params];
    final wait = const Duration(milliseconds: 1000) -
        DateTime.now().difference(_lastSend);
    if (wait <= Duration.zero) {
      _flush();
    } else {
      _pending ??= Timer(wait, _flush);
    }
  }

  void _flush() {
    _pending = null;
    final c = _pendingCmd;
    if (c == null) return;
    _pendingCmd = null;
    _lastSend = DateTime.now();
    send(c[0] as String, c[1] as List<dynamic>).catchError((_) {});
  }

  Future<void> setPower(bool on) =>
      send('set_power', [on ? 'on' : 'off', 'smooth', 300]);

  void setBrightness(int percent) =>
      sendThrottled('set_bright', [percent, 'smooth', 300]);

  void setRgb(int rgb) => sendThrottled('set_rgb', [rgb, 'smooth', 300]);

  Future<void> setColorTemp(int kelvin) =>
      send('set_ct_abx', [kelvin.clamp(1700, 6500), 'smooth', 300]);

  void dispose() {
    _pending?.cancel();
    _socket?.destroy();
  }
}
