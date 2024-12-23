# CDN Checker

A command-line tool that scans your web projects for CDN URLs and validates their accessibility.


## Installation

Using curl:
```bash
curl -o- https://raw.githubusercontent.com/cli-toolbox/CDN-Checker/refs/heads/main/install.sh | bash
```

Using wget:
```bash
wget -qO- https://raw.githubusercontent.com/cli-toolbox/CDN-Checker/refs/heads/main/install.sh | bash
```

After installation, close and reopen your terminal or source your profile:
```bash 
source ~/.bashrc  # or ~/.zshrc, ~/.profile, depending on your shell
```



## Benefits

- Automatically detects CDN URLs in HTML, CSS, and PHP files
- Validates all CDN resources including nested CSS dependencies
- Provides colored output for quick status identification (green=200, red=404)
- Excludes common development directories (node_modules, .git, dist, build)
- Supports custom file extension scanning
- Detailed reporting with file counts and URL summaries

## Examples

Basic scan of current directory:
```bash
cdn-checker
```

Scan specific directory with verbose output:
```bash
cdn-checker --verbose -d /path/to/project
```

Scan only specific file types:
```bash
cdn-checker -e js,html,php
```

Example output:
```
index.html:200:https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css
styles.css:404:https://cdnjs.cloudflare.com/ajax/libs/outdated-library/1.0/style.css

Summary:
--------
Files with CDN URLs: 2
Total CDN URLs found: 2
```



## Usage

```bash
cdn-checker [--verbose] [-d|--directory DIR] [-e|--extensions ext1,ext2,...]

Options:
  --verbose             Enable verbose output
  -d, --directory DIR   Specify directory to scan (default: current directory)
  -e, --extensions LIST Comma-separated list of file extensions to scan (default: html,css,php)
```