# About

uniplay is a universal player that support various resource types: URLs, files, images and so on.

The system consists of fetchers that are concatenated into bash pipeline.
Each fetcher takes messages from stdin and send another messages to stdout to be read by the next fetcher
in pipeline (except terminal fetchers like `pdf` or `mpv`).
To communicate fetchers with each other through stdin/stdout the JSON format of messages is used.

There are 3 types of fetchers:

1. URL-matched fetcher can parse url.
1. Terminal fetcher can read stdin but it does not produce output.
1. Utility fetcher is used by URL-matched fetchers.

# Protocol

Common JSON message:
```json
{
    "item": "https://example.com/resource/image.jpg",
    "title": "Example image"
}
```
Only `item` or `items` attribute is mandatory.

Several URLs:
```json
{
    "items": [
        {
            "item": "https://example.com/image1.jpg",
            "name": "Image 1"
        },
        {
            "item": "https://example.com/image2.jpg",
            "name": "Image 2"
        },
        {
            "item": "https://example.com/image3.jpg",
            "name": "Image 3"
        }
    ],
    "title": "image-cache"
}
```
