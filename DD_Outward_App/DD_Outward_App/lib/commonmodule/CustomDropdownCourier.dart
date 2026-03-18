import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import '../pages/auth/warehouseVo.dart';
import '../pages/order/CourierVO.dart';

class CustomDropdownCourier extends StatefulWidget {
  final List<Courier> items;
  final String hint;
  final Function(String) onSelected;
  final TextEditingController textEditingController;
  final FormFieldValidator<String>? validator;
  final String? defaultValue; // Add this line

  CustomDropdownCourier({
    required this.items,
    required this.hint,
    required this.onSelected,
    required this.textEditingController,
    this.validator,
    this.defaultValue, // Add this line
  });

  @override
  _CustomDropdownCourierState createState() => _CustomDropdownCourierState();
}

class _CustomDropdownCourierState extends State<CustomDropdownCourier> {
  String? _selectedValue;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Set the default value and ID if provided
    if (widget.defaultValue != null) {
      _selectedValue = widget.defaultValue;
      for (var item in widget.items) {
        if (_selectedValue == item.name) {
          _selectedId = item.id.toString();
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 2),
      child: FormField<String>(
        initialValue: _selectedValue, // Set initial value
        validator: (value) {
          // Trigger the custom validator if provided
          if (widget.validator != null) {
            return widget.validator!(value ?? '');
          }
          if (value == null || value.isEmpty) {
            return 'Please select a ${widget.hint}';
          }
          return null;
        },
        builder: (FormFieldState<String> state) {
          return InputDecorator(
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              labelText: widget.hint,
              labelStyle: TextStyle(height: 1, color: Colors.black, fontSize: 14,fontWeight: FontWeight.w400),
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              errorText: state.errorText,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                hint: Text(
                  _selectedValue == null ? widget.hint : '',
                  style: TextStyle(height: 1, color: Colors.black, fontSize: 14,fontWeight: FontWeight.w400),
                ),
                /*icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black45,
                  size: 30,
                ),*/
                items: widget.items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item.name,
                    child: Text(
                      item.name!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
                value: _selectedValue,
                onChanged: (value) {
                  setState(() {
                    _selectedValue = value as String?;
                    for (var item in widget.items) {
                      if (value == item.name) {
                        _selectedId = item.id.toString();
                        break;
                      }
                    }
                    state.didChange(_selectedValue);
                    widget.onSelected(_selectedId!);
                  });
                },
                /*buttonHeight: 50,
                dropdownDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white,
                  // Add bottom padding here
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                dropdownPadding: const EdgeInsets.only(bottom: 100),
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
                  return (item.value.toString().toLowerCase().contains(searchValue));
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
