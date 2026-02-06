import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'led_automator.dart';
import 'root_logic.dart';
import 'devices/device_config.dart';

class BatteryListener {
  static final Battery _battery = Battery();

  // Same keys as BatteryConfigScreen
  static const String kBattLowEffectNameKey = "batt_low_effect_name";
  static const String kBattCriticalEffectNameKey = "batt_critical_effect_name";
  static const String kBattFullEffectNameKey = "batt_full_effect_name";

  static const String kBattLowThresholdKey = "batt_low_threshold";
  static const String kBattCriticalThresholdKey = "batt_critical_threshold";
  static const String kBattFullThresholdKey = "batt_full_threshold";

  // spam control: only fire when entering a zone
  static bool _inLow = false;
  static bool _inCritical = false;
  static bool _inFull = false;

  // Helps avoid “bouncing” around thresholds
  static const int _hysteresis = 2;

  static void listen() {
    _battery.onBatteryStateChanged.listen((state) async {
      try {
        final level = await _battery.batteryLevel;
        await _handleBattery(level: level, state: state);
      } catch (_) {}
    });
  }

  static Future<void> _handleBattery({
    required int level,
    required BatteryState state,
  }) async {
    // If your global master is off, do nothing
    if (!RootLogic.masterEnabled) return;

    final sp = await SharedPreferences.getInstance();
    final cfg = await RootLogic.getConfig();
    if (cfg == null) return;

    final lowTh = (sp.getInt(kBattLowThresholdKey) ?? 20).clamp(5, 50);
    final critTh = (sp.getInt(kBattCriticalThresholdKey) ?? 10).clamp(1, 30);
    final fullTh = (sp.getInt(kBattFullThresholdKey) ?? 100).clamp(90, 100);

    final lowName = _emptyToNull(sp.getString(kBattLowEffectNameKey));
    final critName = _emptyToNull(sp.getString(kBattCriticalEffectNameKey));
    final fullName = _emptyToNull(sp.getString(kBattFullEffectNameKey));

    // Determine zones (with hysteresis)
    final nowCritical = level <= critTh;
    final nowLow = level <= lowTh && !nowCritical;

    // Full: only when charging (or full state) and level >= threshold
    final charging = state == BatteryState.charging || state == BatteryState.full;
    final nowFull = charging && level >= fullTh;

    // Exit rules (hysteresis):
    if (_inCritical && level >= (critTh + _hysteresis)) _inCritical = false;
    if (_inLow && level >= (lowTh + _hysteresis)) _inLow = false;
    if (_inFull && (!charging || level <= (fullTh - _hysteresis))) _inFull = false;

    // Enter rules (fire once on entry):
    if (nowCritical && !_inCritical) {
      _inCritical = true;
      _inLow = true; // critical implies low, keep it “entered” too
      await _playByName(cfg, critName);
      return;
    }

    if (nowLow && !_inLow) {
      _inLow = true;
      await _playByName(cfg, lowName);
      return;
    }

    if (nowFull && !_inFull) {
      _inFull = true;
      await _playByName(cfg, fullName);
      return;
    }
  }

  static String? _emptyToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static Future<void> _playByName(DeviceConfig cfg, String? effectName) async {
    if (effectName == null) return;
    final hex = cfg.ledEffects[effectName];
    if (hex == null || hex.trim().isEmpty) return;

    LedAutomator.playEffect(
      hex: hex,
      priority: LedPriority.battery,
    );
  }
}
