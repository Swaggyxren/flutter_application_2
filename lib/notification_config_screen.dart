import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'root_logic.dart';
import 'devices/device_config.dart';

class NotificationConfigScreen extends StatefulWidget {
  const NotificationConfigScreen({super.key});
  @override
  State<NotificationConfigScreen> createState() => _NotificationConfigScreenState();
}

class _NotificationConfigScreenState extends State<NotificationConfigScreen> {
  static const _kNameMapKey = "notif_name_map";
  static const _kHexMapKey = "notif_hex_map";
  static const _kShowSystemKey = "notif_show_system_apps";

  late final Future<DeviceConfig?> _configFuture;
  Future<List<AppInfo>>? _appsFuture;

  bool _showSystemApps = false;

  Map<String, String> _savedMappings = {};
  Map<String, String> _workingMappings = {};
  bool _dirty = false;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _configFuture = RootLogic.getConfig();
    _initPrefsAndLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initPrefsAndLoad() async {
    final sp = await SharedPreferences.getInstance();

    _showSystemApps = sp.getBool(_kShowSystemKey) ?? false;

    final raw = sp.getString(_kNameMapKey);
    Map<String, String> parsed = {};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
        parsed = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {
        parsed = {};
      }
    }

    _appsFuture = _buildAppsFuture(_showSystemApps);

    if (!mounted) return;
    setState(() {
      _savedMappings = parsed;
      _workingMappings = Map.of(parsed);
      _dirty = false;
    });
  }

  Future<List<AppInfo>> _buildAppsFuture(bool showSystem) {
    // installed_apps uses "excludeSystemApps" rather than "includeSystemApps"
    return InstalledApps.getInstalledApps(
      excludeSystemApps: !showSystem,
      excludeNonLaunchableApps: false, // match your onlyAppsWithLaunchIntent:false
      withIcon: true,
    );
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  Future<void> _toggleSystemApps(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kShowSystemKey, value);

    setState(() {
      _showSystemApps = value;
      _appsFuture = _buildAppsFuture(_showSystemApps);
    });
  }

  Future<void> _openSearchDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        _searchCtrl.text = _searchQuery;
        return AlertDialog(
          title: const Text("Search apps"),
          content: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Name or package…",
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(ctx, ""), child: const Text("Clear")),
            TextButton(onPressed: () => Navigator.pop(ctx, _searchCtrl.text.trim()), child: const Text("Apply")),
          ],
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() => _searchQuery = result);
  }

  Future<void> _save(DeviceConfig config) async {
    final sp = await SharedPreferences.getInstance();

    await sp.setString(_kNameMapKey, jsonEncode(_workingMappings));

    final effects = config.ledEffects; // name -> hex
    final hexMap = <String, String>{};
    for (final e in _workingMappings.entries) {
      final hex = effects[e.value];
      if (hex != null && hex.trim().isNotEmpty) {
        hexMap[e.key] = hex;
      }
    }
    await sp.setString(_kHexMapKey, jsonEncode(hexMap));

    if (!mounted) return;
    setState(() {
      _savedMappings = Map.of(_workingMappings);
      _dirty = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved app LED patterns")),
    );
  }

  Widget _buildLeadingIcon(Uint8List? iconBytes) {
    if (iconBytes == null || iconBytes.isEmpty) {
      return const Icon(Icons.android);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        iconBytes,
        width: 40,
        height: 40,
        errorBuilder: (_, __, ___) => const Icon(Icons.android),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          "App LED Sync",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text("System", style: TextStyle(fontSize: 13)),
              Switch(value: _showSystemApps, onChanged: _toggleSystemApps),
              IconButton(
                tooltip: "Search apps",
                icon: const Icon(Icons.search),
                onPressed: _openSearchDialog,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),

      body: FutureBuilder<DeviceConfig?>(
        future: _configFuture,
        builder: (context, configSnapshot) {
          if (configSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (configSnapshot.hasError) {
            return Center(child: Text("Config error: ${configSnapshot.error}"));
          }

          final config = configSnapshot.data;
          if (config == null) {
            return const Center(child: Text("Device not supported for LED sync"));
          }

          final effects = config.ledEffects;
          final appsFuture = _appsFuture;
          if (appsFuture == null) return const Center(child: CircularProgressIndicator());

          return FutureBuilder<List<AppInfo>>(
            future: appsFuture,
            builder: (context, appSnapshot) {
              if (appSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (appSnapshot.hasError) {
                return Center(child: Text("Apps error: ${appSnapshot.error}"));
              }
              if (!appSnapshot.hasData) {
                return const Center(child: Text("No apps found"));
              }

              final apps = List<AppInfo>.from(appSnapshot.data!);

              // filter by search
              final q = _searchQuery.trim().toLowerCase();
              if (q.isNotEmpty) {
                apps.removeWhere((a) {
                  final name = a.name.toLowerCase();
                  final pkg = a.packageName.toLowerCase();
                  return !(name.contains(q) || pkg.contains(q));
                });
              }

              // mapped apps on top
              apps.sort((a, b) {
                final aHas = _workingMappings.containsKey(a.packageName);
                final bHas = _workingMappings.containsKey(b.packageName);
                if (aHas != bHas) return aHas ? -1 : 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final selected = _workingMappings[app.packageName];
                  final hasPattern = selected != null && selected.trim().isNotEmpty;

                  return Card(
                    elevation: 0,
                    color: hasPattern ? Colors.blue.withOpacity(0.10) : Colors.grey[50],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: _buildLeadingIcon(app.icon),
                      title: Text(
                        app.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: hasPattern ? Colors.blue[700] : Colors.black87,
                        ),
                      ),
                      subtitle: Text(app.packageName, style: const TextStyle(fontSize: 10)),
                      trailing: DropdownButton<String>(
                        value: selected,
                        hint: const Text("None", style: TextStyle(fontSize: 12)),
                        underline: const SizedBox(),
                        items: effects.keys
                            .map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name, style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            if (val == null) {
                              _workingMappings.remove(app.packageName);
                            } else {
                              _workingMappings[app.packageName] = val;
                            }
                            _dirty = !_mapsEqual(_workingMappings, _savedMappings);
                          });
                        },
                      ),
                      onLongPress: () {
                        setState(() {
                          _workingMappings.remove(app.packageName);
                          _dirty = !_mapsEqual(_workingMappings, _savedMappings);
                        });
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FutureBuilder<DeviceConfig?>(
        future: _configFuture,
        builder: (context, snap) {
          final cfg = snap.data;
          if (!_dirty || cfg == null) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => _save(cfg),
            icon: const Icon(Icons.save),
            label: const Text("Save"),
          );
        },
      ),
    );
  }
}
