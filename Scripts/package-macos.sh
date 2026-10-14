#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-module-cache"
swift build -c release
build_dir="$(swift build -c release --show-bin-path)"
dist_dir="$project_dir/dist"
mkdir -p "$dist_dir"
# Preserve the lowercase bundle before creating the Finder name on case-insensitive disks.
for existing_app in "$dist_dir"/*.app(N); do
    if [[ "${existing_app:t}" == "morphy.app" ]]; then
        previous_dir="$(mktemp -d "$dist_dir/.previous-app.XXXXXX")"
        mv "$existing_app" "$previous_dir/morphy.app"
    fi
done
app_dir="$dist_dir/Morphy.app"
app_version="$(plutil -extract CFBundleShortVersionString raw -o - "$project_dir/Packaging/Info.plist")"
package_name="morphy-$app_version-apple-silicon.zip"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/Morphy" "$app_dir/Contents/MacOS/Morphy"
cp -R "$build_dir/Morphy_MorphyApp.bundle" "$app_dir/Contents/Resources/"
cp "$project_dir/Packaging/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Vendor/libwebp/COPYING" "$app_dir/Contents/Resources/libwebp-LICENSE.txt"
swift "$project_dir/Scripts/make-icon.swift" \
    "$project_dir/Sources/MorphyApp/Resources/logo-color.png" \
    "$dist_dir/Morphy.iconset"
iconutil -c icns "$dist_dir/Morphy.iconset" -o "$app_dir/Contents/Resources/Morphy.icns"
codesign --force --sign - --options runtime "$app_dir"
codesign --verify --deep --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" \
    "$dist_dir/$package_name"

# Keep the public download and its Git exception aligned with the successful build.
metadata_tmp=""
trap '[[ -z "$metadata_tmp" ]] || rm -f "$metadata_tmp"' EXIT
for metadata_file in "$project_dir/.gitignore" "$project_dir/README.md"; do
    metadata_tmp="$(mktemp "$metadata_file.XXXXXX")"
    cp -p "$metadata_file" "$metadata_tmp"
    awk -v version="$app_version" -v package="$package_name" '
        {
            gsub(/morphy-[0-9]+[.][0-9]+[.][0-9]+-apple-silicon[.]zip/, package)
            sub(/\*\*Current version: [0-9]+[.][0-9]+[.][0-9]+/, "**Current version: " version)
            if ($0 ~ /^\| Version \|/) $0 = "| Version | " version " |"
            print
        }
    ' "$metadata_file" > "$metadata_tmp"
    mv "$metadata_tmp" "$metadata_file"
    metadata_tmp=""
done
print "Packaged $app_dir"
print "Ready for GitHub: dist/$package_name"
