import 'package:flutter/material.dart';

class BottleNavBar extends StatelessWidget {
  const BottleNavBar({super.key, required int selectedIndex, this.onTap})
    : _selectedIndex = selectedIndex;

  final int _selectedIndex;
  final void Function(int)? onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.blue,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.thermostat), label: 'Status'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
      ],
    );
  }
}
