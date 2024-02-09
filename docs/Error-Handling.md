# Error Handling

Errors produced by this library are of type `WPNError` that comes from our networking layer. For more information visit [the library documentation](https://github.com/wultra/digital-onboarding-apple).


## Custom Digital Onboarding Error Reasons

In addition to pre-defined error reasons available in the networking library, we offer more reasons to further offer better error handling.

### Errors in `WDOActivationService`

#### Custom `WPNErrorReason` values

| Option Name | Description |
|---|---|
|`wdo_activation_inProgress`|Activation is already in progress|
|`wdo_activation_notRunning`|Activation was not started.|
|`wdo_activation_cannotActivate`|PowerAuth instance cannot start the activation (probably already activated).|

#### Extensions of `WPNError`

After the user entered the wrong OTP and an error was raised, you can retrieve the following information from the error:

- `onboardingOtpRemainingAttempts` - How many more OTP attempts are possible.
- `allowOnboardingOtpRetry` - If the user should be allowed to repeat the OTP or activation needs to be started again

### Errors in `WDOVerificationService`

#### Custom `WPNErrorReason` values

| Option Name | Description |
|---|---|
|`wdo_verification_activationNotActive`|Powerauth instance is not active. Verification can only happen when the user already activated the PowerAuth instance.|
|`wdo_verification_missingStatus`|Verification status is unknown. Please make sure that the status was at least once successfully fetched before calling any other method.|
|`wdo_verification_otpFailed`|OTP failed to verify.|

## Read next

- [Language Configuration](Language-Configuration.md)