import 'package:flutter/material.dart';
import '../services/lg_service.dart';
import '../widgets/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LgService lgService = LgService();

    return Scaffold(
      appBar: AppBar(title: const Text("LG Task 2")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 150,
                width: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              PrimaryButton(
                text: "Send Logo (Left Screen)",
                icon: Icons.image,
                color: Colors.blueGrey,
                onPressed: () async {
                  if (!lgService.isConnected) {
                    _showSnack(context, "Not Connected!", isError: true);
                    return;
                  }
                  _showSnack(context, "Uploading Logo...");
                  await lgService.sendLogo();
                  _showSnack(context, "Logo Sent!");
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: "Send KML 1 (City Polygon)",
                icon: Icons.map,
                color: Colors.blueGrey,
                onPressed: () async {
                  if (!lgService.isConnected) {
                    _showSnack(context, "Not Connected!", isError: true);
                    return;
                  }
                  _showSnack(context, "Flying to Lucknow...");
                  await lgService.sendLucknowKml();
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: "Send KML 2 (US Major cities)",
                icon: Icons.people,
                color: Colors.blueGrey,
                onPressed: () async {
                  if (!lgService.isConnected) {
                    _showSnack(context, "Not Connected!", isError: true);
                    return;
                  }
                  _showSnack(context, "Flying to USA...");
                  await lgService.sendMajorCitiesKml();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : null,
            duration: const Duration(seconds: 1),
          )
      );
    }
  }
}