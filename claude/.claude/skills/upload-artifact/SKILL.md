---
name: upload-artifact
description: Upload markdown and html artifacts to my personal file server
---

# Upload Artifact

Upload markdown and html artifacts to my personal file server.

## Usage

```bash
scripts/upload-artifact.sh <file_path>
```

The uploaded file will be available at `https://files.moorad.dev/artifacts/<filename>`.

Uploading a file with the same name as an existing file will overwrite the existing file. All files uploaded and hosted on files.moorad.dev are publicly accessible.
