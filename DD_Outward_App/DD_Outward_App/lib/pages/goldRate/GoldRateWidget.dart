import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'GoldRateController.dart';

class GoldRateWidget extends StatelessWidget {
  final GoldRateController goldRateController = Get.put(GoldRateController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Gold Rates in INR'),
      ),
      body: Obx(() {
        if (goldRateController.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        // If data is available, display it
        return ListView.builder(
          itemCount: goldRateController.goldPrices.length,
          itemBuilder: (context, index) {
            String label = goldRateController.goldPrices.keys.elementAt(index);
            double price = goldRateController.goldPrices.values.elementAt(index);
            return ListTile(
              title: Text(label),
              trailing: Text("₹${price.toStringAsFixed(2)}"),
            );
          },
        );
      }),
    );
  }
}