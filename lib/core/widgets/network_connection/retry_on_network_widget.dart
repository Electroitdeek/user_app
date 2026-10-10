import 'package:flutter/material.dart';

class RetryOnNetworkWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const RetryOnNetworkWidget({super.key, required this.onRetry, this.message = 'No internet connection'});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your internet connection and try again',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
