# Logging

SDK uses `WDOLogger` class that prints to the console.

<!-- begin box info -->
Networking traffic is logged in its own logger described in the [networking library documentation](https://github.com/wultra/networking-apple).
<!-- end -->

### Verbosity Level

You can limit the amount of logged information via `verboseLevel` property.

| Level | Description |
| --- | --- |
| `off` | Silences all messages. |
| `errors` | Only errors will be printed to the debug console. |
| `warnings` _(default)_ | Errors and warnings will be printed to the debug console. |
| `all` | All messages will be printed to the debug console. |