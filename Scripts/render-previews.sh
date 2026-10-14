#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-module-cache"
swift build
build_dir="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$build_dir/Modules" \
    -Xcc "-fmodule-map-file=$build_dir/CWebP.build/module.modulemap" \
    "$project_dir/Scripts/render-previews.swift" \
    "$project_dir/Sources/MorphyApp/Application/AppEnvironment.swift" \
    "$project_dir/Sources/MorphyApp/Application/AppPreferences.swift" \
    "$project_dir/Sources/MorphyApp/Application/AppResources.swift" \
    "$project_dir/Sources/MorphyApp/Application/AppState.swift" \
    "$project_dir/Sources/MorphyApp/Presentation/PixelWorld/PixelWorldViews.swift" \
    "$project_dir/Sources/MorphyApp/Presentation/MenuBar/MenuBarRootView.swift" \
    "$build_dir/MorphyApp.build/DerivedSources/resource_bundle_accessor.swift" \
    "$build_dir"/MorphyCore.build/*.o \
    "$build_dir"/CWebP.build/**/*.o \
    -o "$build_dir/MorphyPreviewExporter"
"$build_dir/MorphyPreviewExporter" "$project_dir/artifacts/previews" "$@"
