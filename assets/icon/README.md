# App Icon Instructions

## How to Change the App Logo

1. **Prepare your icon image:**
   - Create a square image (recommended: 1024x1024 pixels)
   - PNG format with transparent background (optional)
   - The image should be high quality and look good at small sizes
   - **Important for Android**: Keep your main content (like the spork) in the center 70% of the image to avoid cropping

2. **Place your icon:**
   - Save your icon image as `app_icon.png` in this folder (`assets/icon/app_icon.png`)
   - Make sure the filename matches exactly: `app_icon.png`

3. **Generate the icons:**
   - Run this command in your terminal:
     ```
     flutter pub get
     dart run flutter_launcher_icons
     ```

4. **Rebuild your app:**
   - The icons will be automatically generated for Android, iOS, and Web
   - Rebuild your app to see the new icon

## For Best Results (Android Adaptive Icons):

**Option 1: Use current image (simpler)**
- Your current setup uses the full image with a red background
- The icon is scaled to 85% to keep content in the safe zone
- This should work, but the background might still appear as a square on some launchers

**Option 2: Separate foreground and background (recommended)**
- Create a foreground image: `app_icon_foreground.png` - just the spork with transparent background
- The red background color is already configured in `pubspec.yaml`
- Update `pubspec.yaml` to use:
  ```yaml
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  adaptive_icon_background: "#FF0000"
  ```
- This gives the best result with seamless rounded/square shapes on different Android launchers

## Notes:
- Android uses "adaptive icons" - the outer 25% can be cropped by different launchers
- Keep important content in the center 66% of your icon (the "safe zone")
- The icon will be automatically resized for all required sizes
- For best results, use a square image (1024x1024px recommended)
- The icon should be recognizable even at small sizes (48x48px)
