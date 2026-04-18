import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAqvDHUPuGtZGMephb3dN_31eruuBXnbFE",
      authDomain: "gigscourt2.firebaseapp.com",
      projectId: "gigscourt2",
      storageBucket: "gigscourt2.firebasestorage.app",
      messagingSenderId: "505136313803",
      appId: "1:505136313803:web:2b61e6916efdaf8723324e",
    ),
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://qifzdrkpxzosdturjpex.supabase.co',
    anonKey: 'sb_publishable_QfKJ4jT8u_2HuUKmW-xvbQ_9acJvZw-',
  );
  
  runApp(const GigsCourtApp());
}

class GigsCourtApp extends StatelessWidget {
  const GigsCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigsCourt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFE67E22),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF262626)),
          titleTextStyle: TextStyle(
            color: Color(0xFF262626),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFE67E22),
          unselectedItemColor: Color(0xFF8E8E8E),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE67E22),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE67E22),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        cardColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F0F),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFF5F5F5)),
          titleTextStyle: TextStyle(
            color: Color(0xFFF5F5F5),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F0F),
          selectedItemColor: Color(0xFFE67E22),
          unselectedItemColor: Color(0xFFA8A8A8),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE67E22),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashWrapper(),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreenPlaceholder()),
      );
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
            colors: [Color(0xFFC0392B), Color(0xFFE67E22)],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.3, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Gigs',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'Court',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Placeholder - will be replaced with actual AuthScreen in Phase 2
class AuthScreenPlaceholder extends StatelessWidget {
  const AuthScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GigsCourt')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Auth Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Coming in Phase 2'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Temp navigation to test other screens later
              },
              child: const Text('Skip to Home (Testing)'),
            ),
          ],
        ),
      ),
    );
  }
}
