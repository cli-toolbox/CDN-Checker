#!/usr/bin/env bash

#
# Universal Script Installer Configuration
# Edit these variables to customize the installation
#
SCRIPT_NAME="cdn-checker"           # The name of the tool being installed
SCRIPT_SOURCE="https://raw.githubusercontent.com/cli-toolbox/CDN-Checker/refs/heads/main/cdn-checker.sh"  # Source URL to download from
SCRIPT_INSTALL_DIR=".${SCRIPT_NAME}"   # Directory name under $HOME or $XDG_CONFIG_HOME
SCRIPT_EXEC_NAME="${SCRIPT_NAME}"      # Name of the final executable
SCRIPT_ENV_VAR="${SCRIPT_NAME}_DIR"    # Environment variable name (will be converted to uppercase)
SCRIPT_DESC="CDN Checker"           # Description for messages

{ # this ensures the entire script is downloaded #

# Convert SCRIPT_ENV_VAR to uppercase and replace hyphens with underscores
SCRIPT_ENV_VAR=$(echo "$SCRIPT_ENV_VAR" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

util_has() {
  type "$1" > /dev/null 2>&1
}

util_echo() {
  command printf %s\\n "$*" 2>/dev/null
}

if [ -z "${BASH_VERSION}" ] || [ -n "${ZSH_VERSION}" ]; then
  # shellcheck disable=SC2016
  util_echo >&2 'Error: the install instructions explicitly say to pipe the install script to `bash`; please follow them'
  exit 1
fi

util_grep() {
  GREP_OPTIONS='' command grep "$@"
}

util_default_install_dir() {
  [ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/${SCRIPT_INSTALL_DIR}" || printf %s "${XDG_CONFIG_HOME}/${SCRIPT_INSTALL_DIR}"
}

util_install_dir() {
  eval "local env_dir=\${$SCRIPT_ENV_VAR-}"
  if [ -n "$env_dir" ]; then
    printf %s "${env_dir}"
  else
    util_default_install_dir
  fi
}

util_download() {
  if util_has "curl"; then
    curl --fail --compressed -q "$@"
  elif util_has "wget"; then
    # Emulate curl with wget
    ARGS=$(util_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                            -e 's/--compressed //' \
                            -e 's/--fail //' \
                            -e 's/-L //' \
                            -e 's/-I /--server-response /' \
                            -e 's/-s /-q /' \
                            -e 's/-sS /-nv /' \
                            -e 's/-o /-O /' \
                            -e 's/-C - /-c /')
    # shellcheck disable=SC2086
    eval wget $ARGS
  fi
}

install_script() {
  local INSTALL_DIR
  INSTALL_DIR="$(util_install_dir)"

  # Downloading to $INSTALL_DIR
  mkdir -p "$INSTALL_DIR"
  if [ -f "$INSTALL_DIR/$SCRIPT_EXEC_NAME" ]; then
    util_echo "=> $SCRIPT_DESC is already installed in $INSTALL_DIR, trying to update"
  else
    util_echo "=> Downloading $SCRIPT_DESC to '$INSTALL_DIR'"
  fi
  util_download -s "$SCRIPT_SOURCE" -o "$INSTALL_DIR/$SCRIPT_EXEC_NAME" || {
    util_echo >&2 "Failed to download '$SCRIPT_SOURCE'"
    return 1
  }
  chmod a+x "$INSTALL_DIR/$SCRIPT_EXEC_NAME" || {
    util_echo >&2 "Failed to mark '$INSTALL_DIR/$SCRIPT_EXEC_NAME' as executable"
    return 2
  }
}

util_try_profile() {
  if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
    return 1
  fi
  util_echo "${1}"
}

util_detect_profile() {
  if [ "${PROFILE-}" = '/dev/null' ]; then
    # the user has specifically requested NOT to have the script touch their profile
    return
  fi

  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    util_echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''

  if [ "${SHELL#*bash}" != "$SHELL" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
    if [ -f "$HOME/.zshrc" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    fi
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"
    do
      if DETECTED_PROFILE="$(util_try_profile "${HOME}/${EACH_PROFILE}")"; then
        break
      fi
    done
  fi

  if [ -n "$DETECTED_PROFILE" ]; then
    util_echo "$DETECTED_PROFILE"
  fi
}

util_do_install() {
  eval "local TARGET_DIR=\${$SCRIPT_ENV_VAR-}"
  if [ -n "${TARGET_DIR-}" ] && ! [ -d "${TARGET_DIR}" ]; then
    if [ -e "${TARGET_DIR}" ]; then
      util_echo >&2 "File \"${TARGET_DIR}\" has the same name as installation directory."
      exit 1
    fi

    if [ "${TARGET_DIR}" = "$(util_default_install_dir)" ]; then
      mkdir "${TARGET_DIR}"
    else
      util_echo >&2 "You have \$$SCRIPT_ENV_VAR set to \"${TARGET_DIR}\", but that directory does not exist. Check your profile files and environment."
      exit 1
    fi
  fi

  # Check for required tools
  if ! util_has curl && ! util_has wget; then
    util_echo >&2 "You need curl or wget to install $SCRIPT_DESC"
    exit 1
  fi

  install_script

  util_echo

  local TOOL_PROFILE
  TOOL_PROFILE="$(util_detect_profile)"
  local PROFILE_INSTALL_DIR
  PROFILE_INSTALL_DIR="$(util_install_dir | command sed "s:^$HOME:\$HOME:")"

  SOURCE_STR="\\nexport $SCRIPT_ENV_VAR=\"${PROFILE_INSTALL_DIR}\"\\nexport PATH=\"\$$SCRIPT_ENV_VAR:\$PATH\"  # This adds $SCRIPT_DESC to path\\n"

  if [ -z "${TOOL_PROFILE-}" ] ; then
    local TRIED_PROFILE
    if [ -n "${PROFILE}" ]; then
      TRIED_PROFILE="${TOOL_PROFILE} (as defined in \$PROFILE), "
    fi
    util_echo "=> Profile not found. Tried ${TRIED_PROFILE-}~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile."
    util_echo "=> Create one of them and run this script again"
    util_echo "   OR"
    util_echo "=> Append the following lines to the correct file yourself:"
    command printf "${SOURCE_STR}"
    util_echo
  else
    if ! command grep -qc "$SCRIPT_ENV_VAR" "$TOOL_PROFILE"; then
      util_echo "=> Appending $SCRIPT_DESC source string to $TOOL_PROFILE"
      command printf "${SOURCE_STR}" >> "$TOOL_PROFILE"
    else
      util_echo "=> $SCRIPT_DESC source string already in ${TOOL_PROFILE}"
    fi
  fi

  util_echo "=> Close and reopen your terminal to start using $SCRIPT_DESC or run the following to use it now:"
  command printf "${SOURCE_STR}"
}

#
# Unsets the various functions defined
# during the execution of the install script
#
util_reset() {
  unset -f util_has util_install_dir util_download install_script \
    util_try_profile util_detect_profile util_do_install util_reset \
    util_default_install_dir util_grep util_echo
}

[ "_$INSTALL_ENV" = "_testing" ] || util_do_install

} # this ensures the entire script is downloaded #