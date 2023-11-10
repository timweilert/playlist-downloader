#!/bin/bash

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
    echo "Error: yt-dlp is not installed. Please install it first."
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it first."
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Check if the input URL is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a YouTube playlist URL as an argument."
    exit 1
fi

# Fetch the HTML content of the playlist page
playlist_html=$(curl -s "$1")

# Extract the playlist name using grep
playlist_name=$(echo "$playlist_html" | grep -oP '<title>\K[^<]+' | sed 's/ - YouTube$//')

# Echo the playlist name
echo "Playlist Name: $playlist_name"

# Create a directory for the playlist
mkdir -p "$playlist_name"

# Run yt-dlp to download best quality audio
yt-dlp -x --audio-format best --audio-quality 0 --playlist-items 1- --write-info-json -o "$playlist_name/%(playlist_index)s - %(title)s.%(ext)s" "$1"

# Change into the playlist directory
cd "$playlist_name" || exit 1

# Get the extension of the last non-JSON file
last_file=$(ls -t | grep -v '\.json$' | head -n1)
last_extension="${last_file##*.}"

# Loop through files with the determined extension and apply metadata using ffmpeg
for file in *."$last_extension"; do
    index=$(echo "$file" | awk '{print $1}')
    title=$(echo "$file" | cut -d' ' -f3- | sed 's/\.[^.]*$//' | sed 's/^ - //')
    video_info=$(yt-dlp --dump-json --playlist-items "$index" "$1")
    release_year=$(echo "$video_info" | jq -r '.upload_date[0:4]')
	channel=$(echo "$video_info" | jq -r '.uploader')
    album=$(echo "$playlist_name" | sed 's/\.[^.]*$//')  # Use playlist name as album

	# Remove channel name from title and leading spaces/hyphens
	title_no_channel=$(echo "$title" | sed -E "s/\b$channel\b//i" | sed -E 's/^[[:space:]]*-?[[:space:]]*//')

    ffmpeg -i "$file" -c copy -map_metadata 0 -metadata title="$title_no_channel" -metadata track="$index" -metadata artist="$channel" -metadata year="$release_year" -metadata album="$album" "temp_$file"

    # Remove original file
    rm "$file"

    # Rename temp file to the original track name
    mv "temp_$file" "$index $title_no_channel.${file##*.}"
done

# Remove JSON files
rm *.json
