import 'package:flutter/material.dart';

class GroupFilterBar extends StatelessWidget {
  final List<String> groups;
  final String? selectedGroup;
  final String allLabel;
  final ValueChanged<String?> onSelected;

  const GroupFilterBar({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.allLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(allLabel),
              selected: selectedGroup == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...groups.map((g) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(g),
                  selected: selectedGroup == g,
                  onSelected: (_) => onSelected(g),
                ),
              )),
        ],
      ),
    );
  }
}
