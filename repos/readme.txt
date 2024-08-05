package-name
├── host: host by aur(default, can be omitted) or gitlab (or github).
├── url: place the repo url of this package without .git suffix.
├── version: place the version of this package(can be omitted).
└── quirks: place the scipt to do with this package, if quirks exist,
            then it must have before and after founction. Place patch
            in the same dir, get the raw patch by curl, then You can
            patch it in the before founction.
