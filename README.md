# Otto

Otto is a shell script for importing and organizing RAW and JPEG files. The script performs the following tasks:

- transfer RAW and JPEG files from an external USB device (for example, USB card reader)
- rename the transferred files using the _YYYYMMDD-HHMMSS_ format
- write camera model, lens, and weather conditions to the EXIF metadata
- geotag or geocorrelate the transferred files.
- group the processed files into folders by date.

# Dependencies

Otto requires the following tools: getopt, bc, jq, cURL, ExifTool, Rsync, GPSbabel

# Installation and usage

The [Linux Photography](https://gumroad.com/l/linux-photography) book provides detailed instructions on installing and using Otto. Get your copy at [Google Play Store](https://play.google.com/store/books/details/Dmitri_Popov_Linux_Photography?id=cO70CwAAQBAJ) or [Gumroad](https://gumroad.com/l/linux-photography).

<img src="https://tinyvps.xyz/img/linux-photography.jpeg" title="Linux Photography book" width="200"/>

## Usage

    otto.sh -d <dir> -g <location> -c <dir>

- `-d` absolute path to the source directory
- `-g` name of the city where the photos were taken (optional)
- `-c` path to a directory containing one or several GPX files (optional)

## Problems?

Please report bugs and issues in the [Issues](https://github.com/dmpop/otto/issues) section.

## Contribute

If you've found a bug or have a suggestion for improvement, open an issue in the [Issues](https://github.com/dmpop/otto/issues) section.

To add a new feature or fix issues yourself, follow the following steps.

1. Fork the project's repository repository.
2. Create a feature branch using the `git checkout -b new-feature` command.
3. Add your new feature or fix bugs and run the `git commit -am 'Add a new feature'` command to commit changes.
4. Push changes using the `git push origin new-feature` command.
5. Submit a pull request.

## Author

Dmitri Popov [dmpop@linux.com](mailto:dmpop@linux.com)

## License

The [GNU General Public License version 3](http://www.gnu.org/licenses/gpl-3.0.en.html)

<noscript><a href="https://liberapay.com/dmpop/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>
