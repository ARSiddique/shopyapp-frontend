import 'package:flutter/material.dart';

class SearchAndFilterBar extends StatelessWidget {
  final Function(String) onSearchChanged;
  final List<String> filterOptions;
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const SearchAndFilterBar({
    super.key,
    required this.onSearchChanged,
    required this.filterOptions,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedFilter,
          onChanged: (value) {
            if (value != null) {
              onFilterChanged(value);
            }
          },
          items: filterOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(),
          decoration: const InputDecoration(
            labelText: "Filter by",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
