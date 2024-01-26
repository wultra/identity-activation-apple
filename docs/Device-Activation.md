# Device Activation

With `WDOActivationService` you will be able to onboard PowerAuth with just a piece of user information like his email, phone number, or login name.

PowerAuth enrolled in such a way will need [further user verification](Verifying-User.md) until fully operational (able to sign operations). If the PowerAuth activation needs verification can be verified in the [activation flags](#Activation-Flags).

## WDOActivationService

The whole activation process is managed by the `WDOActivationService` class.

### Creating an instance

To create an instance you will need a `PowerAuthSDK` instance that is ready to be activated or a `WPNNetworkingService` with such a `PowerAuthSDK` instance. Optionally, you can choose if the activation process will persist between instance re-creation.

<!-- begin box info -->
[Documentation for `PowerAuthSDK`](https://github.com/wultra/powerauth-mobile-sdk)  
[Documentation for `WPNNetworkingService`](https://github.com/wultra/networking-apple/)
<!-- end -->


Example with `PowerAuthSDK` instance:

```swift
let powerAuth = PowerAuthSDK(configuration: ....)
let instance1 = WDOActivationService(
    powerAuth: powerAuth,
    config: WPNConfig(baseUrl: "https://sever.my/path/"),
    canRestoreSession: true
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
let instance1 = WDOActivationService(
    powerAuth: powerAuth,
    config: WPNConfig(baseUrl: "https://sever.my/path/"),
    canRestoreSession: true
)

```