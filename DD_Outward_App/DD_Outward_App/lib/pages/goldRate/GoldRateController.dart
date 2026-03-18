import 'dart:async';
import 'dart:convert';
import 'package:deodap/widgets/extensions.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class GoldRateController extends GetxController {
  var isLoading = true.obs;
  var goldPrices = {}.obs;  // Observable map to store the gold prices

  final String apiUrl = "https://www.goldapi.io/api/XAU/INR";  // API URL for INR
  final String apiKey = "goldapi-5e4husm1gavyes-io";  // Replace with your GoldAPI.io key

  Future<void> fetchGoldRate() async {
    //isLoading(true);
    showProgress();
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'x-access-token': apiKey,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update the map with values from the API
        goldPrices.value = {
          "24K (per gram)": data['price_gram_24k'],
          "22K (per gram)": data['price_gram_22k'],
          "21K (per gram)": data['price_gram_21k'],
          "20K (per gram)": data['price_gram_20k'],
          "18K (per gram)": data['price_gram_18k'],
          "16K (per gram)": data['price_gram_16k'],
          "14K (per gram)": data['price_gram_14k'],
          "10K (per gram)": data['price_gram_10k'],
        };
      } else {
        print("Failed to fetch gold rate: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      hideProgressBar();
      isLoading(false);
    }
  }

  Timer? timer;

  @override
  void onInit() {
    super.onInit();
    fetchGoldRate();
    timer = Timer.periodic(Duration(seconds: 10), (timer) {
      fetchGoldRate();
    });
  }

  @override
  void onClose() {
    timer?.cancel();  // Cancel the timer when controller is disposed
    super.onClose();
  }

}