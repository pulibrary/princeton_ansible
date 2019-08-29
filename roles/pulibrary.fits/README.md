## Fits

Installs FITS under /opt and symlinks the version installed to /opt/fits

### Requirements

This requires our `pulibrary.common` role.

### Role Variables

Role variables are listed below:

- `fits_version`: The version number of FITS to be installed, e.g., 0.6.2.
- `fits_download_url`: Base download URL from which FITS distribution .zip files may be downloaded.
