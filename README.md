# Otto

```
       ~
    o{°_°}o
     /(.)~[*O]
      / \
================
Hello! I'm Otto.
```

Otto is a shell script for importing and organizing RAW and JPEG files.

## Features

- Transfer all files or RAW files only to the predefined destination directory.
- Rename the transferred files using the _YYYYMMDD-HHMMSS_ naming format.
- For each photo, obtain camera model and lens model.
- If enabled, fetch text notes for the dates corresponding to the dates of the photos.
- Write the obtained camera model, lens model, and notes to the **Comments** field of each photo's EXIF metadata.
- Write the predefined copyright notice to the **Copyright** field of each photo's EXIF metadata.
- If keywords are specified, write them into each photo's EXIF metadata.
- Geotag photos using the geographical coordinates of the specified city.
- Merge multiple GPX tracks and geocorrelate photos using the resulting GPX file.
- Group the transferred files into folders by date using the _YYYY-MM-DD_ naming format.
- Notify on job completion via [ntfy](http://ntfy.sh).

# Dependencies

Otto requires the following tools: `dialog`, `getopt`, `bc`, `jq`, `cURL`, `ExifTool`, `Rsync`, `sshpass`, `GPSbabel`

# Installation and usage

The [Linux Photography](https://gumroad.com/l/linux-photography) book provides detailed instructions on installing and using Otto. Get your copy at [Google Play Store](https://play.google.com/store/books/details/Dmitri_Popov_Linux_Photography?id=cO70CwAAQBAJ) or [Gumroad](https://gumroad.com/l/linux-photography).

<img src="https://cameracode.coffee/uploads/linux-photography.png" title="Linux Photography book" width="300"/>

## Usage

```
otto.sh -d <dir> -g <location> -c <dir> -b -i -k "keyword1, keyword2, keyword3"
otto.sh -d <dir> -s <exif_tag>
```

- `-d` absolute path to the source directory
- `-g` name of the city where the photos were taken
- `-c` path to a directory containing one or several GPX files
- `-b` perform backup only
- `-i` Perform backup to an individual directory named after the current date
- `-k` write specified keywords into EXIF medata
- `-s` Generate stats for the given EXIF tag

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

