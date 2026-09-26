# Google sign-in

The login screen uses real Firebase authentication flows, not a demo: Google Sign-In 7 obtains an ID token on Android/iOS, Firebase verifies it. Web uses Firebase popups. Native desktop is not configured.

Canceling leaves the user on the login screen. Concurrent requests are disabled. A successful login returns to the requesting screen, including a guest scanner draft. Firestore profile initialization is transactional and fills only missing fields; existing names and hair parameters are not overwritten. If profile storage fails after authentication, the app reports that the user is signed in and can finish their profile later. No provider tokens or private keys are stored in preferences.

## Current setup status

Run `python3 tool/configure_social_auth.py` to check the local Google configuration. This read-only check does not enable providers in Firebase or verify a live login.

## Google

1. Open [Authentication / Sign-in method](https://console.firebase.google.com/project/hair-app-1172f/authentication/providers) for project `hair-app-1172f`. Enable Google and choose the project's support email.
2. For Android app `com.example.hair_app`, add the signing certificate SHA-1 and SHA-256 in Firebase project settings. Run `cd android` and `./gradlew signingReport` to inspect local build fingerprints. Configure Play App Signing/release fingerprints separately before distribution.
3. Download fresh configs for the registered apps:
   - iOS bundle `com.muratovaslan.hairApp`: replace `ios/Runner/GoogleService-Info.plist`.
   - Android package `com.example.hair_app`: replace `android/app/google-services.json`. It must contain a web OAuth client (`client_type: 3`).
4. Run from the project root:

   ```sh
   python3 tool/configure_social_auth.py --google
   ```

   This copies the public iOS client ID and reversed callback scheme into `ios/Runner/Info.plist`, preserving unrelated URL schemes. Android reads its config through the existing Google Services Gradle plugin.
5. Fully rebuild the application. Hot reload cannot register the Google SDK or URL scheme.

References: [Firebase Flutter social sign-in](https://firebase.google.com/docs/auth/flutter/federated-auth), [Google Sign-In iOS setup](https://pub.dev/packages/google_sign_in_ios), [Android setup](https://pub.dev/packages/google_sign_in_android).

## Check and test

`python3 tool/configure_social_auth.py` is read-only and prints the local configuration status. It cannot verify console/provider enablement or signing certificates.

Automated tests use fake provider responses and Firestore transactions. They never open a real consent screen or create a real account. On a configured phone, additionally check Google account selection, cancellation, repeat login after editing the profile, sign-out/re-login and returning to the scanner result.
