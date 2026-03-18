# Unified Scanner - Visual Flow Diagram

## Screen Layout

```
┌─────────────────────────────────────────┐
│  📱 Unified QR Scanner                  │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  📷 CAMERA SCANNER (45%)        │   │
│  │                                 │   │
│  │  [Scan Feedback Popup] 🔦      │   │  ← Top popup shows real-time scan results
│  │                                 │   │
│  │      ┌─────────────┐           │   │
│  │      │   QR CODE   │           │   │  ← Scanner viewfinder frame
│  │      │   FRAME     │           │   │
│  │      └─────────────┘           │   │
│  │                                 │   │
│  │  [Scan primary/secondary QR]   │   │  ← Instruction card
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  📋 ORDER LIST (55%)            │   │
│  │  ────────────────────────────── │   │
│  │  ✅ Primary Order               │   │  ← Primary order card (after 1st scan)
│  │     Order: #12345               │   │
│  │     Location: Warehouse A       │   │
│  │     Parts: 3                    │   │
│  │  ────────────────────────────── │   │
│  │  📦 Secondary Orders (2/3)      │   │  ← Live progress counter
│  │  ────────────────────────────── │   │
│  │  ✅ Secondary #001 - Scanned    │   │  ← Scanned (green)
│  │  ✅ Secondary #002 - Scanned    │   │  ← Scanned (green)
│  │  ⏳ Secondary #003 - Waiting    │   │  ← Waiting (white)
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [Close Button - Hidden]        │   │  ← Only shows when all scanned
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Scanning Flow

### Phase 1: Primary Order Scan
```
START
  │
  ▼
┌──────────────────┐
│ Open Scanner     │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│ Scanner Active (Top)         │
│ "Waiting for Primary" (Bot) │
└────────┬─────────────────────┘
         │
         ▼ Scan Primary QR
┌──────────────────┐
│ API Call to      │
│ Get Order Info   │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│ ✓ Show popup: "Primary OK"  │
│ ✓ Play success sound        │
│ ✓ Display primary card      │
│ ✓ Display all secondaries   │
└────────┬─────────────────────┘
         │
         ▼
    [Phase 2]
```

### Phase 2: Secondary Orders Scan
```
┌──────────────────────────────┐
│ Scanner Still Active         │
│ Primary + Secondaries Shown  │
└────────┬─────────────────────┘
         │
         ▼ Scan Secondary QR #1
┌──────────────────────────────┐
│ ✓ Match against list         │
│ ✓ Show popup: "Secondary OK" │
│ ✓ Play success sound         │
│ ✓ Mark as scanned (green)    │
│ ✓ Update counter (1/3)       │
└────────┬─────────────────────┘
         │
         ▼ Scan Secondary QR #2
┌──────────────────────────────┐
│ ✓ Same process...            │
│ ✓ Update counter (2/3)       │
└────────┬─────────────────────┘
         │
         ▼ Scan Secondary QR #3
┌──────────────────────────────┐
│ ✓ Same process...            │
│ ✓ Update counter (3/3)       │
│ ✓ ALL COMPLETE!              │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ 🎉 Show Close Button         │
│    "All orders scanned"      │
└────────┬─────────────────────┘
         │
         ▼ User taps Close
┌──────────────────┐
│ Return to Home   │
└──────────────────┘
         │
         ▼
      [END]
```

## Real-Time Popup Behavior

### Successful Primary Scan
```
┌────────────────────────────────┐
│ ✓ Primary Order Scanned        │
│   Order: #12345                │  ← Green background
└────────────────────────────────┘
   ↓ Auto-dismiss after 2 seconds
```

### Successful Secondary Scan
```
┌────────────────────────────────┐
│ ✓ Secondary Scanned            │
│   Secondary #001               │  ← Green background
└────────────────────────────────┘
   ↓ Auto-dismiss after 2 seconds
