# ffmpeg_s

Ansible role to build and install FFmpeg from source with a comprehensive set of codecs and libraries.

## Overview

This role compiles FFmpeg from source along with numerous codec libraries, providing a fully-featured multimedia toolkit. Building from source ensures you get the latest features, optimizations, and non-free codecs (like libfdk-aac) that aren't available in distribution packages.

## Requirements

- Ubuntu 22.04 or 24.04 (tested)
- Root/sudo access
- Approximately 2GB disk space for build artifacts
- Internet access to download sources

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ffmpeg_s_prefix` | `/opt/ffmpeg` | Base installation directory |
| `ffmpeg_s_version` | `8.0.1` | FFmpeg version to build |
| `ffmpeg_s_make_jobs` | `{{ ansible_processor_vcpus }}` | Parallel make jobs |
| `ffmpeg_s_symlink_targets` | `[ffmpeg, ffprobe, ffplay]` | Binaries to symlink to `/usr/local/bin` |

### Derived Variables

These are computed from `ffmpeg_s_prefix` and generally don't need modification:

- `ffmpeg_s_sources_dir`: Source code directory (`/opt/ffmpeg/sources`)
- `ffmpeg_s_build_dir`: Build output directory (`/opt/ffmpeg/build`)
- `ffmpeg_s_bin_dir`: Binary directory (`/opt/ffmpeg/bin`)

## Included Codecs and Libraries

The role builds and links the following libraries:

| Library | Purpose |
|---------|---------|
| NASM | Assembler for optimized code |
| libx264 | H.264/AVC video encoder |
| libx265 | H.265/HEVC video encoder |
| libvpx | VP8/VP9 video codec |
| libfdk-aac | AAC audio encoder (non-free) |
| libopus | Opus audio codec |
| libaom | AV1 reference codec (x86_64 only) |
| libsvtav1 | SVT-AV1 encoder |
| libdav1d | AV1 decoder |
| libvmaf | Video quality metrics |
| libde265 | HEVC decoder |
| libheif | HEIF/HEIC image format |

Additional system libraries: libass, libfreetype, libmp3lame, libvorbis, libwebp, GnuTLS

## Architecture Support

The role supports both x86_64 and ARM64 (aarch64) architectures:

- **x86_64**: Full codec support including libaom
- **ARM64**: Most codecs with architecture-specific optimizations; libaom is skipped due to build complexity on ARM

## Dependencies

None. All build dependencies are installed via apt.

## Example Playbook

```yaml
- hosts: figgy_servers
  become: true
  roles:
    - role: ffmpeg_s
      vars:
        ffmpeg_s_version: "8.0.1"
```

### Custom Installation Path

```yaml
- hosts: figgy_servers
  become: true
  roles:
    - role: ffmpeg_s
      vars:
        ffmpeg_s_prefix: /usr/local/ffmpeg
```

**Note**: This role builds FFmpeg from source and does NOT use the system `ffmpeg` package. If you have `ffmpeg` installed via apt, this role will not remove it.

## Directory Structure

After installation:

```text
/opt/ffmpeg/
├── bin/           # Compiled binaries (ffmpeg, ffprobe, ffplay, x264, etc.)
├── build/         # Library installation prefix
│   ├── include/   # Header files
│   └── lib/       # Static libraries and pkgconfig
├── sources/       # Downloaded and extracted source code
└── tmp/           # Temporary build directory
```

## Post-Installation

FFmpeg binaries are available at:

- `/opt/ffmpeg/bin/ffmpeg`
- `/opt/ffmpeg/bin/ffprobe`
- `/opt/ffmpeg/bin/ffplay`

Symlinks are created in `/usr/local/bin/` for PATH access.

Verify the installation:

```bash
ffmpeg -version
ffmpeg -encoders | grep -E "(libx264|libx265|libfdk)"
```

## Build Time

Building all libraries and FFmpeg from source takes approximately:

- **x86_64**: 15-30 minutes depending on CPU cores
- **ARM64**: 20-45 minutes depending on CPU cores

## Testing

The role includes Molecule tests. Run with:

```bash
cd roles/ffmpeg_s
molecule test
```

### Verify Tests

The Molecule verify stage checks:

- FFmpeg binary exists and is executable
- Symlinks are correctly created
- Expected codecs are available
- Static libraries were built
- System `ffmpeg` package is NOT installed

## License

BSD-3-Clause

## Author Information

Princeton University Library
