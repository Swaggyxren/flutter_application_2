import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

import 'root_logic.dart';
import 'devices/device_config.dart';

class BatteryConfigScreen extends StatefulWidget {
  const BatteryConfigScreen({super.key});

  @override
  State<BatteryConfigScreen> createState() => _BatteryConfigScreenState();
}

class _BatteryConfigScreenState extends State<BatteryConfigScreen> {
  static const String kBattLowEffectNameKey = "batt_low_effect_name";
  static const String kBattCriticalEffectNameKey = "batt_critical_effect_name";
  static const String kBattFullEffectNameKey = "batt_full_effect_name";

  static const String kBattLowThresholdKey = "batt_low_threshold";
  static const String kBattCriticalThresholdKey = "batt_critical_threshold";
  static const String kBattFullThresholdKey = "batt_full_threshold";

  late final Future<DeviceConfig?> _configFuture;

  String? _lowEffectName;
  String? _criticalEffectName;
  String? _fullEffectName;

  int _lowThreshold = 20;
  int _criticalThreshold = 10;
  int _fullThreshold = 100;

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _configFuture = RootLogic.getConfig();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _lowEffectName = _emptyToNull(sp.getString(kBattLowEffectNameKey));
      _criticalEffectName = _emptyToNull(sp.getString(kBattCriticalEffectNameKey));
      _fullEffectName = _emptyToNull(sp.getString(kBattFullEffectNameKey));

      _lowThreshold = sp.getInt(kBattLowThresholdKey) ?? 20;
      _criticalThreshold = sp.getInt(kBattCriticalThresholdKey) ?? 10;
      _fullThreshold = sp.getInt(kBattFullThresholdKey) ?? 100;

      _lowThreshold = _lowThreshold.clamp(5, 50);
      _criticalThreshold = _criticalThreshold.clamp(1, 30);
      _fullThreshold = _fullThreshold.clamp(90, 100);

      if (_criticalThreshold >= _lowThreshold) {
        _criticalThreshold = (_lowThreshold - 5).clamp(1, _lowThreshold - 1);
      }

      _dirty = false;
    });
  }

  String? _emptyToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();

    await sp.setString(kBattLowEffectNameKey, _lowEffectName ?? "");
    await sp.setString(kBattCriticalEffectNameKey, _criticalEffectName ?? "");
    await sp.setString(kBattFullEffectNameKey, _fullEffectName ?? "");

    await sp.setInt(kBattLowThresholdKey, _lowThreshold);
    await sp.setInt(kBattCriticalThresholdKey, _criticalThreshold);
    await sp.setInt(kBattFullThresholdKey, _fullThreshold);

    if (!mounted) return;
    setState(() => _dirty = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saved battery LED settings"),
        backgroundColor: Color(0xFF1A2942),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF1A2942),
              Color(0xFF0F1D2F),
              Color(0xFF0A1628),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            AppBar(
              centerTitle: false,
              titleSpacing: 0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFFB8C5D6)),
              title: const Text(
                "Battery LED",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFD4DCE6),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<DeviceConfig?>(
        future: _configFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5B9FED)),
            );
          }
          final cfg = snap.data;
          if (cfg == null) {
            return const Center(
              child: Text(
                "Device not supported",
                style: TextStyle(color: Color(0xFF8899AA)),
              ),
            );
          }

          final effectNames = cfg.ledEffects.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Thresholds",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4DCE6),
                ),
              ),
              const SizedBox(height: 10),

              _buildThresholdTile(
                title: "Low battery threshold",
                value: _lowThreshold,
                min: 5,
                max: 50,
                onChanged: (v) {
                  setState(() {
                    _lowThreshold = v;
                    if (_criticalThreshold >= _lowThreshold) {
                      _criticalThreshold = (_lowThreshold - 5).clamp(1, _lowThreshold - 1);
                    }
                    _dirty = true;
                  });
                },
              ),

              const SizedBox(height: 10),

              _buildThresholdTile(
                title: "Critical battery threshold",
                value: _criticalThreshold,
                min: 1,
                max: 30,
                onChanged: (v) {
                  setState(() {
                    _criticalThreshold = v;
                    if (_criticalThreshold >= _lowThreshold) {
                      _lowThreshold = (_criticalThreshold + 5).clamp(_criticalThreshold + 1, 50);
                    }
                    _dirty = true;
                  });
                },
              ),

              const SizedBox(height: 10),

              _buildThresholdTile(
                title: "Full battery threshold",
                value: _fullThreshold,
                min: 90,
                max: 100,
                onChanged: (v) {
                  setState(() {
                    _fullThreshold = v;
                    _dirty = true;
                  });
                },
              ),

              const SizedBox(height: 24),
              const Text(
                "Effects",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4DCE6),
                ),
              ),
              const SizedBox(height: 10),

              _buildEffectDropdown(
                title: "Low battery effect",
                value: _lowEffectName,
                items: effectNames,
                onChanged: (v) {
                  setState(() {
                    _lowEffectName = v;
                    _dirty = true;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildEffectDropdown(
                title: "Critical battery effect",
                value: _criticalEffectName,
                items: effectNames,
                onChanged: (v) {
                  setState(() {
                    _criticalEffectName = v;
                    _dirty = true;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildEffectDropdown(
                title: "Full battery effect",
                value: _fullEffectName,
                items: effectNames,
                onChanged: (v) {
                  setState(() {
                    _fullEffectName = v;
                    _dirty = true;
                  });
                },
              ),

              const SizedBox(height: 14),
              const Text(
                "Tip: set an effect to None to disable LEDs for that level.\n"
                "Full triggers when charging and level >= your Full threshold.",
                style: TextStyle(
                  color: Color(0xFF8899AA),
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: const Color(0xFF5B9FED),
              icon: const Icon(Icons.save),
              label: const Text("Save"),
            )
          : null,
    );
  }

  Widget _buildEffectDropdown({
    required String title,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2942).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD4DCE6),
                  ),
                ),
              ),
              DropdownButton<String>(
                value: value,
                hint: const Text(
                  "None",
                  style: TextStyle(color: Color(0xFF8899AA)),
                ),
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1A2942),
                style: const TextStyle(color: Color(0xFFD4DCE6)),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text("None"),
                  ),
                  ...items.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  )),
                ],
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdTile({
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2942).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD4DCE6),
                  ),
                ),
              ),
              Text(
                "$value%",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4DCE6),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.remove, color: Color(0xFF8899AA)),
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF8899AA)),
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}