import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'devices/device_config.dart';
import 'devices/lh8n_config.dart';

class RootManagerInfo {
  final String name;
  final String iconPath;
  RootManagerInfo(this.name, this.iconPath);
}

class RootLogic {
  static DeviceConfig? _currentConfig;
  static bool masterEnabled = true;

  static Future<DeviceConfig?> getConfig() async {
    if (_currentConfig != null) return _currentConfig;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    // Specifically targeting the TECNO LH8n hardware
    if (androidInfo.model.contains("LH8n")) {
      _currentConfig = LH8nConfig();
      return _currentConfig;
    }
    return null;
  }

  static Future<bool> isRooted() async {
    try {
      var result = await Process.run('su', ['-v']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getPhoneInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    var kernel = await _runSu("uname -r");

    String version = androidInfo.version.release;
    return {
      'model': androidInfo.model,
      'version': "Android $version",
      'kernel': kernel.stdout.toString().trim(),
    };
  }

  static Future<RootManagerInfo> detectManager() async {
    if ((await _runSu("ls /data/adb/ksu")).exitCode == 0) {
      return RootManagerInfo("KernelSU Next", "assets/kernelsu_next.png");
    }
    if ((await _runSu("ls /data/adb/apatch")).exitCode == 0) {
      return RootManagerInfo("APatch", "assets/apatch_icon.png");
    }
    var magiskCheck = await _runSu("magisk -v");
    if (magiskCheck.exitCode == 0) {
      return RootManagerInfo("Magisk", "assets/magisk.png");
    }
    return RootManagerInfo("Unknown", "");
  }

  /// Basic init (kept), but better to call ensureLedEnabled() before effects.
  static Future<void> initializeHardware() async {
    await ensureLedEnabled();
  }

  /// ✅ IMPORTANT: Always re-enable the AW chip + open the lightbelt command
  /// so that after Emergency Kill (hwen=0) effects still work.
  static Future<void> ensureLedEnabled() async {
    final cfg = await getConfig();
    if (cfg == null) return;

    // aw_enable() equivalent:
    await _runSu("echo 1 > ${cfg.awPath}/hwen");

    // Some devices use imax + trigger; ignore failures if not present.
    await _runSu("echo c > ${cfg.awPath}/imax || true");
    await _runSu("echo 255 > ${cfg.awPath}/brightness");
    await _runSu("echo none > ${cfg.awPath}/trigger || true");

    // lb_open() equivalent (command_open)
    await _runSu("echo -n '00 00 00 00 00 00' > ${cfg.lbCmd}");
  }

  /// Send hex safely (auto-wake first).
  static Future<void> sendRawHex(String hex) async {
    if (!masterEnabled) return;
    final cfg = await getConfig();
    if (cfg == null) return;

    // 🔧 auto recover if emergency kill previously disabled the chip
    await ensureLedEnabled();

    await _runSu("echo -n '$hex' > ${cfg.lbCmd}");
  }

  /// Turns LED off NOW, but keeps system recoverable by future effects
  /// (because sendRawHex() calls ensureLedEnabled()).
  static Future<void> turnOffAll() async {
    final cfg = await getConfig();
    if (cfg == null) return;

    // lb_close (command_close)
    await _runSu("echo -n '00 01 00 00 00 00' > ${cfg.lbCmd}");

    // aw_off (disable)
    await _runSu("echo 0 > ${cfg.awPath}/brightness");
    await _runSu("echo 0 > ${cfg.awPath}/hwen");
  }

  /// ✅ Emergency Kill that DOES NOT "kill forever":
  /// off immediately, then turns the controller back on so LEDs can work again.
  static Future<void> emergencyKillAndRevive({
    Duration offTime = const Duration(milliseconds: 250),
  }) async {
    await turnOffAll();
    await Future.delayed(offTime);
    await ensureLedEnabled();
  }

  static Future<ProcessResult> _runSu(String cmd) async =>
      await Process.run('su', ['-c', cmd]);
}
