import 'package:flutter/material.dart';
import 'dart:ui';
import 'root_logic.dart';
import 'devices/device_config.dart';

class LedMenu extends StatefulWidget {
  const LedMenu({super.key});
  @override
  State<LedMenu> createState() => _LedMenuState();
}

class _LedMenuState extends State<LedMenu> {
  final ScrollController _scrollController = ScrollController();
  List<String> logs = [];
  DeviceConfig? config;
  bool isReady = false;

  @override
  void initState() {
    super.initState();
    _initLab();
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() => logs.add("> $msg"));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _initLab() async {
    config = await RootLogic.getConfig();
    if (await RootLogic.isRooted()) {
      await RootLogic.initializeHardware();
      _addLog("Hardware Nodes Initialized.");
      setState(() => isReady = true);
    } else {
      _addLog("Critical: No Root Access.");
    }
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
        child: SafeArea(
          top: false, // Allow drawing behind status bar
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFB8C5D6)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "LED Hardware Lab",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4DCE6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // LOG BOX
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1D2F).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF5B9FED).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, i) => Text(
                        logs[i],
                        style: const TextStyle(
                          color: Color(0xFF5B9FED),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "Injected Effects",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4DCE6),
                ),
              ),
              const SizedBox(height: 15),
              if (isReady && config != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: config!.ledEffects.entries.map((e) => ActionChip(
                        backgroundColor: const Color(0xFF1A2942),
                        avatar: const Icon(
                          Icons.lightbulb,
                          size: 16,
                          color: Color(0xFF5B9FED),
                        ),
                        label: Text(
                          e.key,
                          style: const TextStyle(color: Color(0xFFD4DCE6)),
                        ),
                        onPressed: () {
                          RootLogic.sendRawHex(e.value);
                          _addLog("Injected: ${e.key}");
                        },
                      )).toList(),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    RootLogic.turnOffAll();
                    _addLog("Emergency Stop Sent.");
                  },
                  child: const Text(
                    "EMERGENCY KILL",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}