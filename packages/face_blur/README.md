# face_blur

Data layer. Takes a photo and pixelates every face in it on the phone, before anything is
uploaded. Face detection is ML Kit's (`google_mlkit_face_detection`): detection only, never
recognition. Phones only: ML Kit has no web version, so `isSupported` is `false` on web.

| Member | Does |
|---|---|
| `takePhoto(PhotoSource)` | Opens the camera or the gallery (`image_picker`); `null` when the person backs out |
| `retrieveLostPhoto()` | The photo the camera took while Android stopped the app, if any |
| `blur(TakenPhoto)` | Every face found pixelated, as a `BlurredPhoto`; the photo taken is deleted |
| `blurTappedFace(photo, x:, y:)` | One more face pixelated around a tap the detector missed |
| `close()` | Releases the detector |

How `blur` works (`docs/STACK.md` § Security):

1. `flutter_image_compress` writes an upright copy with no EXIF, its short side at most 2400 px.
2. `MlKitFaceDetector` finds the faces on that copy (accurate mode, faces down to 3% of the width).
3. In an isolate, `image` scales the photo to 1600 px on its long side, pixelates each face box
   grown by a quarter on every side (about 8 cells across), sets `exif = ExifData()` and encodes
   a JPEG.
4. The copy and the photo taken are deleted.

**Only a blurred photo can leave.** `TakenPhoto` is opaque: nothing outside this package reads its
pixels. `BlurredPhoto` is a `final class` whose only public constructor is `@visibleForTesting`,
so outside tests the only way to get one is `blur` or `blurTappedFace`. Code that uploads takes a
`BlurredPhoto` (`flyer_repository`).

The detector sits behind the `FaceDetector` interface; the ML Kit plugin is built on the first
detection, so nothing of it runs on web. It logs nothing. Only bootstrap constructs it.

## Tests

```sh
very_good test --coverage --min-coverage 100
```

Tests pass a fake `FaceDetector`, a mocked `ImagePicker` and in-memory files; one test runs the
default plugins over mocked method channels.
