# Firebase

Configured externally:

- Firebase project created from the Google Cloud project.
- Android and iOS apps registered.
- `mobile/android/app/google-services.json` is already present locally.

Backend/runtime:

- Use environment variables for `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY`.
- Do not commit service-account JSON files.

Planned use:

- FCM for tournament updates, registration updates, reminders, and invitations.

