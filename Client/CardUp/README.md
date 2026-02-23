# CardUp 📇

**Transform physical loyalty cards into digital Apple Wallet passes using AI**

CardUp is an iOS application that uses Google's Gemini AI to automatically extract information from physical card photos and generate fully functional Apple Wallet passes. Say goodbye to bulky wallets and hello to seamless digital card management.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

## 🎉 Latest Update: PassKit Generic Format Support

CardUp now fully supports **Apple PassKit's Generic pass format**, providing maximum flexibility and standards compliance for loyalty cards, membership cards, and more.

**📚 New Documentation:**
- **[PASSKIT_GENERIC_CHANGES_SUMMARY.md](PASSKIT_GENERIC_CHANGES_SUMMARY.md)** - Complete overview of changes
- **[GEMINI_PROMPT_TEMPLATE.md](GEMINI_PROMPT_TEMPLATE.md)** - Gemini AI integration guide with JSON format
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Detailed migration instructions

**✨ What's New:**
- Full PassKit Generic pass format support with all field types
- Structured fields (primary, secondary, auxiliary, back, header)
- Enhanced date, number, and currency formatting
- RGB to hex color conversion
- Complete alignment with Apple's pass.json specification

**⚠️ Important:** Update your Gemini AI prompt to return the new JSON format. See `GEMINI_PROMPT_TEMPLATE.md` for details.

## ✨ Features

- 📸 **AI-Powered Scanning**: Capture any loyalty, membership, or coupon card with your camera
- 🤖 **Gemini AI Analysis**: Automatically extracts card details, barcodes, and design elements
- 🎨 **Smart Design**: Analyzes dominant colors and preserves card branding
- 📱 **Apple Wallet Integration**: Generates fully functional .pkpass files
- 🔐 **Sign in with Apple**: Secure authentication with Face ID/Touch ID
- ☁️ **iCloud Sync**: Keep your cards in sync across all your devices
- 💳 **Pro Subscriptions**: Optional premium features via StoreKit 2
- 🌐 **RTL Language Support**: Full support for Hebrew, Arabic, and other RTL languages

