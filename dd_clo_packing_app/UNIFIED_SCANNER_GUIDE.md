# Unified Scanner Implementation Guide

## Overview
The new Unified Scanner provides a streamlined QR scanning experience where both primary and secondary orders are scanned using the same continuous scanner interface.

## Key Features

### 1. **Single Scanner Interface**
- One continuous camera scanner handles both primary and secondary QR codes
- No modal popups or screen changes during scanning
- Scanner remains active throughout the entire process

### 2. **Real-Time Scan Feedback**
- Each scanned QR code displays a popup notification at the top
- Green checkmark popup for successful scans
- Red error popup for invalid/duplicate scans
- Auto-dismisses after 2 seconds

### 3. **Split Screen Layout**
- **Top Half (45%)**: Live camera scanner with overlay
  - QR code viewfinder frame
  - Torch/flashlight toggle button (top-right)
  - Real-time scan feedback popup (top-left)
  - Instruction card at bottom of scanner

- **Bottom Half (55%)**: Order list display
  - Primary order card (after first scan)
  - Secondary orders list with scan status
  - Live progress tracking

### 4. **Two-Phase Scanning Process**

#### Phase 1: Primary Order Scan
1. User opens scanner
2. Bottom shows "Waiting for Primary Order Scan" message
3. User scans primary order QR code
4. System fetches order details from API
5. Displays primary order card and all secondary orders at bottom
6. Scanner automatically switches to secondary scanning mode

#### Phase 2: Secondary Orders Scan
1. All secondary orders displayed in scrollable list
2. Each order shows:
   - Order number
   - Scan status (waiting/scanned)
   - Visual indicator (QR icon → green checkmark)
3. User scans secondary QR codes one by one
4. Each scan:
   - Plays success/error sound
   - Shows real-time popup feedback
   - Updates the order card to "Scanned" status
   - Changes card background to green tint

### 5. **Close Button Behavior**
- **Before all scans complete**: Close button is HIDDEN
- **After all scans complete**:
  - Close button appears at bottom
  - Shows green "Close" button with checkmark icon
  - Status changes to "All orders scanned (X/X)"
  - Tapping Close returns to home screen

### 6. **Progress Tracking**
- Header shows "Scanned X / Y orders" count
- Visual progress indicators on each order card
- Color-coded status (orange = in progress, green = complete)

## Implementation Details

### File Structure
```
lib/
├── qr/
│   ├── unified_scanner.dart (NEW - Main implementation)
│   ├── qr_scanner.dart (OLD - Original scanner)
│   └── qr_scanner_two.dart (Slip viewer)
├── route/
│   ├── app_route.dart (Updated - Added unified scanner route)
│   └── app_page.dart (Updated - Registered unified scanner)
└── home/
    └── home.dart (Updated - Points to unified scanner)
```

### Key Components

#### 1. **UnifiedScannerScreen**
Main screen widget that manages:
- Scanner controller
- State management for scanned orders
- API calls
- Audio feedback

#### 2. **State Management**
```dart
bool _primaryScanned = false;
PrimaryOrderInfo? _primaryOrder;
List<SecondaryOrderInfo> _secondaryOrders = [];
```

#### 3. **Scan Flow**
```dart
_handleScan(String rawCode) {
  if (!_primaryScanned) {
    _scanPrimaryOrder(code);  // Fetch from API
  } else {
    _scanSecondaryOrder(code);  // Match against list
  }
}
```

#### 4. **Visual Feedback**
- `_FeedbackCard`: Top popup for scan notifications
- `_InstructionCard`: Bottom instruction text
- `_PrimaryCard`: Primary order details
- `_SecondaryCard`: Each secondary order status
- `_BottomBar`: Progress and close button

## Usage Instructions

### For Users:
1. **Open Scanner**: Tap "CLO Packaging Scanner" from home
2. **Scan Primary**: Point camera at primary order QR code
   - Wait for green popup confirmation
   - See all secondary orders appear at bottom
