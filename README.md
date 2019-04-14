# Otto

Shell script for NAS appliances and Linux machines to import and organize photos and RAW files. The script transfers photos and RAW files from an external storage device to the specified directory on the NAS. The script can also geotag or geocorrelate the imported files.

For each JPEG photos, the script writes camera model, lens, and weather conditions to the EXIF metadata. The script then renames the transferred files using the YYYYMMDD-HHMMSS format and groups them into folders by date.

# Installation and Usage

The [Linux Photography](https://gumroad.com/l/linux-photography) book provides detailed instructions on installing and using Otto. Get your copy at [Google Play Store](https://play.google.com/store/books/details/Dmitri_Popov_Linux_Photography?id=cO70CwAAQBAJ) or [Gumroad](https://gumroad.com/l/linux-photography).

<img src="https://scribblesandsnaps.files.wordpress.com/2016/07/linux-photography-6.jpg" width="200"/>

## Usage

    otto.sh -d <dir> -g <location>

- `-d` or `--directory` absolute path to the source directory
- `-g` or `--geotag`    name of the city where the photos were taken (optional)

## Limitations

When using the script to geotag photos, Otto assumes that all transferred photos and RAW files are taken is one city.

## Problems?

Please report bugs and issues in the [Issues](https://gitlab.com/dmpop/otto/issues) section.

## Contribute

If you've found a bug or have a suggestion for improvement, open an issue in the [Issues](https://gitlab.com/dmpop/otto/issues) section.

To add a new feature or fix issues yourself, follow the following steps.

1. Fork the project's repository repository
2. Create a feature branch using the `git checkout -b new-feature` command
3. Add your new feature or fix bugs and run the `git commit -am 'Add a new feature'` command to commit changes
4. Push changes using the `git push origin new-feature` command
5. Submit a pull request

## Author

Dmitri Popov [dmpop@linux.com](mailto:dmpop@linux.com)

## License

The [GNU General Public License version 3](http://www.gnu.org/licenses/gpl-3.0.en.html)

<noscript><a href="https://liberapay.com/dmpop/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>