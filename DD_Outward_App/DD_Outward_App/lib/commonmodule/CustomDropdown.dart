import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import 'CommonDropDownVO.dart';

class CustomDropdown extends StatefulWidget {
  final List<Commons> items;
  final String hint;
  final Function(Commons) onSelected; // Pass the entire Commons object
  final TextEditingController textEditingController;
  final FormFieldValidator<String>? validator;
  final String? defaultValue;
  final Widget? prefixIcon;
  final String? selectedCityId; // Added for initial value logic

  CustomDropdown({
    required this.items,
    required this.hint,
    required this.onSelected,
    required this.textEditingController,
    this.validator,
    this.defaultValue,
    this.prefixIcon,
    this.selectedCityId,
  });

  @override
  _CustomDropdownState createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  String? _selectedValue;
  Commons? _selectedItem;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCityId != null) {
      // Set the initial value based on selectedCityId
      _selectedItem = widget.items.firstWhere(
            (item) => item.id == widget.selectedCityId,
        orElse: () => Commons(id: '', label: ''), // Provide a default Commons object
      );
      _selectedValue = _selectedItem?.label;
    } else if (widget.defaultValue != null) {
      // Fallback to default value logic
      _selectedValue = widget.defaultValue;
      _selectedItem = widget.items.firstWhere(
            (item) => item.label == _selectedValue,
        orElse: () => widget.items.first,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 2),
      child: FormField<String>(
        initialValue: _selectedValue,
        validator: widget.validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        builder: (FormFieldState<String> state) {
          return InputDecorator(
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              labelText: widget.hint,
              labelStyle: const TextStyle(
                height: 1,
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              hintStyle: const TextStyle(
                height: 1,
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.black, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
              errorText: state.errorText,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                padding: const EdgeInsets.only(left: 13, right: 0),
                child: widget.prefixIcon,
              )
                  : null,
              prefixIconConstraints: widget.prefixIcon != null
                  ? const BoxConstraints(minWidth: 25, minHeight: 25)
                  : null,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                hint: Text(
                  _selectedValue == null ? widget.hint : '',
                  style: const TextStyle(
                    height: 1,
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                items: widget.items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item.id, // Ensure `id` is unique
                    child: Text(
                      item.label ?? '',
                      style: const TextStyle(
                        height: 1,
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
                value: widget.items.any((item) => item.id == _selectedItem?.id)
                    ? _selectedItem?.id
                    : null, // Ensure the value matches an item
                onChanged: (value) {
                  setState(() {
                    _selectedItem = widget.items.firstWhere(
                          (item) => item.id == value,
                      orElse: () => widget.items.first,
                    );
                    _selectedValue = _selectedItem?.label;
                    state.didChange(_selectedValue);
                    widget.onSelected(_selectedItem!); // Pass the entire object
                  });
                },
               /* buttonHeight: 50,
                dropdownMaxHeight: 500, // Set maximum height for the dropdown
                dropdownDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                dropdownPadding: const EdgeInsets.only(bottom: 16), // Add bottom padding
                dropdownScrollPadding: const EdgeInsets.only(bottom: 16), // Extra scrollable space after the last item
                searchController: widget.textEditingController,
                searchInnerWidget: Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextFormField(
                    controller: widget.textEditingController,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      hintText: 'Search...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                searchMatchFn: (item, searchValue) {
                  return (widget.items
                      .firstWhere((e) => e.id == item.value)
                      .label.toString()
                      .toLowerCase()
                      .contains(searchValue.toLowerCase()));
                },*/
                onMenuStateChange: (isOpen) {
                  if (!isOpen) {
                    widget.textEditingController.clear();
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