3. **Scan Secondary Orders**: Point camera at each secondary QR
   - Orders can be scanned in any order
   - Each scan shows instant feedback
   - Already-scanned orders won't scan again
4. **Complete**: When all orders scanned
   - Green "Close" button appears
   - Tap to return to home

### For Developers:

#### Route Configuration
The scanner is registered at `/unified-scanner`:
```dart
// Access from anywhere:
Get.toNamed(AppRoutes.unifiedScanner);
```

#### API Configuration
Update API credentials in `unified_scanner.dart` if needed:
```dart
final ApiClient _api = const ApiClient(
  apiBaseUrl: "YOUR_API_BASE_URL",
  appId: "YOUR_APP_ID",
  apiKey: "YOUR_API_KEY",
);
```

#### Audio Assets
Ensure these audio files exist:
- `assets/audio/success.mp3` - Success scan sound
- `assets/audio/failed.mp3` - Error scan sound

Add to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/audio/success.mp3
    - assets/audio/failed.mp3
```

## Error Handling

### Network Errors
- Displays error message in scan feedback popup
- Plays error sound
- Allows retry by scanning again

### Invalid QR Codes
- "QR not in list or already scanned" message
- Prevents duplicate scans
- Red error feedback

### Debouncing
- Prevents rapid duplicate scans (900ms cooldown)
- Compares against last scanned code

## Customization Options

### Colors
```dart
// Success color
CupertinoColors.systemGreen

// Error color
CupertinoColors.systemRed

// In-progress color
CupertinoColors.systemOrange

// Primary brand color
CupertinoColors.activeBlue
```

### Timing
```dart
// Feedback popup duration
Timer(const Duration(seconds: 2), ...)

// Scan cooldown
now.difference(_lastScanTime!).inMilliseconds < 900

// API timeout
await req.send().timeout(const Duration(seconds: 30))
```

### Layout Dimensions
```dart
// Scanner height (top half)
final scannerHeight = size.height * 0.45;

// Scanner frame size
cutOutSize: size.width * 0.70
```

## Testing Checklist

- [ ] Primary QR scan loads order details
- [ ] Secondary orders display correctly
- [ ] Each secondary scan updates status
- [ ] Duplicate scans are prevented
- [ ] Invalid QR shows error message
- [ ] Close button appears only when complete
- [ ] Torch toggle works
- [ ] Audio feedback plays
- [ ] Network errors handled gracefully
- [ ] Back navigation works correctly

## Migration Notes

### From Old Scanner
The previous scanner (`qr_scanner.dart`) is still available at `/qr-scanner` route if needed for fallback. The new unified scanner is now the default for:
- Home screen "CLO Packaging Scanner" button
- Drawer menu "QR Scanner (Packing)" option

### Backward Compatibility
Both scanners can coexist. To revert to old scanner:
```dart
// In home.dart, change:
Get.toNamed(AppRoutes.unifiedScanner);
// Back to:
Get.toNamed(AppRoutes.qrScanner);
```

## Performance Considerations

1. **Camera Resources**: Scanner auto-starts and remains active
2. **Memory**: Order lists are kept in memory during session
3. **Network**: Single API call for primary order (includes all secondary data)
4. **Debouncing**: Prevents rapid scan spam

## Future Enhancements

Potential improvements:
- [ ] Barcode scanning support
- [ ] Manual QR code entry option
- [ ] Scan history/log
- [ ] Export scanned data
- [ ] Offline mode with sync
- [ ] Multi-language support
- [ ] Scan statistics

## Support

For issues or questions:
1. Check console logs for error details
2. Verify API credentials are correct
3. Ensure camera permissions granted
4. Confirm audio assets are loaded
5. Test network connectivity

## Version History

### v1.0.0 (Current)
- Initial unified scanner implementation
- Real-time scan feedback
- Progressive order display
- Conditional close button
- Audio feedback integration
