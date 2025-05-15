# Cloak

Hide (_mostly_) anything in plain sight.

## Features

* Handle several file types (audio, video, image, pdf)
* Can hide a string, a file and a folder
* Fileless (avoids writing to disk as possible)
* Encryption (AES 256 / ChaCha20-Poly1305)
  
> [!NOTE]
> Folder content will be archived as `zip` files and embedded into the target file.

## Limits

Contrary to the real steganography, (ab)using files metadata has some limits that may not exist with the [LSB](https://www.researchgate.net/publication/368691521_Hiding_secret_data_in_audiovideoimagetext_steganography_using_least_significant_bit_algorithmMHIndia) algorithm.

### Hidden data size

Basically, the limit for storing hidden data will be the target file size itself.

So, if your target file size is 500 KB, you will then be able to store (hide) up to 500 KB of data into the target file.

The bigger the target file is, the more you can store (hide) data in it.

> [!TIP]
> __As a rule of thumb, the data that you want to store (hide) must be smaller than the target file that will hold it.__

### Metadata tags

When testing if PDF files could be used as target file, I've discovered that only the `description` tag could be added but not the `comment` tag.

> [!NOTE]
> I've then modified the code to handle this situation but depending on the target file format, the script might fail to write the required metadata tags.

### Not very stealthy

Another limit is that the encrypted data can be seen while using an hexadecimal viewer like `xxd`.

> [!IMPORTANT]
> If that's a problem for you, you should then fallback on real steganography to conceal your secret data.

## Usage

```console
Usage: cloak.sh <file> <data | string> - Embed and Hide data in file.

Arguments:

  -h | --help                        Print this help message
  -d | --dump <file>                 Dump data from given file
  -e | --extract <file>              Extract data from given file
  -k | --keep                        Keep original input file (don't replace it)

Examples:

  * cloak.sh <file>                  Print file tags
  * cloak.sh <file> <data | string>  Embed and Hide data in file tags
  * cloak.sh -d <file>               Read given file tags and print hidden data
  * cloak.sh -e <file>               Read given file tags and extract hidden data

```

## Author

* __Jiab77__
