# CardUp

Turn any physical card into an Apple Wallet pass. Snap a photo, let AI extract the details, and add it to Wallet in seconds.

## Overview

CardUp is an iOS app paired with a Node.js backend. The app uses on-device Vision and Apple Intelligence to scan physical cards (ID cards, membership cards, loyalty cards, etc.), extract their data, and generate signed `.pkpass` files that can be added to Apple Wallet.

## Features

- **Sign in with Apple** — secure, privacy-preserving authentication
- **Camera / Photo Library import** — scan any card with your iPhone camera
- **AI-powered data extraction** — Gemini 2.5 Flash reads text, barcodes, and layout from the card image
- **Apple Wallet integration** — generates cryptographically signed `.pkpass` files
- **Multiple pass types** — Generic, Store Card, Coupon, Event Ticket
- **Custom card design** — AI generates an SVG background inspired by the card's visual style
- **iCloud sync** — cards sync across devices via CloudKit / SwiftData
- **Subscription management** — free and Pro tiers via StoreKit 2
- **Hebrew support** — OCR and field extraction work with RTL text

## Tech Stack

### iOS Client (`Client/`)
| Technology | Purpose |
|---|---|
| SwiftUI | UI framework |
| SwiftData + CloudKit | Persistence and iCloud sync |
| AuthenticationServices | Sign in with Apple |
| Vision framework | On-device OCR and barcode scanning |
| Apple Intelligence / Foundation Models | Text parsing, logo identification |
| PassKit (`PKPass`, `PKAddPassesViewController`) | Apple Wallet integration |
| StoreKit 2 | In-app subscriptions |

### Backend Server (`Server/`)
| Technology | Purpose |
|---|---|
| Node.js + Express | HTTP server |
| `passkit-generator` | Cryptographic `.pkpass` signing |
| `@google/genai` (Gemini 2.5 Flash) | Card data extraction and design generation |
| `sharp` | Image resizing and compression |
| `multer` | Multipart image uploads |

## Project Structure

```
CardUp/
├── Client/                    # iOS Xcode project
│   └── CardUp/
│       ├── Models/            # User, Card (SwiftData models)
│       ├── Views/             # EntryScreen, HomeScreen, AddCard, EditCard, Profile
│       ├── Services/          # AuthenticationService, CardProcessingService,
│       │                      #   StorageManagerService, PaymentService
│       └── Integrations/      # PassKitIntegrator, CloudFlareIntegrator
└── Server/                    # Node.js backend
    ├── Server.js              # Express app entry point
    ├── routes/
    │   ├── GeminiApi.js       # POST /api/gemini/cardDataExtraction
    │   │                      # POST /api/gemini/cardDesignGenerating
    │   └── PassGeneration.js  # POST /generate-pass
    └── certs/                 # Apple signing certificates (not committed)
```

## Getting Started

### Prerequisites

- **iOS:** Xcode 16+, iOS 18+, an Apple Developer account (for PassKit certificates)
- **Server:** Node.js 20+

### Backend Setup

1. Install dependencies:
   ```bash
   cd Server
   npm install
   ```

2. Create a `.env` file in `Server/`:
   ```env
   PORT=3000
   GEMINI_API_KEY=your_google_gemini_api_key
   PASS_TYPE_IDENTIFIER=pass.com.yourteam.cardup
   TEAM_IDENTIFIER=YOUR_APPLE_TEAM_ID
   CERT_PASSPHRASE=your_p12_passphrase   # if your key is password-protected
   ```

3. Add Apple PassKit signing certificates to `Server/certs/`:
   - `signerCert.pem` — your Pass Type ID certificate
   - `signerKey.pem` — the private key
   - `wwdr.pem` — Apple WWDR intermediate certificate (G4)

4. Start the server:
   ```bash
   node Server.js
   # or for development with auto-reload:
   npx nodemon Server.js
   ```

### iOS Setup

1. Open `Client/CardUp.xcodeproj` in Xcode.
2. Set your development team and bundle identifier.
3. Update the server base URL in `CloudFlareIntegrator` to point at your running backend.
4. Build and run on a physical device (PassKit and Sign in with Apple require a real device).

## API Reference

### `POST /api/gemini/cardDataExtraction`
Accepts a card image (`multipart/form-data`, field: `file`) and returns structured card data as JSON.

**Response:**
```json
{
  "passFormat": "generic",
  "cardDetails": {
    "organizationName": "...",
    "primaryFields": [{ "key": "", "label": "", "value": "" }],
    "secondaryFields": [],
    "auxiliaryFields": [],
    "backFields": [],
    "barcodeMessage": "...",
    "barcodeFormat": "PKBarcodeFormatCode128"
  }
}
```

### `POST /api/gemini/cardDesignGenerating`
Accepts a card image and returns an SVG string (1125×432 px) inspired by the card's visual style.

**Response:**
```json
{ "designSvg": "<svg>...</svg>" }
```

### `POST /generate-pass`
Accepts a JSON payload from the iOS app and returns a signed `.pkpass` binary.

**Content-Type:** `application/json`  
**Response Content-Type:** `application/vnd.apple.pkpass`

Key payload fields (all snake_case, iOS JSONEncoder convention):

| Field | Type | Description |
|---|---|---|
| `organization_name` | String | Card issuer name |
| `pass_style` | String | `generic`, `storeCard`, `coupon`, or `eventTicket` |
| `logo_image_data` | String | Base64-encoded logo/icon PNG |
| `banner_image_data` | String | Base64-encoded banner PNG |
| `foreground_color` | String | Hex color (e.g. `#FFFFFF`) |
| `background_color` | String | Hex color |
| `primary_fields` | Array | PassKit primary fields |
| `secondary_fields` | Array | PassKit secondary fields |
| `barcode_message` | String | Barcode payload |
| `barcode_format` | String | e.g. `PKBarcodeFormatQR` |

## Certificate Setup (Apple PassKit)

1. In the Apple Developer portal, create a **Pass Type ID** (e.g. `pass.com.yourteam.cardup`).
2. Generate a certificate for that Pass Type ID and download it.
3. Export the certificate + private key as a `.p12` file from Keychain Access.
4. Convert to PEM format:
   ```bash
   openssl pkcs12 -in Certificates.p12 -clcerts -nokeys -out signerCert.pem
   openssl pkcs12 -in Certificates.p12 -nocerts -nodes  -out signerKey.pem
   ```
5. Download the Apple WWDR G4 certificate and convert it:
   ```bash
   openssl x509 -inform der -in AppleWWDRCAG4.cer -out wwdr.pem
   ```
6. Place all three `.pem` files in `Server/certs/`.

## License

Private — all rights reserved.
