import 'package:flutter/material.dart';
import 'root_logic.dart';
import 'devices/device_config.dart';

class BatteryConfigScreen extends StatefulWidget {
  const BatteryConfigScreen({super.key});
  @override
  State<BatteryConfigScreen> createState() => _BatteryConfigScreenState();
}

class _BatteryConfigScreenState extends State<BatteryConfigScreen> {
  double _lowBatteryThreshold = 20.0;
  bool _isFullEnabled = true;
  bool _isLowEnabled = false;
  String? _selectedFullPattern;
  String? _selectedLowPattern;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Battery Configuration", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      // FIX 1: Changed <DeviceConfig> to <DeviceConfig?> to match backend return type
      body: FutureBuilder<DeviceConfig?>(
        future: RootLogic.getConfig(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // FIX 2: Handle null data for unsupported devices
          final config = snapshot.data;
          if (config == null) {
            return const Center(child: Text("LED configuration not found for this device"));
          }

          final effects = config.ledEffects.keys.toList();
          
          // Set initial dropdown values safely
          _selectedFullPattern ??= effects.isNotEmpty ? effects.first : null;
          _selectedLowPattern ??= effects.isNotEmpty ? effects.first : null;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader("Battery Full Settings", Icons.battery_full),
              SwitchListTile(
                title: const Text("Enable Full LED"),
                subtitle: const Text("Trigger LED when charge reaches 100%"),
                value: _isFullEnabled,
                onChanged: (val) => setState(() => _isFullEnabled = val),
              ),
              if (_isFullEnabled)
                _buildDropdown("Select Full Pattern", effects, _selectedFullPattern, (val) {
                  setState(() => _selectedFullPattern = val);
                }),

              const Divider(height: 40),

              _buildSectionHeader("Low Battery Trigger", Icons.battery_alert),
              SwitchListTile(
                title: const Text("Enable Trigger LED"),
                subtitle: const Text("Trigger LED when battery drops below threshold"),
                value: _isLowEnabled,
                onChanged: (val) => setState(() => _isLowEnabled = val),
              ),
              if (_isLowEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Trigger at ${_lowBatteryThreshold.round()}%", 
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                      Slider(
                        value: _lowBatteryThreshold,
                        activeColor: Colors.blueAccent,
                        min: 1, max: 100,
                        onChanged: (val) => setState(() => _lowBatteryThreshold = val),
                      ),
                    ],
                  ),
                ),
                _buildDropdown("Select Trigger Pattern", effects, _selectedLowPattern, (val) {
                  setState(() => _selectedLowPattern = val);
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? current, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label, 
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // FIX 3: Using 'value' as per standard Flutter, but if your IDE 
        // specifically requested 'initialValue', keep that.
        initialValue: current,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}