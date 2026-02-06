import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'led_menu.dart';
import 'root_logic.dart';
import 'battery_listener.dart';
import 'notif_permission.dart'; // ✅ add this

void main() => runApp(const LedApp());

class LedApp extends StatelessWidget {
  const LedApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const LedEffectsHome(),
    );
  }
}

class LedEffectsHome extends StatefulWidget {
  const LedEffectsHome({super.key});
  @override
  State<LedEffectsHome> createState() => _LedEffectsHomeState();
}

class _LedEffectsHomeState extends State<LedEffectsHome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool isSwitched = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    RootLogic.initializeHardware();
    BatteryListener.listen();

    // ✅ Ask permission after first frame (so dialog won't crash context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotifPermission.ensureEnabled(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  // ✅ When returning from Settings, re-check
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotifPermission.ensureEnabled(context);
    }
  }

  // Helper for Version + Codename
  String _getAndroidDisplayVersion(String rawVersion) {
    if (rawVersion.contains('13')) return "Android 13 (Tiramisu)";
    if (rawVersion.contains('14')) return "Android 14 (Upside Down Cake)";
    if (rawVersion.contains('15')) return "Android 15 (Vanilla Ice Cream)";
    if (rawVersion.contains('16')) return "Android 16 (Baklava)";
    return rawVersion;
  }

  void _navigateToLedLab() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LedMenu(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _toggleMasterPower(bool value) async {
    setState(() => isSwitched = value);
    RootLogic.masterEnabled = value;

    if (!value) {
      await RootLogic.turnOffAll();
    } else {
      await RootLogic.initializeHardware();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "LedSync",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Switch(
            value: isSwitched,
            onChanged: _toggleMasterPower,
            activeThumbColor: Colors.blue,
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            icon: const Icon(Icons.grid_view_rounded, color: Colors.black, size: 30),
            onPressed: _navigateToLedLab,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Current Status:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),

              FutureBuilder<List<dynamic>>(
                future: Future.wait([RootLogic.isRooted(), RootLogic.getConfig()]),
                builder: (context, snapshot) {
                  String msg = "Checking System...";
                  Color color = Colors.grey;
                  if (snapshot.hasData) {
                    bool rooted = snapshot.data![0] ?? false;
                    var config = snapshot.data![1];
                    if (!rooted) {
                      msg = "Root Not Granted";
                      color = Colors.red;
                    } else if (config == null) {
                      msg = "No Led config found";
                      color = Colors.orange;
                    } else {
                      msg = "Ready to use";
                      color = Colors.green;
                    }
                  }
                  return Text(
                    msg,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
                  );
                },
              ),

              const SizedBox(height: 10),

              // 1. DEVICE INFO CARD
              FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  RootLogic.getPhoneInfo(),
                  RootLogic.isRooted(),
                ]).then((res) => {'device': res[0], 'rooted': res[1]}),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return _buildPlaceholderCard("Reading Hardware...");
                  final device = snapshot.data!['device'];
                  final bool isRooted = snapshot.data!['rooted'] ?? false;

                  return Container(
                    height: 190,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device['model'] ?? "Unknown",
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getAndroidDisplayVersion(device['version'] ?? "Android"),
                                style: const TextStyle(fontSize: 15, color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                device['kernel'] ?? "",
                                style: const TextStyle(fontSize: 10, color: Colors.black38),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Text(
                                    "Root Status: ",
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isRooted ? Colors.green : Colors.red,
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isRooted ? Colors.green : Colors.red)
                                                  .withValues(alpha: 0.4),
                                              blurRadius: _pulseController.value * 12,
                                              spreadRadius: 2,
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // THE PREVIEW BOX (Kept exactly as requested)
                        Container(
                          width: 115,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              )
                            ],
                          ),
                          child: ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black, Colors.black, Colors.transparent],
                              stops: [0.0, 0.75, 1.0],
                            ).createShader(rect),
                            blendMode: BlendMode.dstIn,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Transform.scale(
                                scale: 2.0,
                                child: Align(
                                  alignment: const Alignment(0, 1.7),
                                  child: Image.asset('assets/LH8n.png', fit: BoxFit.fitHeight),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),

              GestureDetector(
                onTap: () => AppDrawerPopup.show(context),
                child: Container(
                  height: 55,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.menu, color: Colors.black54, size: 30),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<RootManagerInfo>(
                      future: RootLogic.detectManager(),
                      builder: (context, snapshot) {
                        final info = snapshot.data;
                        return _buildStatusCard(
                          title: "Root Manager",
                          status: info?.name ?? "Detecting...",
                          icon: (info?.iconPath != null && info!.iconPath.isNotEmpty)
                              ? Image.asset(info.iconPath, width: 30)
                              : const Icon(Icons.shield_outlined, size: 30, color: Colors.black54),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatusCard(
                      title: "LED Engine",
                      status: isSwitched ? "READY" : "OFF",
                      icon: Icon(Icons.bolt, color: isSwitched ? Colors.blue : Colors.grey, size: 35),
                    ),
                  ),
                ],
              ),

              // ✅ Push footer to bottom
              const Spacer(),

              // ✅ Footer text row
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: const [
                    Text(
                      "Xi'annnnnn/@kasajin001",
                      style: TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600),
                    ),
                    Spacer(),
                    Text(
                      "Initial Release Expect Bugs",
                      style: TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(String m) => Container(
        height: 190,
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
        child: Center(child: Text(m)),
      );

  Widget _buildStatusCard({required String title, required String status, required Widget icon}) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          icon,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              Text(status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
