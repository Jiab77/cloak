# Cloak

Hide (_mostly_) anything in plain sight.

## Features

* Handle several file types (audio, video, image, pdf)
* Can hide a string, a file or a folder
* Fileless (avoids writing to disk as possible)
* Encryption (AES 256 / ChaCha20-Poly1305)
* Accept password from prompt or environment variable
* Use auto generated key if no password provided

> [!NOTE]
> Folder content will be archived as `zip` files and embedded into the target file.

## How it works

Basically, I'm (ab)using [metadata](https://en.wikipedia.org/wiki/Metadata) tags embedded in audio, video, image and pdf files to store the encrypted payload passed as argument or from stdin.

More precisely, I'm creating (or replacing) two metadata tags:

1. Comment (_used to store detection tag line_)
2. Description (_used to store the encrypted payload_)

The payload is encrypted and base64 encoded before being stored to the `description` metadata tag.

For the decryption, the script will parse the `description` metadata tag if it finds the defined tag line in the `comment` metadata tag.

> [!NOTE]
> You can change the detection tag line in the [source code](cloak.sh) of the script.

## Limits

Contrary to the real [steganography](https://en.wikipedia.org/wiki/Steganography), (ab)using files [metadata](https://en.wikipedia.org/wiki/Metadata) tags has some limits that may not exist with the [LSB](https://www.researchgate.net/publication/368691521_Hiding_secret_data_in_audiovideoimagetext_steganography_using_least_significant_bit_algorithmMHIndia) algorithm.

### Metadata tags

When testing if PDF files could be used as target file, I've discovered that only the `description` tag could be added but not the `comment` tag.

> [!NOTE]
> I then modified the code to handle this situation but depending on the target file format, the script might fail to write the required metadata tags.
>
> Please, create an issue with the unsupported file type so that I can try to implement required code.

### Not very stealthy

Another limit is that the encrypted data can be seen while using an hexadecimal viewer like `xxd`.

> [!IMPORTANT]
> If that's a problem for you, you should then fallback on real [steganography](https://en.wikipedia.org/wiki/Steganography) to conceal your secret data.

## Usage

```console

Usage: cloak.sh <file> [payload] - Embed and Hide data in file.

Arguments:

  -h | --help                             Print this help message
  -d | --dump <file>                      Dump data from given file
  -e | --extract <file>                   Extract data from given file
  -k | --keep                             Keep original input file (don't replace it)
  -p | --pass                             Enable password protection

Examples:

  * cloak.sh <file>                      Print file tags
  * cloak.sh <file> <payload>            Embed and Hide data in file tags
  * cat <file> | cloak.sh <file> -       Embed and Hide data from stdin
  * echo <string> | cloak.sh <file> -    Embed and Hide string from stdin
  * cloak.sh -d <file>                   Read given file tags and print hidden data
  * cloak.sh -d <file> | file -          Read given file tags and get hidden data type
  * cloak.sh -e <file>                   Read given file tags and extract hidden data

Note: The payload can be either a file, a string or a folder.

```

## Author

* __Jiab77__
