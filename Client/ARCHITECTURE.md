# CardUp – Architecture

## File Layout
* **HomeScreen**
* **Models/**
    * User
    * Card
* **Views/**
    * EntryScreen
    * HomeScreen
    * Profile
    * AddCard
    * EditCard
* **Services/**
    * AuthenticationService
    * CardProcessingService
    * SorageManagerService
    * PaymentManagerService
* **Integrations/**
    * PassKitIntegrator
    * CloudFlareIntegrator

---

## Views

### EntryScreen
When the user fo not sign in there’s welcome screen with buttons to sign in/up via apple id 

### HomeScreen
all the cards of the user divided by cards that have been added to wallet and draft. On the buttom there is liquid glass search bar and button to add new card. and on the top small profile icon

### Profile
Shows the user’s name, Subscrioption type (free/pro) and option to sign out and manage subscription

### AddCard
Button to take picture of upload picture, functionallty to retake/reupload/confirm. When confirmed an anomation shows while the app scanning and generating the card behind the scence, when done movw automaticlly to efit

### EditCard
Fields and text boxes that automaticlly filed with the generated content with the abillity to change, texts, banner images, colors

---

## Models

### User
Saves user basic info
* **Variables:**
    * `appleUserId`: String (Unique, stable identifier for the user).
    * `firstName`: String? (Provided only on first login).
    * `lastName`: String? (Provided only on first login).
    * `email`: String? (Provided only on first login, might be a proxy email).

### Card
* **Variables:**
    * `id`: UUID (Unique identifier for database and CloudKit sync).
    * `passType`: String (The PassKit format, e.g., storeCard, generic).
    * `extractedTextJson`: String (Text parsed via Vision framework and Apple Intelligence in json format with card name, company name, date).
    * `barcodeString`: String (The decoded payload of the scanned barcode/QR).
    * `barcodeFormat`: String (The format of the barcode, e.g., QR, Code128).
    * `dominantColorsHex`: String[] (array with Hex codes extracted for UI and pass background).
    * `isDraft`: Bool (Determines if the card is in the editing phase or finalized in the Wallet).
    * `creationDate`: Date (Timestamp for sorting on the HomeScreen).

---

## Services

### AuthenticationService
(ObservableObject / @Observable) Manages the Sign in with Apple lifecycle, credential validation, and user session state.
* **Variables:**
    * `isAuthenticated`: Bool (Determines which root view to show).
    * `currentUser`: AppUser? (Holds the active user's data).
* **Functions:**
    * `handleAuthorization(result: Result<ASAuthorization, Error>)`: 
        * **Purpose:** Processes the callback from the native Apple login prompt.
        * **Functionality:** Casts the ASAuthorization credential to ASAuthorizationAppleIDCredential. Extracts the useridentifier, fullName, and email. Saves the appleUserId securely to the Keychain. Updates currentUser and sets isAuthenticated to true.
    * `verifySession()`:
        * **Purpose:** Checks if the user's Apple ID session is still valid across app launches.
        * **Functionality:** Retrieves the saved appleUserId from the Keychain. Uses ASAuthorizationAppleIDProvider().getCredentialState(forUserID:) to check if the state is .authorized. Updates isAuthenticated accordingly.
* **Integrations:** AuthenticationServices framework, Keychain (for secure ID storage).

### CardProcessingService
The central coordinator linking camera output, optical recognition, AI parsing, and color extraction.
* **Variables:**
    * `@Published var isProcessing: Bool`: Controls UI loading states.
    * `@Published var extractedData: ExtractedCardData?`: Triggers view navigation when populated.
* **Functions:**
    * `processCard(image: UIImage) async`:
        * **Purpose:** Orchestrates the asynchronous data pipeline.
        * **Functionality:** Sets isProcessing to true. Spawns tasks to call VisionService.performOCR(on:) and ColorAnalyzer.extractDominantColor(from:) concurrently. Takes the resulting OCR string and passes it to the Apple Intelligence text API to identify the parsedName and parsedNumber. Constructs an ExtractedCardData object with the combined results. Dispatches the assignment of extractedData to the MainActor to update the SwiftUI view hierarchy safely.
    * `generateCardType(image)`: recive a picture and scan it using vision framework and choosing which passkit card format to select
    * `fetchText(image)`: recive a picture and fetching text via vision framework with hebrew support and orgonize it via foundation model
    * `createGraphic(image)`: recive a picture and generate description of the grapic design via foundation model and Recreating the graphics via core 
    * `fetchColors(image)`: recive a picture and scan it using vision framework and outputs the dominant colors.
    * `getLogo(image)`: recive a picture and scan it using vision framework and idenifing the logo via foundation model. Search the logo via google API and get high qualty svg or png 
    * `generateCard(image)`: pass the image to the other function and create .pkpass from the information. Set the output from createGraphic(imag)as card banner picture. Set the output from fetchColors (imag)as gradient card background. Set the output from getLogo (imag)as the card logo. Set the output from fetchText(image) as the card text.

### StorageManagerService
Handle storing on icloud via iCloudKit
* **Variables:**
    * `modelContext`: ModelContext: Manages the active, in-memory objects.
* **Functions:**
    * `saveCard(card: Card)`: Inserts the newly generated or edited card into the context. SwiftData handles the automatic push to iCloud.
    * `deleteCard(card: Card)`: Removes the local record and queues the deletion for CloudKit.
    * `fetchCards(isDraft: Bool) -> [Card]`: Queries the local database to populate the HomeScreen sections.

### PaymentService
StoreKit 2. Fully native, secure, and requires no external backend server for basic subscription validation and entitlement checking.
* **Variables:**
    * `@Published var hasProAccess: Bool`: Toggles the Pro features across the app views.
    * `@Published var subscriptions: [Product]`: Holds the fetched App Store Connect subscription tiers.
* **Functions:**
    * `loadProducts() async`: Retrieves the available premium subscription products from Apple's servers.
    * `purchase(product: Product) async throws`: Triggers the native Apple Pay sheet and cryptographically verifies the resulting transaction.
    * `updateSubscriptionStatus() async`: Runs on app launch to verify the user's current active entitlements and updates hasProAccess.
    * `restorePurchases() async`: Required by Apple Review guidelines to let users recover past subscriptions on a new device.

---

## Integrations

### PassKitIntegrator
Cryptographically compiles database records into Apple-certified Wallet passes.
* **Functions:**
    * `requestPassGeneration(for card: ScannedCard) async throws -> PKPass`: Packages the extracted text, barcode string, dominant color, and parsed domain into a JSON payload. Sends a POST request to the Cloudflare Worker endpoint. Awaits the binary response, initializes a PKPass(data:) object, and triggers the PKAddPassesViewController.

### CloudFlareIntegrator
* **Functions:**
    * `getLogo(domain)`: Moved to the serverless backend. Uses HTMLRewriter to fetch the logo securely without exposing API keys or consuming device resources.
    * `generateCard(payload)`: Moved to the serverless backend. Compiles and cryptographically signs the .pkpass file securely using Apple Developer certificates, which cannot be done on-device.
