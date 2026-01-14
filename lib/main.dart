import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation/bottom_nav.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const LGTask2App(),
    ),
  );
}

class LGTask2App extends StatelessWidget {
  const LGTask2App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'LG Task 2',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const BottomNav(),
      debugShowCheckedModeBanner: false,
    );
  }
}