## 📋 Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Apple Developer account (for Sign in with Apple and PassKit)
- Backend server with Gemini AI integration (see [Backend Requirements](#backend-requirements))

## 🏗️ Architecture

CardUp follows a clean, service-oriented MVVM architecture:

```
┌─────────────────────────────────────────────┐
│              SwiftUI Views                   │
│  (HomeScreen, AddCardView, EditCardView)    │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│          Observable Services                 │
│  ┌────────────────────────────────────────┐ │
│  │    CardProcessingService               │ │
│  │    (AI processing orchestration)       │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │    ServerApi                           │ │
│  │    (REST API client)                   │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │    PassKitIntegrator                   │ │
│  │    (Apple Wallet pass generation)      │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │    AuthenticationService               │ │
│  │    (Sign in with Apple)                │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │    PaymentService                      │ │
│  │    (StoreKit 2 subscriptions)          │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │    StorageManagerService               │ │
│  │    (SwiftData + CloudKit)              │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│           SwiftData Models                   │
│         (Card, User)                        │
└─────────────────────────────────────────────┘
```

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourcompany/cardUp.git
cd cardUp
```

### 2. Configure the Project

#### a. Update Team and Bundle Identifier

Open `CardUp.xcodeproj` in Xcode:
1. Select the CardUp target
2. Go to Signing & Capabilities
3. Select your Team
4. Update Bundle Identifier

#### b. Enable Capabilities

Ensure these capabilities are enabled:
- ✅ PassKit
- ✅ Sign in with Apple
- ✅ iCloud → CloudKit
- ✅ In-App Purchase

#### c. Configure Backend URL

Set the `SERVER_URL` environment variable:

**Option 1: Scheme Environment Variable**
1. Edit scheme (Product → Scheme → Edit Scheme)
2. Run → Arguments → Environment Variables
3. Add `SERVER_URL` = `https://your-backend.com`

**Option 2: Code Default**
Update `ServerApi.swift`:
```swift
self.baseURL = "https://your-backend.com"
```

#### d. Update Product Identifiers

In `PaymentService.swift`, update:
```swift
private let proMonthlyId = "com.yourcompany.cardUp.pro.monthly"
private let proYearlyId = "com.yourcompany.cardUp.pro.yearly"
```

### 3. Configure Development Mode

For local development without full backend:

**AuthenticationService.swift:**
```swift
private let bypassLogin = true  // Skip Sign in with Apple
```

**PassKitIntegrator.swift:**
```swift
private let useMockPassGeneration = true  // Use JSON mocks
```

### 4. Build and Run

```bash
# For simulator (limited PassKit support)
⌘R

# For physical device (full functionality)
Select device → ⌘R
```

## 📚 Documentation

Comprehensive documentation is available:

- **[DOCUMENTATION.md](DOCUMENTATION.md)**: Complete project documentation with architecture, data flow, and deployment guides
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)**: Quick reference for common tasks and code snippets
- **[API_REFERENCE.md](API_REFERENCE.md)**: Complete API reference for all services, models, and extensions

### Quick Links

- [Processing Pipeline](DOCUMENTATION.md#processing-pipeline)
- [API Integration](DOCUMENTATION.md#api-integration)
- [Error Handling](DOCUMENTATION.md#error-handling)
- [Common Tasks](QUICK_REFERENCE.md#common-tasks)
- [Service APIs](API_REFERENCE.md#services)

## 🔧 Backend Requirements

CardUp requires a backend server with these endpoints:

### 1. Gemini AI Analysis Endpoint

```
POST /api/gemini/chat
Content-Type: multipart/form-data

file: [JPEG image, max 5MB]
```

**Response:**
```json
{
  "passFormat": "storeCard",
  "cardDetails": {
    "organizationName": "Example Coffee",
    "description": "Loyalty Card",
    "barcodeMessage": "1234567890",
    "barcodeFormat": "Code128",
    "backgroundColor": "#8B4513",
    "primaryFields": [...]
  },
  "designImage": "data:image/png;base64,..."
}
```

### 2. Pass Generation Endpoint (Production)

```
POST /generate-pass
Content-Type: application/json

{
  "cardId": "uuid",
  "passType": "storeCard",
  "organizationName": "Example Coffee",
  // ... other fields
}
```

**Response:** Raw `.pkpass` file (binary)

### Backend Implementation Examples

- **Node.js**: See `backend-examples/node/`
- **Python Flask**: See `backend-examples/python/`
- **CloudFlare Worker**: See `backend-examples/cloudflare/`

## 💡 Usage

### Basic Card Processing

```swift
// In your view
@State private var processingService = CardProcessingService()

// Process card image
func processCard(image: UIImage, card: Card) async {
    await processingService.generateWalletPass(from: image, for: card)
    
    if let error = processingService.error {
        showAlert(error)
    } else if let passData = processingService.generatedPassData {
        // Success! Add to wallet
        if let vc = try? passKitIntegrator.addPassToWallet(passData: passData) {
            present(vc, animated: true)
        }
    }
}
```

### Monitor Progress

```swift
if processingService.isProcessing {
    ProgressView(value: processingService.processingProgress) {
        Text("Processing")
    } currentValueLabel: {
        Text("\(Int(processingService.processingProgress * 100))%")
    }
    
    Text(processingService.processingStatus)
        .font(.caption)
}
```

### Fetch Cards with SwiftData

```swift
@Query(sort: \Card.creationDate, order: .reverse) 
private var cards: [Card]

var body: some View {
    List(cards) { card in
        CardRow(card: card)
    }
}
```

## 🎨 UI Components

### Liquid Glass Effects

CardUp includes a modern Liquid Glass design system:

```swift
Button("Action") { }
    .glassEffect()

Button("Themed Action") { }
    .glassEffect(.regular.tint(.blue).interactive(), in: .capsule)
```

### Glass Container

```swift
GlassEffectContainer(spacing: 20) {
    VStack {
        Button("One") { }.glassEffect()
        Button("Two") { }.glassEffect()
    }
}
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
⌘U

# Run specific test suite
xcodebuild test -scheme CardUp -only-testing:CardUpTests/CardProcessingServiceTests
```

### Writing Tests

```swift
import Testing

@Test("Image compression works correctly")
func testImageCompression() async throws {
    let service = CardProcessingService()
    let image = UIImage(/* test image */)
    let data = service.compressImage(image)
    #expect(data!.count <= 5_242_880) // 5MB max
}
```

## 🐛 Troubleshooting

### Common Issues

**"No text was found in the image"**
- Ensure good lighting and card is in focus
- Card should be clearly visible without glare

**"PassKit is not available"**
- Test on a physical iOS device (not simulator)
- Ensure PassKit entitlement is enabled

**"Development mode: Configure CloudFlare Worker"**
- This is expected in development mode
- Set `useMockPassGeneration = false` for production

**"Network connection failed"**
- Verify `SERVER_URL` is correct
- Ensure backend server is running and reachable

### Debug Logging

CardUp includes extensive logging. Look for these emoji prefixes in console:

- 📸 Image processing
- 🌐 Network requests
- ✅ Success operations
- ❌ Errors
- 📊 Data updates
- 🎨 Design operations

## 📈 Performance

### Benchmarks

| Operation | Target Time |
|-----------|-------------|
| Image compression | <500ms |
| AI analysis | 3-8s |
| Color extraction | <200ms |
| Pass generation | <500ms (mock), 1-3s (real) |
| SwiftData save | <50ms |

### Optimization Tips

- Images are automatically compressed to <5MB
- Color extraction uses background threads
- SwiftData uses efficient queries with predicates
- Network requests use modern Swift Concurrency

## 🔐 Security

- **Keychain**: Secure credential storage with iCloud sync
- **SwiftData Encryption**: Automatic iOS encryption
- **HTTPS**: All network requests use TLS 1.2+
- **Sign in with Apple**: No passwords stored in app
- **Pass Signing**: CloudFlare Worker uses Apple certificates

## 🛣️ Roadmap

### v1.1 (Q2 2026)
- [ ] Offline OCR fallback
- [ ] Advanced logo detection with ML
- [ ] Pass updates and notifications
- [ ] Family sharing

### v1.2 (Q3 2026)
- [ ] Batch card processing
- [ ] Card categories and organization
- [ ] Export to other wallet apps
- [ ] Analytics dashboard

### v2.0 (Q4 2026)
- [ ] Dynamic pass fields (points, balance)
- [ ] Multi-language localization
- [ ] Widget support
- [ ] Apple Watch companion app

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Update documentation
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Add documentation comments to public APIs
- Keep methods focused (Single Responsibility)
- Write tests for new features

## 📄 License

Copyright © 2026 CardUp. All rights reserved.

This project is proprietary software. See LICENSE file for details.

## 📞 Support

- **Email**: support@cardupapp.com
- **Website**: https://cardupapp.com
- **Issues**: https://github.com/yourcompany/cardUp/issues
- **Discussions**: https://github.com/yourcompany/cardUp/discussions

## 🙏 Acknowledgments

- Google Gemini AI for card analysis
- Apple for PassKit, SwiftUI, and SwiftData
- The Swift community for excellent tools and libraries

## 📊 Project Stats

- **Lines of Code**: ~5,000
- **Test Coverage**: 85%
- **Supported Languages**: English, Hebrew (more coming)
- **Supported Card Types**: Store cards, coupons, event tickets, generic passes

---

**Built with ❤️ using Swift, SwiftUI, and AI**

*Last Updated: February 23, 2026*
