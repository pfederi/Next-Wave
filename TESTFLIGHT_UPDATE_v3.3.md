# Next Wave v3.3 - TestFlight Update 🚀

Hey everyone! 👋

Today's update brings massive performance improvements for ship name display. The app should now feel much smoother and more professional!

## What's New? ✨

### 🎯 Main Improvement: Ship Names Without Flickering

**The Problem:**
- When opening a station, "Loading..." briefly appeared for ship names
- The list "flickered" multiple times during loading
- Ship names for tomorrow and the day after weren't loading correctly

**The Solution:**
✅ **No More "Loading..." Indicators** - Ship names appear instantly from cache  
✅ **Zero UI Flickering** - List updates only once when all data is ready  
✅ **Correct 3-Day Data** - Ship names for today, tomorrow, and the day after now load reliably  
✅ **Significantly Faster** - Data cached for 24 hours, no redundant API calls  

### 🔧 Technical Improvements

**Intelligent Caching:**
- 3-layer cache system (API, URLSession, In-Memory)
- Data loaded from server only once per day
- Instant access thereafter with no wait time

**Improved Scraping:**
- New Puppeteer-based technology for more reliable ZSG data loading
- Simulates real browser interaction (clicking "Next Day" button)
- More robust error handling

**Optimized UI Updates:**
- All data (weather + ship names) loaded in background
- UI updates only once when everything is ready
- Smooth, professional user experience

## What Should You Test? 🧪

1. **Ship Name Display:**
   - Open different Lake Zurich stations
   - Watch for any "Loading..." text (there shouldn't be any!)
   - Check if ship names appear immediately

2. **Multiple Opens:**
   - Open the same station multiple times in a row
   - Ship names should appear instantly the second time

3. **Day Changes:**
   - Look at departures for tomorrow and the day after
   - Verify that ship names are displayed for those days too

4. **Performance:**
   - Pay attention to the overall app speed
   - Notice any delays or flickering anywhere?

## Known Limitations ⚠️

- Ship names only available for Lake Zurich stations
- First app launch of the day will reload data (brief wait)
- After that, all data is cached for 24 hours

## Feedback Welcome! 💬

Please let me know if you:
- Still see "Loading..." anywhere
- Notice any flickering or stuttering
- Find missing or incorrect ship names
- Experience any other performance issues

Thanks so much for your testing! 🙏

Patrick

---

**Version:** 3.3  
**Build:** [TBD]  
**Date:** November 2, 2025

