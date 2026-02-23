# SF Symbol Icon Picker Integration Guide

## Overview

The CardUp app now supports native SF Symbol icons for card logos, providing a modern and consistent visual experience aligned with Apple's design language.

## Features

### 1. **SF Symbol Icon Picker**
- Browse icons organized by category (Business, Shopping, Food & Drink, Fitness, etc.)
- Search functionality to quickly find specific icons
- Color customization for each icon
- Real-time preview of selected icons

### 2. **Seamless Integration**
- Icons are automatically converted to PNG format for Apple Wallet passes
- Works alongside existing image-based logos
- Persistent storage using SwiftData

### 3. **User Experience**
- Intuitive category-based navigation
- Visual feedback for selected icons
- Ability to change or remove icons at any time

## Implementation Details

### New Files

#### `SFSymbolIconPicker.swift`
A comprehensive SwiftUI view that provides:
- Category-based icon browsing
- Search functionality
- Color picker integration
- Grid-based icon selection

### Modified Files

#### `Card.swift`
- Added `logoSFSymbol: String?` to store the SF Symbol name
- Added `logoIconColor: String?` to store the icon color in hex format
- Added `getLogoImageDataForPass()` method to generate PNG data from SF Symbols
- Enhanced `logoImage` computed property to prioritize SF Symbols

#### `EditCardView.swift`
- Added `LogoIconSection` to display and manage icon selection
- Integrated icon picker sheet presentation
- Updated preview section to show selected SF Symbol icons
- Enhanced save functionality to persist icon data

#### `PassKitIntegrator.swift`
- Updated to use `card.getLogoImageDataForPass()` for pass generation
- Ensures SF Symbol icons are properly converted to PNG format

#### `ExtensionsService.swift`
- Added `glassEffect` view modifier placeholder for visual polish

## Usage

### Selecting an Icon

1. Open a card in edit mode
2. Navigate to the "Logo Icon" section
3. Tap "Choose Icon"
4. Browse categories or search for an icon
5. Select your desired icon
6. Customize the icon color if needed
7. Tap "Done"

### Changing or Removing an Icon

- To change: Tap "Change Icon" and select a new one
- To remove: Tap "Remove Icon"

### Integration with Apple Wallet

When regenerating a pass, the selected SF Symbol icon is:
1. Rendered at appropriate size (100pt)
2. Colored according to the selected color
3. Converted to PNG format
4. Included in the .pkpass file

## Technical Notes

### SF Symbol Rendering

Icons are rendered using `UIImage.SymbolConfiguration`:
- Point size: 100pt for pass generation, 50pt for UI preview
- Weight: Regular
- Rendering mode: Always original (to preserve color)

### Color Management

- Icon colors are stored as hex strings
- Automatic conversion between SwiftUI Color and hex format
- Falls back to foreground color if no custom color is set

### Data Persistence

- SwiftData automatically persists `logoSFSymbol` and `logoIconColor`
- Migration from existing image-based logos is seamless
- Both image and SF Symbol logos can coexist (SF Symbol takes priority)

## Icon Categories

The picker includes the following predefined categories:

1. **All** - Shows all available icons
2. **Business** - building.2.fill, briefcase.fill, chart.line.uptrend.xyaxis, etc.
3. **Shopping** - cart.fill, bag.fill, creditcard.fill, etc.
4. **Food & Drink** - cup.and.saucer.fill, fork.knife, wineglass.fill, etc.
5. **Fitness** - figure.run, dumbbell.fill, heart.fill, etc.
6. **Entertainment** - tv.fill, music.note, film.fill, etc.
7. **Travel** - airplane, car.fill, tram.fill, etc.
8. **Communication** - envelope.fill, phone.fill, message.fill, etc.
9. **Objects** - key.fill, lock.fill, shield.fill, etc.

## Future Enhancements

Potential improvements:
- Add more icon categories
- Support for custom icon upload alongside SF Symbols
- Icon animation support
- Dynamic icon selection based on card type
- Favorite icons list

## Troubleshooting

### Icon not showing in preview
- Ensure the icon name is valid
- Check that the icon color is set
- Verify SwiftData persistence

### Icon not appearing in Apple Wallet pass
- Confirm pass regeneration was successful
- Check that `getLogoImageDataForPass()` is being called
- Verify PNG conversion is working

## Best Practices

1. **Choose icons that represent your brand** - Select icons that are immediately recognizable
2. **Use consistent colors** - Match icon colors to your card's color scheme
3. **Test in Apple Wallet** - Always regenerate and preview passes after changing icons
4. **Consider accessibility** - Choose icons with clear shapes and sufficient contrast

## Code Example

```swift
// Setting an icon programmatically
card.logoSFSymbol = "creditcard.fill"
card.logoIconColor = "#FFFFFF"

// Getting logo image data for pass generation
if let logoData = card.getLogoImageDataForPass() {
    // Use in pass generation
}

// Displaying in SwiftUI
if let logoImage = card.logoImage {
    Image(uiImage: logoImage)
        .resizable()
        .frame(width: 50, height: 50)
}
```

## Compatibility

- **iOS**: 17.0+
- **SwiftUI**: Latest version
- **SwiftData**: Latest version
- **SF Symbols**: 5.0+

---

**Last Updated**: February 23, 2026
