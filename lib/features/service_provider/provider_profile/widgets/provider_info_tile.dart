import 'package:flutter/material.dart';

class ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const ProfileInfoTile({super.key, required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue[50],
        child: Icon(icon, size: 20, color: Colors.blue[700]),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value ?? 'Not provided',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: value != null ? Colors.black87 : Colors.grey[400],
        ),
      ),
      trailing: onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
    );
  }
}
