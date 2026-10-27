# auth_repository

Repository layer. Signs people in to Ronda with **Google only** over Firebase Auth, and reports
who is signed in. No phone, email or anonymous sign-in.

Depends on `firebase_auth` and `equatable`. `FirebaseAuth` is built in bootstrap (pointed at the
Auth emulator in the development flavor) and passed in; this package never reads the platform or
the flavor itself.

## API

| Member | Does |
|---|---|
| `AuthRepository(firebaseAuth: FirebaseAuth, googleSignInFlow: GoogleSignInFlow)` | Built in bootstrap; tests pass `MockFirebaseAuth` or a mocktail mock |
| `Stream<User> user` | The signed-in `User`, or `User.empty`, on every sign-in and sign-out |
| `User currentUser` | Who is signed in now; `User.empty` when nobody is |
| `Future<void> signInWithGoogle()` | Signs in through the flow below; throws `SignInWithGoogleFailure` |
| `Future<void> signOut()` | Throws `SignOutFailure` when Firebase Auth fails |
| `AuthRepository.emulatorAccount` | The invented demo account (`vecina@example.com`) the emulator credential signs in as |

## GoogleSignInFlow

- `popup`: `signInWithPopup(GoogleAuthProvider())`, the web.
- `provider`: `signInWithProvider(GoogleAuthProvider())`, Android and iOS.
- `emulatorCredential`: `signInWithCredential` with an unsigned JSON id token. Only the Auth
  emulator accepts it, and only `main_development.dart` can pick it.

How each one reaches the Auth emulator: `docs/STACK.md` § Native and project checklist.

## Models and failures

- `User(id)`: the Firebase uid only. Ronda knows people by the first name they give in
  onboarding, so no Google name, email or photo is carried.
- `SignInWithGoogleFailure(reason)`: `cancelled` (the person closed the picker), `network`,
  `userDisabled`, `unknown`. Mapped from Firebase Auth error codes by `fromCode`.
- `SignOutFailure`.
