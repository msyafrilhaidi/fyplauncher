import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Required for date formatting
import '../user_state_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';
  
  // Timer for the clock
  late Timer _timer;
  String _timeString = '';
  String _dateString = '';

  @override
  void initState() {
    super.initState();
    _timeString = _formatTime(DateTime.now());
    _dateString = _formatDate(DateTime.now());
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = _formatTime(now);
      _dateString = _formatDate(now);
    });
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('EEEE, MMMM d').format(dateTime);
  }

  void _submitPin() async {
    final manager = Provider.of<UserStateManager>(context, listen: false);
    final pin = _pinController.text;

    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Please enter a PIN.');
      return;
    }

    // Simple loading feedback
    setState(() => _errorMessage = ' ');

    bool success = await manager.authenticate(pin);

    if (success) {
      // Authentication successful
    } else {
      // Authentication failed
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The background gradient colors
    const Color gradientStart = Color(0xFF2C3E50); // Deep blue/grey
    const Color gradientEnd = Color(0xFF8E44AD);   // Purple
    // Or use the image colors: Deep Purple to Pink/Red
    // const Color gradientStart = Color(0xFF4A148C);
    // const Color gradientEnd = Color(0xFF880E4F);

    return PopScope(
      canPop: false, // Disable back button
      child: Scaffold(
        // No AppBar for a fullscreen modern look
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFFB71C1C)], // Blue to Red gradient
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Digital Clock
                Text(
                  _timeString,
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _dateString,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
                
                const Spacer(), // Pushes the login card to the bottom/center

                // Glassmorphism Login Card
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15), // Semi-transparent white
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Lock Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54, width: 2),
                          ),
                          child: const Icon(Icons.lock_outline, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Enter Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 5),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            counterText: "", // Hide the char counter
                            prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.white),
                            ),
                          ),
                          onSubmitted: (_) => _submitPin(),
                        ),
                        
                        // Error Message
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Unlock Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _submitPin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple, // Text color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Unlock',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