```

### Error Cases
```
┌────────────────────────────────┐
│ ✗ QR not in list or already    │
│   scanned                      │  ← Red background
└────────────────────────────────┘
   ↓ Auto-dismiss after 2 seconds

┌────────────────────────────────┐
│ ✗ Network error                │
│   Please try again             │  ← Red background
└────────────────────────────────┘
   ↓ Auto-dismiss after 2 seconds
```

## Order Card State Transitions

### Before Scan
```
┌─────────────────────────┐
│ 📦 Secondary #001       │  White background
│ ⏳ Waiting for scan     │  Orange status
│                         │  QR icon
└─────────────────────────┘
```

### After Scan
```
┌─────────────────────────┐
│ ✅ Secondary #001       │  Light green background
│ ✓ Scanned               │  Green status
│                         │  Checkmark icon
└─────────────────────────┘
```

## Close Button States

### Not Ready (Hidden)
```
┌────────────────────────────────┐
│ ⏳ Scanned 2/3 orders          │  ← Status only, no button
└────────────────────────────────┘
```

### Ready (Visible)
```
┌────────────────────────────────┐
│ ✅ All orders scanned (3/3)    │  ← Status
├────────────────────────────────┤
│ [  ✓ Close  ]                  │  ← Green button appears
└────────────────────────────────┘
```

## User Interaction Points

```
1. 🔦 Torch Toggle
   ├─ Location: Top-right of scanner
   ├─ Action: Toggle flashlight on/off
   └─ Visual: Bolt icon (filled/slashed)

2. 📷 QR Scanner Frame
   ├─ Location: Center of top half
   ├─ Action: Automatically scans QR codes
   └─ Visual: Blue border frame

3. 📋 Order Cards
   ├─ Location: Bottom half (scrollable)
   ├─ Action: Visual feedback only (no tap)
   └─ Visual: White → Green when scanned

4. ✅ Close Button
   ├─ Location: Bottom (only when complete)
   ├─ Action: Return to home screen
   └─ Visual: Green button with checkmark
```

## Edge Cases Handling

### Duplicate Scan
```
Scan same QR twice
   ↓
Check if already scanned
   ↓
Show error popup: "Already scanned"
   ↓
Play error sound
   ↓
Continue scanning
```

### Wrong QR Code
```
Scan QR not in list
   ↓
Check against secondary order list
   ↓
No match found
   ↓
Show error popup: "QR not in list"
   ↓
Play error sound
   ↓
Continue scanning
```

### Network Failure
```
API call fails
   ↓
Catch error
   ↓
Show error popup: "Network error"
   ↓
Play error sound
   ↓
User can retry by scanning again
```

### Rapid Scanning
```
Scan QR #1
   ↓
< 900ms passes
   ↓
Scan QR #2 (same or different)
   ↓
Ignored (debounced)
   ↓
Wait for cooldown
   ↓
Can scan again
```

## Performance Optimization

```
Camera
   ↓
Continuous active (no restart)
   ↓
Single scanner for all QRs
   ↓
No modal popups (faster)

API
   ↓
Single call for primary
   ↓
All secondary data included
   ↓
No additional network calls

Memory
   ↓
Small order list in RAM
   ↓
Efficient state updates
   ↓
Auto-cleanup on exit
```

## Summary of Requirements Met

✅ **First scan primary order** - Phase 1
✅ **Display all orders at top** - Bottom half shows scrollable list
✅ **Close button hidden until complete** - Conditional rendering based on _allScanned
✅ **Same scanner for both** - Single continuous MobileScanner instance
✅ **Real-time popup feedback** - _FeedbackCard with auto-dismiss timer
✅ **Show each scan in popup** - Success/error messages with icons

## Color Legend

| Color | Meaning |
|-------|---------|
| 🟢 Green | Scanned / Success / Complete |
| 🟠 Orange | In Progress / Waiting |
| 🔴 Red | Error / Failed |
| 🔵 Blue | Scanner frame / Primary action |
| ⚪ White | Default / Not started |
