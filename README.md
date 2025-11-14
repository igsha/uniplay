# About

uniplay is a universal player that support various resource types: URLs, files, images and so on.

The system consists of fetchers that are concatenated into bash pipeline.
Each fetcher takes messages from stdin and send another messages to stdout to be read by the next fetcher
in pipeline (except terminal fetchers like `pdf` or `mpv`).
To communicate fetchers with each other through stdin/stdout the JSON format of messages is used.

There are 3 types of fetchers:
#. URL-matched fetcher can parse url.
#. Terminal fetcher can read stdin but it does not produce output.
#. Utility fetcher is used by URL-matched fetchers.

# Protocol

Common JSON message:
```json
{
    "result": "url",
    "item": "https://example.com/resource/image.jpg",
}
```
Only `item` or `items` attribute is mandatory.

Several URLs:
```json
{
    "result": "urls",
    "items": [
        "https://example.com/image1.jpg",
        "https://example.com/image2.jpg",
        "https://example.com/image3.jpg"
    ]
}
```
