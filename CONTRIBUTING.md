# Contributing to flutter_bicubic_resize

Thank you for your interest in contributing! This guide will help you get started.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/erykkruk/BICUBIC_FLUTTER/issues) first
2. Open a new issue using the **Bug Report** template
3. Include: Flutter version, device/OS, minimal reproduction code, expected vs actual behavior

### Suggesting Features

1. Open an issue using the **Feature Request** template
2. Describe the use case and why it would be useful

### Submitting Code

1. Fork the repository
2. Create a branch from `main`: `git checkout -b feature/your-feature`
3. Make your changes
4. Run checks:
   ```bash
   flutter analyze
   dart format .
   flutter test
   ```
5. Commit with a clear message (e.g., `Add support for WebP format`)
6. Open a Pull Request against `main`

## Development Setup

```bash
git clone https://github.com/erykkruk/BICUBIC_FLUTTER.git
cd BICUBIC_FLUTTER
flutter pub get
```

### Running the example app

```bash
cd example
flutter pub get
flutter run
```

### Project Structure

- `src/` - Native C code (stb_image, bicubic resize logic)
- `lib/` - Dart FFI bindings and public API
- `ios/` - iOS build configuration (CMakeLists.txt)
- `android/` - Android build configuration (CMakeLists.txt)
- `test/` - Flutter tests
- `example/` - Demo app

### Working with Native Code

The core image processing is in C (`src/`). If you modify native code:

- Test on **both** iOS and Android
- Ensure no memory leaks (all `malloc` has matching `free`)
- Keep the API surface minimal (single FFI entry point per operation)

## Code Style

- Dart: follow `flutter_lints` rules defined in `analysis_options.yaml`
- C: keep functions small, document parameters, use `static` for internal functions
- No `print()` statements in library code
- No `dynamic` types in Dart

## Pull Request Guidelines

- Keep PRs focused on a single change
- Update `CHANGELOG.md` with your changes under an `## Unreleased` section
- Update `doc/api.md` if you change the public API
- Add tests for new functionality
- Ensure `flutter analyze` reports zero issues

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
