import 'package:flutter/material.dart';
import '../models/product.dart';

class CategoryFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const CategoryFilter({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ProductCategory.values;

    return SizedBox(
      height: 44,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            // Bouton "Tous"
            final isSelected = selected == null;
            return _Chip(
              label: 'Tous',
              emoji: '🛍️',
              isSelected: isSelected,
              onTap: () => onSelected(null),
            );
          }
          final cat = categories[i - 1];
          final isSelected = selected == cat.label;
          return _Chip(
            label: cat.label,
            emoji: cat.emoji,
            isSelected: isSelected,
            onTap: () => onSelected(isSelected ? null : cat.label),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1976D2)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1976D2)
                : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.3),
                  blurRadius: 6,
                )]
              : [],
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
