# varManager
varManager
var Manager for virt-a-mate
This tool is used to manage var files.
The main method is to place all var files to the repository directory.Create a symlink link to the var file in the AddonPackages directory as needed.

### Version 1.0.4.10 Update Tips:
0. **Upgrade Notice**: If you wish to retain your old variable profile, make sure to back up `varManager.mdb`. It is recommended to use the new version with a completely updated profile for optimal performance.
0. **Administrator IS NECESSARY**: Starting from version 1.0.4.9, `varManager.exe` must be run as an administrator due to the necessity of creating symlinks in .NET 6.0.
0. **Runtime Installation**: If `varManager.exe` fails to run, try installing the .NET Desktop Runtime 6.0 from [here](https://dotnet.microsoft.com/en-us/download/dotnet/6.0).
1. **New Button**: New `FetchDownloadFromHub` Button for Hub var resource get and download, it support download misssing single var at `depends analyse` page for now, download function powered by plugin [vam_downloader](https://github.com/bustesoul/vam_downloader).
