import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lg_connection_model.dart';
import '../services/lg_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/connection_status.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LgService _lgService = LgService();

  LgConnectionModel _connectionModel = LgConnectionModel();

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _rigsController = TextEditingController();

  bool _isConnected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedModel = await _connectionModel.loadFromPreference();
    setState(() {
      _connectionModel = savedModel;

      _ipController.text = _connectionModel.ip;
      _usernameController.text = _connectionModel.username;
      _passwordController.text = _connectionModel.password;
      _portController.text = _connectionModel.port.toString();
      _rigsController.text = _connectionModel.screens.toString();

      _isConnected = _lgService.isConnected;
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _rigsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConnectionStatus(isConnected: _isConnected),
            const SizedBox(height: 20),

            _field("Username", _usernameController, icon: Icons.person),
            _field("IP Address", _ipController, icon: Icons.network_wifi),
            _field(
              "LG Connection Password",
              _passwordController,
              obscure: true,
              icon: Icons.lock,
            ),
            _field(
              "Port Number",
              _portController,
              isNumber: true,
              icon: Icons.numbers,
            ),
            _field(
              "Number of Rigs",
              _rigsController,
              isNumber: true,
              icon: Icons.computer,
            ),

            const SizedBox(height: 16),

            PrimaryButton(
              text: _isConnected ? "Disconnect" : "Connect to LG",
              icon: _isConnected ? Icons.link_off : Icons.link,
              color: _isConnected ? Colors.red : Colors.blue,
              onPressed: () async {
                if (_isConnected) {
                  _lgService.disconnect();
                  setState(() => _isConnected = false);
                } else {
                  if (_ipController.text.isEmpty ||
                      _usernameController.text.isEmpty ||
                      _passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fill all fields')),
                    );
                    return;
                  }

                  _connectionModel.username = _usernameController.text;
                  _connectionModel.ip = _ipController.text;
                  _connectionModel.port = int.parse(_portController.text);
                  _connectionModel.password = _passwordController.text;
                  _connectionModel.screens = int.parse(_rigsController.text);

                  await _connectionModel.saveToPreference();

                  setState(() => _isLoading = true);

                  _lgService.connectionModel.updateConnection(
                    ip: _connectionModel.ip,
                    port: _connectionModel.port,
                    username: _connectionModel.username,
                    password: _connectionModel.password,
                    screens: _connectionModel.screens,
                  );

                  bool? success = await _lgService.connectToLG();

                  setState(() {
                    _isLoading = false;
                    _isConnected = success ?? false;
                  });

                  if (success == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connected! Flying to India...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _lgService.flyTo(
                      '<LookAt><longitude>78.9629</longitude><latitude>20.5937</latitude><range>5000000</range><tilt>0</tilt><heading>0</heading><altitudeMode>relativeToGround</altitudeMode></LookAt>',
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connection Failed'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),

            if (_isLoading) ...[
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: "Clean Logo",
                    icon: Icons.cleaning_services,
                    color: Colors.orange,
                    onPressed: () async {
                      if (!_isConnected) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleaning Logo...')));
                      await _lgService.cleanLogo();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: "Clean KML",
                    icon: Icons.delete_outline,
                    color: Colors.redAccent,
                    onPressed: () async {
                      if (!_isConnected) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleaning Everything...')));
                      await _lgService.cleanKML();
                    },
                  ),
                ),

              ],
            ),

            const SizedBox(height: 30),
            const Divider(),
            SwitchListTile(
              title: const Text("Dark Mode"),
              value: themeProvider.isDarkMode,
              onChanged: themeProvider.toggleTheme,
            ),
            const Divider(),
            const SizedBox(height: 30),
            const Text(
              "System Controls",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _systemButton(
                  context,
                  label: "Relaunch",
                  icon: Icons.refresh,
                  color: Colors.orange,
                  onTap: () async => await _lgService.relaunchLG(),
                ),
                _systemButton(
                  context,
                  label: "Reboot",
                  icon: Icons.restart_alt,
                  color: Colors.purple,
                  onTap: () async => await _lgService.reboot(),
                ),
                _systemButton(
                  context,
                  label: "Shutdown",
                  icon: Icons.power_settings_new,
                  color: Colors.red,
                  onTap: () async => await _lgService.shutdown(),
                ),
              ],
            ),
            const SizedBox(height: 30,),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool isNumber = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _systemButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Function onTap
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            if (!_isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Not connected to LG!'))
              );
              return;
            }
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('$label Liquid Galaxy?'),
                content: Text('Are you sure you want to $label the rig?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onTap();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Executing $label...'))
                      );
                    },
                    child: Text(label, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
