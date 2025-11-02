# Next Wave v3.3 - TestFlight Update 🚀

Hey everyone! 👋

Today's update brings massive performance improvements for ship name display. The app should now feel much smoother and more professional!

## What's New? ✨

### 🎯 Main Improvement: Ship Names Without Flickering

**The Problem:**
- Ship names for tomorrow and the day after weren't loading at all (only today worked)
- When opening a station, "Loading..." briefly appeared for ship names
- The list "flickered" multiple times during loading
- When switching days, the list jumped around before settling at the top

**The Solution:**
✅ **No More "Loading..." Indicators** - Ship names appear instantly from cache  
✅ **Zero UI Flickering** - List updates only once when all data is ready  
✅ **Correct 3-Day Data** - Ship names for today, tomorrow, and the day after now load reliably  
✅ **Significantly Faster** - Data cached for 24 hours, no redundant API calls  
✅ **Smooth Day Switching** - No more jumping when changing between days  

### 🔧 Technical Improvements

**Intelligent Caching:**
- 3-layer cache system (API, URLSession, In-Memory)
- Data loaded from server only once per day
- Instant access thereafter with no wait time

**Improved Scraping:**
- New Puppeteer-based technology for more reliable ZSG data loading
- Simulates real browser interaction (clicking "Next Day" button) to load all 3 days
- Fixed: Ship names now load correctly for tomorrow and the day after (not just today)
- More robust error handling

**Optimized UI Updates:**
- All data (weather + ship names) loaded in background
- UI updates only once when everything is ready
- Smart scroll positioning: today scrolls to next departure, other days scroll to top
- Smooth, professional user experience

## What Should You Test? 🧪

1. **Ship Name Display:**
   - Open different Lake Zurich stations
   - Watch for any "Loading..." text (there shouldn't be any!)
   - Check if ship names appear immediately

2. **Multiple Opens:**
   - Open the same station multiple times in a row
   - Ship names should appear instantly the second time

3. **Day Switching:**
   - Switch between today, tomorrow, and the day after
   - Verify that ship names are displayed for all days
   - Check that the list doesn't jump around when switching days
   - Today should scroll to next departure, other days should show from the top

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
- See the list jumping when switching days
- Find missing or incorrect ship names
- Experience any other performance issues

Thanks so much for your testing! 🙏

Patrick

---

**Version:** 3.3  
**Build:** [TBD]  
**Date:** November 2, 2025

