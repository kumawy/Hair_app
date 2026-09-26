# App demo: current behavior and checks

The app uses English throughout. The non-functional language picker is hidden. Email/password and Google authentication and password reset use Firebase; Google requires the setup in [social sign-in](social-sign-in.md). The hairstyle preview displays a catalog reference photo, with a caption explaining that the user’s photo has not been edited (see `TODO(generation-api)`).

## Persistence

- Favorites and recent results use `SharedPreferencesAsync`, scoped by Firebase user ID or `guest`. They survive an app restart on the same installation and do not sync across devices. Guest favorites/history are kept separately when signing in.
- Finishing the scanner saves result metadata locally: timestamp, face shape, texture, length and source. No photos are written to preferences. Edited parameters update the same result; a new scan creates a new entry.
- A guest's current scanner result survives sign-in. Tapping **Save to profile** writes it to Firestore and also records it in the signed-in account's local history. Sign-out or switching between accounts clears the current scanner draft.
- Profile editing writes first name, last name and hair parameters together. An incomplete profile displays all available values. Failed saves retain edits and allow retry.
- If Firebase account creation succeeds but the profile document fails to save, the app reports that the account exists. The user can complete the profile in **Edit Profile**, without registering again.
- Theme preference persists on the device. English is the only supported interface language for now.

## Catalog and recommendations

Home's **See all** actions open the catalog or the full recommendations list. The account button opens Profile when signed in. Detail pages load by ID, including when opened without navigation extras; unknown IDs show a recovery action.

Length categories and the filter sheet share one selection. Reset clears both. Recommendations require matching catalog tags for face shape and texture, then rank by length. They are not shown as personalized without a complete profile. The limited catalog may yield only one match (currently Buzz Cut for coily hair). This is not an inference that only one hairstyle can suit that hair texture.

Curtains uses the existing center-part reference image also used by Middle Part; a separate editorial asset can be added later. Detail pages show description, lengths, maintenance and styling difficulty.

## Manual smoke check

Use a **full restart/rebuild**, not hot reload, after adding the preferences plugin.

1. Save a hairstyle from a card; open Favorites, open its details, remove it. Add it again and restart the app: it should remain.
2. Choose Short in Explore, then Long in the filter sheet. Results should use Long only. Reset and apply: all length categories should return.
3. Complete a manual scan as a guest. Sign in from the result: the result should remain. Save it; inspect Profile, Home recommendations and Recent Results. Restart and reopen the history.
4. Edit only one profile parameter and a name, save and reopen. Unset parameters should remain visible as unset. Retry a failed save without losing changes.
5. Switch the theme and restart. Open Help. On sign-in, test password-reset delivery with an account you control.
6. Open a haircut and Preview hairstyle: the animation and catalog reference photo should appear. No generation service is called.

Automated checks: `flutter analyze` and `flutter test`. Auth and persistence tests use fakes, not live credentials or real password-reset emails. The optional model integration test requires a separately running local server; see [Face Scanner](face-scanner.md).
