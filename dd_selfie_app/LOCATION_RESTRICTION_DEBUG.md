# Location Restriction Debug Guide

## Changes Made

I've improved the location restriction implementation with:

### 1. **Debug Logging**
- Added detailed console logs (visible in Android Studio/Xcode console when running in debug mode)
- Logs show:
  - Location policy loading status
  - Parsed coordinates and radius
  - Distance calculations
  - Whether restrictions are bypassed or active

### 2. **Visual Debug Panel**
- Added an on-screen debug panel (only visible in debug mode)
- Shows real-time status of:
  - Policy loading status
  - Location mode (EVERYONE/DELTA/ELISA)
  - Base coordinates and radius
  - Current location
  - Distance from base
  - Whether user is within allowed range

### 3. **Improved Coordinate Validation**
- Removed the strict (0,0) coordinate rejection
- Added better validation logging
- Shows exactly why coordinates might be rejected

## How to Test

### Step 1: Run in Debug Mode
```bash
flutter run --debug
```

### Step 2: Check the Debug Panel
- When you open the selfie screen, you'll see a black/yellow debug panel at the top
- This panel shows all location restriction status in real-time

### Step 3: Check Console Logs
Look for these logs in your console:
- `📍 Location Policy Loaded:` - Shows what the backend returned
- `📍 Distance check:` - Shows distance calculation
- `⚠️` - Warnings about invalid data
- `❌` - Errors loading policy

## Common Issues & Solutions

### Issue 1: Location Restriction Always Bypassed

**Symptoms:**
- Debug panel shows "LOCATION RESTRICTION: BYPASSED"
- Mode shows "EVERYONE"
- Base coordinates show "NULL"

**Possible Causes:**
1. **Backend returning invalid data**
   - Check backend API response at: `https://customprint.deodap.com/api_selfie_app/selfie_location.php?action=get_policy&emp_code=YOUR_EMP_CODE`
   - Verify response has `ok: true` and valid `data` object

2. **Backend returning null/invalid coordinates**
   - Check if `lat` and `lng` are actual numbers (not "null" strings or 0)
   - Check if `mode` is set correctly (should be "DELTA", "ELISA", not "EVERYONE")

3. **Coordinate parsing failing**
   - Console will show: `⚠️ Invalid coordinates from backend`
   - Check coordinate format in backend response

### Issue 2: Distance Check Not Working

**Symptoms:**
- Base coordinates are set correctly
- But app still allows selfie from far away

**Solution:**
Check console logs for distance calculation. You should see:
```
📍 Distance check:
   Current: (lat, lng)
   Base: (lat, lng)
   Distance: XXX meters
   Allowed: XXX meters
   Within Range: true/false
```

If this doesn't appear, location might not be loading before the check.

### Issue 3: GPS Location Not Available

**Symptoms:**
- Debug panel shows "Current Coords: ❌ NULL"
- Location service or permission is off

**Solution:**
1. Enable GPS on device
2. Grant location permission to app
3. Tap "Refresh Location" button

## Backend API Requirements

Your backend API should return this format:

```json
{
  "ok": true,
  "data": {
    "mode": "DELTA",  // or "ELISA" or "EVERYONE"
    "lat": 28.123456,  // NUMBER or STRING (not "null")
    "lng": 77.123456,  // NUMBER or STRING (not "null")
    "radius_m": 600,   // radius in meters
    "address": "Office Address Here"
  }
}
```

### Important Notes:
1. **mode = "EVERYONE"** → Location restriction is DISABLED (anyone can take selfie anywhere)
2. **mode = "DELTA" or "ELISA"** → Location restriction is ENABLED
3. If `lat` or `lng` are null/"null"/0, restriction is automatically bypassed
4. If API fails or returns `ok: false`, app defaults to "EVERYONE" mode (no restriction)

## Testing Checklist

- [ ] Run app in debug mode
- [ ] Check debug panel appears on selfie screen
- [ ] Verify "Policy Loaded" shows ✅ YES
- [ ] Verify "Mode" is NOT "EVERYONE" (should be DELTA or ELISA)
- [ ] Verify "Base Coords" shows ✅ SET with actual coordinates
- [ ] Verify "Current Coords" shows your GPS location
- [ ] Check console logs for any ⚠️ or ❌ messages
- [ ] Try taking selfie from far away - should show distance warning
- [ ] Try taking selfie from within allowed radius - should work

## Quick Fix for Backend

If your backend is not returning proper coordinates, update your backend API to:

1. Always return valid lat/lng values (not null)
2. Set mode to "DELTA" or "ELISA" (not "EVERYONE")
3. Set appropriate radius_m value
4. Return actual address string

Example backend query:
```sql
SELECT
  'DELTA' as mode,
  28.123456 as lat,
  77.123456 as lng,
  600 as radius_m,
  'Head Office, City Name' as address
FROM dual;
```

## Removing Debug Panel (Production)

The debug panel automatically disappears when you build a release version:
```bash
flutter build apk --release
```

Debug logs also won't appear in release builds.

## Contact for Help

If location restriction still doesn't work after checking these items:
1. Share the console logs showing the location policy response
2. Share a screenshot of the debug panel
3. Share your backend API response for the policy endpoint
