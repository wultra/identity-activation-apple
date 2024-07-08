# Verifyng user

If your PowerAuthSDK instance was activated with the `WDOActivationService`, it will be in the state that needs additional verification. Without such verification, it won't be able to properly sign requests.

Additional verification means that the user will need to scan his face and documents like ID and/or passport.

## When is the verification needed?

Verification is needed if the `activationFlags` in the `PowerAuthActivationStatus` contains `VERIFICATION_PENDING` or `VERIFICATION_IN_PROGRESS` value.

These values can be accessed via the extension methods `verificationPending` and `verificationInProgress` or just simply `needVerification` if one of them is true.

Example:

```swift
import WultraDigitalOnboarding
import PowerAuth2

let powerAuth: PowerAuthSDK // configured and activated PowerAuth instance

powerAuth.fetchActivationStatus { status, error in
    if let error = error {
        // handle error
    } else if let status = status {
        // note that `needVerification` property is an extension
        // from the `WultraDigitalOnboarding` space
        if status.needVerification {
            // navigate to the verification flow 
            // and call `WDOVerificationService.status`
        } else {
            // handle PA status
        }
    }
}

```

## Example app flow

<p align="center"><img src="images/verification-mockup.png" alt="Example verification flow" width="100%" /></p>

<!-- begin box info -->
This mockup shows a __happy user flow__ of an example setup. Your usage may vary.   
The final flow (which screens come after another) is controlled by the backend.
<!-- end -->

## Server driven flow

- The screen that should be displayed is driven by the state on the server "session".   
- At the beginning of the verification process, you will call the status which will tell you what to display to the user and which function to call next.
- Each API call returns a result and a next screen to display.
- This repeats until the process is finished or an "endstate state" is presented which terminates the process.

## Possible state values

State is defined by the `WDOVerificationState` enum with the following possibilities:

```swift
/// State which should be presented to the user. Each state represents a separate screen UI that should be presented to the user.
enum WDOVerificationState {
    
    /// Show the verification introduction screen where the user can start the activation.
    ///
    /// The next step should be calling the `getConsentText`.
    case intro
    
    /// Show approve/cancel user consent.
    /// The content of the text depends on the server configuration and might be plain text or HTML.
    ///
    /// The next step should be calling the `consentApprove`.
    case consent(_ body: String)
    
    /// Show document selection to the user. Which documents are available and how many
    /// can the user select is up to your backend configuration.
    ///
    /// The next step should be calling the `documentsSetSelectedTypes`.
    case documentsToScanSelect
    
    /// User should scan documents - display UI for the user to scan all necessary documents.
    ///
    /// The next step should be calling the `documentsSubmit`.
    case scanDocument(_ process: WDOVerificationScanProcess)
    
    /// The system is processing data - show loading with text hint from provided `ProcessingItem`.
    ///
    /// The next step should be calling the `status`.
    case processing(_ item: ProcessingItem)
    
    /// The user should be presented with a presence check.
    /// Presence check is handled by third-party SDK based on the project setup.
    ///
    /// The next step should be calling the `presenceCheckInit` to start the check and `presenceCheckSubmit` to
    /// mark it finished  Note that these methods won't change the status and it's up to the app to handle the process of the presence check.
    case presenceCheck
    
    /// Show enter OTP screen with resend button.
    ///
    /// The next step should be calling the `verifyOTP` with user-entered OTP.
    /// The OTP is usually SMS or email.
    case otp(_ remainingAttempts: Int?)
    
    /// Verification failed and can be restarted
    ///
    /// The next step should be calling the `restartVerification` or `cancelWholeProcess` based on
    /// the user's decision if he wants to try it again or cancel the process.
    case failed
    
    /// Verification is canceled and the user needs to start again with a new PowerAuth activation.
    ///
    /// The next step should be calling the `PowerAuthSDK.removeActivationLocal()` and starting activation from scratch.
    case endstate(_ reason: EndstateReason)
    
    /// Verification was successfully ended. Continue into your app
    case success
}
```

## Creating an instance

To create an instance you will need a `PowerAuthSDK` instance that is __already activated__ or a `WPNNetworkingService` with such a `PowerAuthSDK` instance.

