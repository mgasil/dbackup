# dbackup
[![Build status](https://img.shields.io/github/workflow/status/mgasil/dbackup/Run%20all%20D%20Tests/master)](https://github.com/mgasil/dbackup/actions?query=workflow%3A%22Run+all+D+Tests%22)
[![Build status](https://img.shields.io/github/workflow/status/mgasil/dbackup/Validate%20style/master)](https://github.com/mgasil/dbackup/actions?query=workflow%3A%22Validate+style%22)
[![Github Downloads (monthly)](https://img.shields.io/github/downloads/mgasil/dbackup/total.svg)]()
[![Licensed under the GPLv3 License](https://img.shields.io/badge/License-GPLv3-red.svg)](https://github.com/mgasil/dbackup/LICENSE)

`dbackup` is a simple utility that creates a zip archive from the contents of a folder.
Unwanted files can be filtered out by creating a .dbackupignore file in the input directory.

**Filter**    

`.dbackignore` uses three different types of patterns to filter out unwanted files and folders.
* Directory: Any pattern prepended with a `/`, will only match directories.
* Extension: Any pattern prepended with a `*`, will only match extensions.
* Filename: Any pattern that are not one of the above will only match filenames.

**Examples**

`/.dub` will only match files that have `.dub` as a directory in its path.  
`*.o` will only match files with the extension `o`.    
`dbackup` will only match files with the filename `dbackup`.  

## Usage
Create a default .dbackupignore file in the current directory:
```
  dbackup --init="."
```
Backup the contents of the current directory to the current directory silently:
```
  dbackup --from="." --to="."
```
Backup the contents of the current directory to the current directory, displaying diagnostic messages:
```
  dbackup --from="." --to="." -v
```
Do not perform any action, and explain what would have been done:
```
  dbackup --from="." --to="." --annotate
```

## Download

You can download `dbackup` for specific OS via [**Github releases**](https://github.com/mgasil/dbackup/releases) of this project.

## Compilation

Please follow below instructions to be able to compile the project:

```
git clone https://github.com/mgasil/dbackup.git
cd dbackup
dub
```

## Requirements

There are no special requirements to run `dbackup`.

## Contribution

We welcome and appreciate any help, even if it's a tiny text or code change. Please read [contribution](https://github.com/mgasil/dbackup/blob/master/CONTRIBUTING.md) page before starting work on a pull request. All contributors are listed in the project's wiki [page](https://github.com/mgasil/dbackup/wiki/Contributors). 
Not sure what to start with? Feel free to refer to <kbd>[good first issue](https://github.com/mgasil/dbackup/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)</kbd> or <kbd>[help wanted](https://github.com/mgasil/dbackup/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)</kbd> tags.

## License

This project is under GNU General Public License v3.0. Please refer to file [**LICENSE**](https://github.com/mgasil/dbackup/blob/master/LICENSE) for more details.
