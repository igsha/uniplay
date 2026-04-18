# About

uniplay is a universal player that supports various resource types: URLs, files, images and so on.

The system consists of fetchers that are concatenated into a bash pipeline.
Each fetcher takes message from stdin and send another message to stdout to be read by the next fetcher
in pipeline (except terminal fetchers like `mpv`).
To communicate fetchers with each other through stdin/stdout the JSON format of messages is used.

There are 3 types of fetchers:

1. URL-matched fetcher can parse url.
1. Terminal fetcher can read stdin but it does not produce output.
1. Utility fetcher is used by URL-matched fetchers.

# Protocol

Common JSON message:
```json
{
    "url": "https://example.com/resource/video.mp4",
    "title": "Example video",
    "type": "video"
}
```

Several URLs:
```json
{
    "list": [
        {
            "url": "https://example.com/image1.jpg",
            "title": "Image 1.jpg"
        },
        {
            "url": "https://example.com/image2.jpg",
            "title": "Image 2.jpg"
        },
        {
            "url": "https://example.com/image3.jpg",
            "title": "Image 3.jpg"
        }
    ],
    "title": "image-cache",
    "hashkey": "url",
    "type": "images",
    "pipeline": "manga"
}
```
