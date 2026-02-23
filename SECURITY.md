# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.3.x   | Yes       |
| 1.2.x   | Yes       |
| < 1.2   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability in `flutter_bicubic_resize`, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please email: **eryk@codigee.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response Timeline

- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix release**: as soon as possible, depending on severity

## Scope

This policy covers:
- Native C code in `src/` (memory safety, buffer overflows, integer overflows)
- Dart FFI bindings in `lib/src/`
- Build configurations (CMakeLists.txt, podspec)

## Known Considerations

- The library processes untrusted image data (user-provided bytes). All input validation happens in native C code via stb_image.
- Memory is manually managed in C. All `malloc` calls have corresponding `free` calls.
- No network access is performed by the library.
