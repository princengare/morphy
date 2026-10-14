#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/artifacts/previews/menu-bar.png" \
    -vf "pad=1520:1520:(ow-iw)/2:(oh-ih)/2:color=white" \
    -frames:v 1 "$project_dir/artifacts/previews/menu-bar-video.png"
ffmpeg -hide_banner -loglevel error -y \
    -f concat -safe 0 -i "$project_dir/Scripts/walkthrough.ffconcat" \
    -vf "scale=840:840:force_original_aspect_ratio=decrease:flags=neighbor,pad=1280:960:(ow-iw)/2:60+(840-ih)/2:color=0x202224,fps=30,drawtext=fontfile=/System/Library/Fonts/Menlo.ttc:text='morphy - visual walkthrough':x=40:y=20:fontsize=22:fontcolor=white,drawtext=fontfile=/System/Library/Fonts/Menlo.ttc:text='Rendered app screens - development build':x=40:y=915:fontsize=18:fontcolor=0xbfc5c9" \
    -t 24 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
    -movflags +faststart "$project_dir/artifacts/morphy-walkthrough.mp4"
