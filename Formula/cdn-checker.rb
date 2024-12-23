class CdnChecker < Formula
  desc "Tool to find and validate CDN URLs in web projects"
  homepage "https://github.com/cli-toolbox/CDN-Checker"
  url "https://github.com/cli-toolbox/CDN-Checker/archive/0.1.tar.gz"
  sha256 "36804352a0f2f9d2de9098205bb1dde4505d8ec612d5ea3635a8f6f71074f7b0"
  license "MIT"

  depends_on "grep"
  depends_on "curl"

  def install
    bin.install "cdn-checker"

    # Create the script file
    (bin/"cdn-checker").write <<~EOS
      #!/bin/bash

      VERBOSE=false
      DIRECTORY="."
      FILE_EXTENSIONS=("html" "css" "php")
      GREP_CMD=$(command -v ggrep || command -v grep)

      # ANSI color codes
      GREEN='\\033[0;32m'
      RED='\\033[0;31m'
      NC='\\033[0m' # No Color

      cdn_providers=(
          "cdn.jsdelivr.net"
          "cdnjs.cloudflare.com"
          "cloudflare.com"
          "akamai.net"
          "maxcdn.bootstrapcdn.com"
          "fastly.net"
          "unpkg.com"
          "stackpath.com"
          "bunnycdn.com"
          "keycdn.com"
          "cloudfront.net"
          "azureedge.net"
          "googleusercontent.com"
          "gstatic.com"
          "edgekey.net"
          "azure.net"
          "rackcdn.com"
      )

      excluded_paths=("node_modules" ".git" "dist" "build")

      log_verbose() {
          if [ "$VERBOSE" = true ]; then
              echo "[VERBOSE] $1" >&2
          fi
      }

      normalize_url() {
          local url="$1"
          if [[ "$url" =~ ^// ]]; then
              echo "https:${url}"
          elif [[ "$url" =~ ^https?:// ]]; then
              echo "$url"
          else
              echo "https://${url}"
          fi
      }

      get_status_code() {
          local url="$1"
          local status_code
          if command -v curl >/dev/null 2>&1; then
              status_code=$(curl -s -o /dev/null -I -w "%{http_code}" "$url")
          else
              echo "Error: curl is not installed" >&2
              exit 1
          fi
          echo "$status_code"
      }

      print_with_color() {
          local file="$1"
          local code="$2"
          local url="$3"

          if [ "$code" = "200" ]; then
              printf "%s:${GREEN}%s${NC}:%s\\n" "$file" "$code" "$url"
          elif [ "$code" = "404" ]; then
              printf "%s:${RED}%s${NC}:%s\\n" "$file" "$code" "$url"
          else
              printf "%s:%s:%s\\n" "$file" "$code" "$url"
          fi
      }

      process_css_url() {
          local css_file="$1"
          local base_cdn_url="$2"
          local parent_path="$3"
          local output_file="$4"

          local css_content
          css_content=$(cat "$css_file")

          local url_regex="url\\(['\"]?([^'\\"\\?]+)[^)]*\\)"
          echo "$css_content" | "$GREP_CMD" -o "url([^)]*)" | while read -r line; do
              if [[ $line =~ $url_regex ]]; then
                  local resource_path="${BASH_REMATCH[1]}"
                  resource_path=${resource_path#./}

                  local base_dir
                  base_dir=$(dirname "$base_cdn_url")
                  local full_url="${base_dir}/${resource_path}"

                  local status_code
                  status_code=$(get_status_code "$full_url")
                  print_with_color "$parent_path" "$status_code" "$full_url"
              fi
          done
      }

      find_and_process_files() {
          local temp_file
          temp_file=$(mktemp)

          local exclude_expr=""
          for path in "${excluded_paths[@]}"; do
              exclude_expr+=" -path \\"./$path\\" -prune -o"
          done

          local provider_pattern
          provider_pattern=$(IFS='|'; echo "${cdn_providers[*]}" | sed 's/\\./\\\\./g')
          local cdn_regex="(https?:)?//[^[:space:]'\\"]*($provider_pattern)[^[:space:]'\\"",<>()]*"

          local find_pattern=""
          for ext in "${FILE_EXTENSIONS[@]}"; do
              find_pattern="$find_pattern -o -name \\"*.$ext\\""
          done
          find_pattern=${find_pattern:3}

          while IFS= read -r file; do
              log_verbose "Processing file: $file"

              "$GREP_CMD" -oE "$cdn_regex" "$file" 2>/dev/null | while read -r url; do
                  local normalized_url status_code
                  normalized_url=$(normalize_url "$url")
                  status_code=$(get_status_code "$normalized_url")
                  print_with_color "$file" "$status_code" "$normalized_url"

                  if [[ "$normalized_url" =~ \\.css$ ]] && [[ "$status_code" == "200" ]]; then
                      log_verbose "Processing CSS file: $normalized_url"
                      local css_temp
                      css_temp=$(mktemp)
                      if curl -s "$normalized_url" -o "$css_temp"; then
                          process_css_url "$css_temp" "$normalized_url" "$file" "$temp_file"
                          rm -f "$css_temp"
                      fi
                  fi
              done

          done < <(eval "find \\"$DIRECTORY\\" $exclude_expr -type f \\( $find_pattern \\) -print" | sort) | tee >(cat > "$temp_file")

          if [ -s "$temp_file" ]; then
              file_count=$(cut -d':' -f1 "$temp_file" | sort | uniq | wc -l)
              url_count=$(wc -l < "$temp_file")
              echo "Summary:" >&2
              echo "--------" >&2
              echo "Files with CDN URLs: $file_count" >&2
              echo "Total CDN URLs found: $url_count" >&2

              if [ "$VERBOSE" = true ]; then
                  echo "" >&2
                  echo "CDN URLs and Status Codes:" >&2
                  while IFS=: read -r file code url; do
                      echo "File: $file" >&2
                      echo "Status Code: $code" >&2
                      print_with_color "$file" "$code" "$url" >&2
                      echo "---" >&2
                  done < "$temp_file"
              fi
          else
              echo "No CDN URLs found." >&2
          fi

          rm -f "$temp_file"
      }

      show_usage() {
          echo "Usage: $0 [--verbose] [-d|--directory DIR] [-e|--extensions ext1,ext2,...]" >&2
          echo "Options:" >&2
          echo "  --verbose             Enable verbose output" >&2
          echo "  -d, --directory DIR   Specify directory to scan (default: current directory)" >&2
          echo "  -e, --extensions LIST Comma-separated list of file extensions to scan (default: html,css,php)" >&2
      }

      while [[ $# -gt 0 ]]; do
          case $1 in
              --verbose)
                  VERBOSE=true
                  shift
                  ;;
              -d|--directory)
                  DIRECTORY="$2"
                  shift 2
                  ;;
              -e|--extensions)
                  IFS=',' read -ra FILE_EXTENSIONS <<< "$2"
                  shift 2
                  ;;
              -h|--help)
                  show_usage
                  exit 0
                  ;;
              *)
                  echo "Unknown option: $1" >&2
                  show_usage
                  exit 1
                  ;;
          esac
      done

      if [ ! -d "$DIRECTORY" ]; then
          echo "Error: Directory '$DIRECTORY' does not exist" >&2
          exit 1
      fi

      find_and_process_files
    EOS
  end

  test do
    system "#{bin}/cdn-checker", "--help"
  end
end