// bottom_app_bar_a.dart
import 'package:flutter/material.dart';

class BottomAppBarA extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const BottomAppBarA({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // This container adds the shadow and z-index effect
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Material(
        // Material widget helps with elevation and z-index
        elevation: 4,
        child: BottomAppBar(
          color: Colors.white,
          height: 60, // Reduced height from default (usually 80)
          padding: EdgeInsets.zero, // Remove default padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) {
              return IconButton(
                padding: EdgeInsets.zero, // Remove default padding
                constraints: const BoxConstraints(), // Remove minimum size constraints
                icon: Container(
                  padding: const EdgeInsets.all(12), // Further reduced padding
                  decoration: BoxDecoration(
                    color: selectedIndex == index 
                        ? Colors.grey[300] 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIconForIndex(index),
                    color: selectedIndex == index 
                        ? Colors.black 
                        : Colors.grey,
                    size: 22, // Slightly smaller icon size
                  ),
                ),
                onPressed: () => onItemSelected(index),
              );
            }),
          ),
        ),
      ),
    );
  }

  // Helper function to get icon for each index
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.home;
      case 1: return Icons.dashboard;
      case 2: return Icons.credit_card;
      case 3: return Icons.person;
      default: return Icons.error;
    }
  }
}