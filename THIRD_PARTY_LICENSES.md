# Third-Party Licenses

morphy includes libwebp 1.6.0 (Google/WebM Project), statically compiled from its official source release. The complete upstream license is retained in `Vendor/libwebp/COPYING` and included in the packaged app at `Contents/Resources/libwebp-LICENSE.txt`. Upstream patent terms are retained in `Vendor/libwebp/PATENTS`.

Source: https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz

Archive SHA-256: `e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564`.

The C sources are unmodified. A small public-header shim and SwiftPM target configuration integrate the encoding, decoding, mux, and SharpYUV components. No external codec installation is needed to run the packaged app.