<!-- begin box info -->
[Documentation for `PowerAuthSDK`](https://github.com/wultra/powerauth-mobile-sdk).  
[Documentation for `WPNNetworkingService`](https://github.com/wultra/networking-apple/).
<!-- end -->


Example with `PowerAuthSDK` instance:

```swift
let powerAuth = PowerAuthSDK(configuration: ....)
let verification = WDOVerificationService(
    powerAuth: powerAuth,
    config: WPNConfig(baseUrl: "https://sever.my/path/")
)
```

Example with `WPNNetworkingService ` instance:

```swift
let powerAuth = PowerAuthSDK(configuration: ....)
let networking = WPNNetworkingService(
    powerAuth: powerAuth, // configured PowerAuthSDK instance
    config: WPNConfig(baseUrl: "https://sever.my/path/"),
    serviceName: "MyProjectNetworkingService", // for better debugging
    acceptLanguage: "en" // more info in "Language Configuration" docs section
)
let verification = WDOVerificationService(
    networking: networking
)
```

## Getting the verification status

When entering the verification flow for the first time (for example fresh app start), you need to retrieve the state of the verification.

The same needs to be done after some operation fails and it's not sure what is the next step in the verification process.

Most verification functions return the result and also the state for your convenience of "what next".

Getting the state directly:

```swift
let verification: WDOVerificationService // configured instance
verification.status { result in 
    switch result {
    case .success(let state):
        // handle `WDOVerificationState` state and navigate to the expected screen
        break
    case .failure(let error):
        if let state = error.state {
            // show expected screen based on the state
        } else {
            // navigate to error screen and show the error in
            // error.cause
        }
    }
}
```

## Getting the user consent text

When the state is `intro`, the first step in the flow is to get the context text for the user to approve.

```swift
let verification: WDOVerificationService // configured instance
verification.consentGet { result in 
    switch result {
    case .success(let state):
        // state will be in the `consent` case here - display the consent screen
        break
    case .failure(let error):
        if let state = error.state {
            // show expected screen based on the state
        } else {
            // navigate to the error screen and show the error in
            // error.cause
        }
    }
}
```

## Approving the user consent

When the state is `consent`, you should display the consent text to the user to approve or reject.

If the user __rejects the consent__, just return him to the intro screen, there's no API call for reject.

If the user chooses to accept the consent, call `consentApprove` function. If successful, `documentsToScanSelect` state will be returned.

```swift
let verification: WDOVerificationService // configured instance
verification.consentApprove { result in 
    switch result {
    case .success(let state):
        // state will be in the `documentsToScanSelect` case here - display the document selector
        break
    case .failure(let error):
        if let state = error.state {
            // show expected screen based on the state
        } else {
            // navigate to the error screen and show the error in
            // error.cause
        }
    }
}
```

## Set document types to scan

After the user approves the consent, present a document selector for documents which will be scanned. The number and types of documents (or other rules like 1 type required) are completely dependent on your backend system integration, frontend SDK does not provide any hint for this configuration.

For example, your system might require a national ID and one additional document like a driver's license, passport, or any other government-issued personal document.

```swift
let verification: WDOVerificationService // configured instance
let documentsToScan: [WDODocumentType] = [.idCard, .driversLicense]
verification.documentsSetSelectedTypes(types: documentsToScan) { result in 
    switch result {
    case .success(let state):
        // state will be in the `scanDocument` case here - display the document scanner
        break
    case .failure(let error):
        if let state = error.state {
            // show expected screen based on the state
        } else {
            // navigate to the error screen and show the error in
            // error.cause
        }
    }
}
```

## Configuring the "Document Scan SDK"

<!-- begin box info -->
This step does not move the state of the process but is a "stand-alone" API call.
<!-- end -->

Since the document scanning itself is not provided by this library but by a 3rd party library, some of them need a server-side initialization.

If your chosen scanning SDK requires such a step, use this function to retrieve necessary data from the server.

ZenID RecogLib_iOS integration example:

```swift
let verification: WDOVerificationService // configured instance

let documentsToScan = [WDODocumentType.idCard, .driversLicense]
    
verification.documentsSetSelectedTypes(types: documentsToScan) { result in
    switch result {
    case .success(let result):
        // state will be in the `scanDocument` case here - tell the user to start scanning required documents
        // in the `scanDocument` case, process object `WDOVerificationScanProcess` is present which will
        // tell you the status of each document and also provide you `nextDocumentToScan` - the document that should be scanned next
        break
    case .failure(let error):
        // handle error
        break
    }
}
```

## Scanning a document

When the state of the process is `scanDocument` with the `WDOVerificationScanProcess` parameter, you need to present a document scan UI to the user. This UI needs
to guide through the scanning process - scanning one document after another and both sides (if the document requires so).

The whole UI and document scanning process is up to you and the 3rd party library you choose to use.

<!-- begin box warning -->
This step is the most complicated in the process as you need to integrate this SDK, another document-scanning SDK, and integrate your server-side expected logic. To
make sure everything goes as smoothly as possible, ask your project management to provide you with a detailed description/document of the required scenarios and expected documents
for your implementation.
<!-- end -->

## Uploading a document

When a document is scanned (both sides when required), it needs to be uploaded to the server.

<!-- begin box warning -->
__Images of the document should not be bigger than 1MB. Files that are too big will take longer time to upload and process on the server.__
<!-- end -->

To upload a document, use `documentsSubmit` function. Each side of a document is a single `WDODocumentFile` instance.

Example:

```swift
let verification: WDOVerificationService // configured instance

let passportToUpload = WDODocumentFile(
    data: Data(...), // raw image data from the document scanning library/photo camera
    type: WDODocumentType.passport,
    side: WDODocumentSide.front, // passport has only front side
    originalDocumentId: nil, // use only when re-uploading the file (for example when first upload was rejected because of a blur)
    dataSignature: nil // optional, use when provided by the document scanning library
)

verification.documentsSubmit(
    types: [passportToUpload],
    progressCallback: { percentUploadProgress in
        // report upload progress
    }
) { result in
    switch result {
    case .success(let result):
        // state here will be "processing" - telling you that the file is being processed on the server
        break
    case .failure(let error):
        // handle error
        break
    }
}

```

### `WDODocumentFile`

```swift
class WDODocumentFile {
    /// Raw data to upload. Make sure that the data aren't too big, hundreds of kbs should be enough.
    public var data: Data
    /// Image signature. Use only when the scan SDK supports this.
    public var dataSignature: String?
    /// Type of the document (for example .idCard).
    public let type: WDODocumentType
    /// Side of the document (`front` if the document is one-sided or only one side is expected).
    public let side: WDODocumentSide
    /// For image reuploading when the previous file of the same document was rejected.
    /// Without specifying this value, the document side won't be overwritten.
    public let originalDocumentId: String?
    
    /// Image of a document that can be sent to the backend for Identity Verification.
    ///
    /// - Parameters:
    ///   - scannedDocument: Document to upload.
    ///   - data: Raw image data.  Make sure that the data aren't too big, hundreds of kbs should be enough.
    ///   - side: The side of the document that the image captures.
    ///   - dataSignature: Signature of the image data. Optional, use only when the scan SDK supports this. `nil` by default.
    public convenience init(scannedDocument: WDOScannedDocument, data: Data, side: WDODocumentSide, dataSignature: String? = nil)
    
    /// Image of a document that can be sent to the backend for Identity Verification.
    ///
    /// - Parameters:
    ///   - data: Raw image data.  Make sure that the data aren't too big, hundreds of kbs should be enough.
    ///   - type: The type of the document.
    ///   - side: The side of the document the the image captures
    ///   - originalDocumentId: Original document ID In case of a reupload. If you've previously uploaded this type and side and won't specify the previous ID, the image won't be overwritten.
    ///   - dataSignature: Signature of the image data. Optional, use only when the scan SDK supports this. `nil` by default.
    public convenience init(data: Data, type: WDODocumentType, side: WDODocumentSide, originalDocumentId: String?, dataSignature: String? = nil)
}
```

<!-- begin box info -->
To create an instance of the `WDODocumentFile`, you can use `WDOScannedDocument.createFileForUpload`. The `WDOScannedDocument` is returned in the process status as a "next document to scan".
<!-- end -->

## Presence check

To verify that the user is present in front of the phone, a presence check is required. This is suggested by the `presenceCheck` state.

When this state is obtained, the following steps need to be done:

1. Call `presenceCheckInit` to initialize the presence check on the server. This call returns a dictionary of necessary data for the presence-check library to initialize.
2. Make the presence check by the third-party library
3. After the presence check is finished, call `presenceCheckSubmit` to tell the server you finished the process on the device.

## Verify OTP

After the presence check is finished, the user will receive an SMS/email OTP and the `otp` state will be reported. When this state is received, prompt the user for the OTP and verify it via `verifyOTP` method.

The `otp` state also contains the number of possible OTP attempts. When attempts are depleted, the error state is returned.

Example:

```swift
let verification: WDOVerificationService // configured instance

let userOTP = "123456"

verification.verifyOTP(otp: userOTP) { result in
    switch result {
    case .success(let result):
        // React to a new state returned in the result
        break
    case .failure(let error):
        // handle error
        break
    }
}
```

## Success state

When a whole verification is finished, you will receive the `success` state. Show a success screen and navigate the user to a common activated flow.

At the same time, the verification flags from the PowerAuth status are removed.

## Failed state

When the process fails, a `failed` state is returned. This means that the current verification process has failed and the user can restart it (by calling the `restartVerification` function) and start again (by showing the intro).

## Endstate state

When the activation is no longer able to be verified (for example did several failed attempts or took too long to finish), the `endstate` state is returned. In this state there's nothing the user can do to continue. `cancelWholeProcess` shall be called and `removeActivationLocal` should be called on the PowerAuthSDK object. After that, user should be put inti the "fresh install state".

## Read next

- [Error Handling](Error-Handling.md)