#!/usr/bin/env bash
# shellcheck disable=SC2034

# Cloak
#
# Encrypt and hide (mostly) anything in plain sight
# using OpenSSL or GPG and FFMpeg or ExifTool.
#
# Made by Jiab77
#
# Notes:
# - Part of this project has been inspired by the work done by THC.
#
# Version 0.2.0

# Options
[[ -e $HOME/.debug ]] && set -x

# Config
ENC_ALGO_OSSL="chacha20"
ENC_ALGO_GPG="aes256"
TAG_LINE="Modified by Cloak"
ALLOW_FOLDERS=true
KEEP_ORIGINAL=false
USE_PASSWORD=false
RUN_MODE="embed"  # Available run modes: 'embed', 'extract', 'dump'

# Internals
SCR_DIR="$(dirname "$0")"
SCR_NAME="$(basename "$0")"
BIN_DEPS=(base64 exiftool ffmpeg ffprobe jq openssl gpg)
BIN_B64=$(which base64 2>/dev/null)
BIN_B82=$(which base82 2>/dev/null)
BIN_EXF=$(which exiftool 2>/dev/null)
BIN_FFM=$(which ffmpeg 2>/dev/null)
BIN_FFP=$(which ffprobe 2>/dev/null)
BIN_OSSL=$(which openssl 2>/dev/null)
BIN_GPG=$(which gpg 2>/dev/null)
BIN_QPDF=$(which qpdf 2>/dev/null)
BIN_SRM=$(which srm 2>/dev/null)
BIN_TAR=$(which tar 2>/dev/null)
BIN_XZ=$(which xz 2>/dev/null)
BIN_ZIP=$(which zip 2>/dev/null)
BIN_7Z=$(which 7z 2>/dev/null)

# Functions
function die() {
  echo -e "\nError: $1\n" >&2
  exit 255
}
function log() {
  echo "$@" >&2
}
function print_missing() {
  local MISSING_COUNT=0
  local MISSING_DEPS=()

  for D in "${BIN_DEPS[@]}"; do
    if [[ -z $(which "$D" 2>/dev/null) ]]; then
      ((MISSING_COUNT++))
      MISSING_DEPS+=("$D")
    fi
  done
  if [[ $MISSING_COUNT -ne 0 ]]; then
    if [[ $MISSING_COUNT -gt 1 ]]; then
      die "Missing '$(echo "${MISSING_DEPS[@]}" | tr " " ",")' binaries. Please install any supported one."
    else
      die "Missing '${MISSING_DEPS[0]}' binary. Please install any supported one."
    fi
  fi
}
function print_usage() {
  echo -e "\nUsage: $SCR_NAME <file> <data | string> - Embed and Hide data in file." >&2
  exit 1
}
function print_help() {
  cat >&2 <<EOF

Usage: $SCR_NAME <file> [payload] - Embed and Hide data in file.

Arguments:

  -h | --help                             Print this help message
  -d | --dump <file>                      Dump data from given file
  -e | --extract <file>                   Extract data from given file
  -k | --keep                             Keep original input file (don't replace it)
  -p | --pass                             Enable password protection

Examples:

  * $SCR_NAME <file>                      Print file tags
  * $SCR_NAME <file> <payload>            Embed and Hide data in file tags
  * cat <file> | $SCR_NAME <file> -       Embed and Hide data from stdin
  * echo <string> | $SCR_NAME <file> -    Embed and Hide string from stdin
  * $SCR_NAME -d <file>                   Read given file tags and print hidden data
  * $SCR_NAME -d <file> | file -          Read given file tags and get hidden data type
  * $SCR_NAME -e <file>                   Read given file tags and extract hidden data

Note: The payload can be either a file, a string or a folder.

EOF

  exit 1
}
function enc_str() {
  echo -n "$1" | base64 -w0 -
}
function dec_str() {
  echo -n "$1" | base64 -d -
}
function gen_key() {
  if [[ ! -r $SCR_DIR/key.dat ]]; then
    openssl rand -base64 32 > "$SCR_DIR/key.dat"
  fi
}
function enc_data() {
  if [[ -n $BIN_OSSL ]]; then
    if [[ -n $PASSWORD ]]; then
      echo -n "$1" | openssl "$ENC_ALGO_OSSL" -pbkdf2 -e -pass env:PASSWORD -in - | base64 -w0 -
    elif [[ $USE_PASSWORD == false ]]; then
      echo -n "$1" | openssl "$ENC_ALGO_OSSL" -pbkdf2 -e -pass file:"$SCR_DIR/key.dat" -in - | base64 -w0 -
    else
      echo -n "$1" | openssl "$ENC_ALGO_OSSL" -pbkdf2 -e -in - | base64 -w0 -
    fi
  else
    echo -n "$1" | gpg -ac --cipher-algo="$ENC_ALGO_GPG" -o- | base64 -w0 -
  fi
}
function dec_data() {
  if [[ -n $BIN_OSSL ]]; then
    if [[ -n $PASSWORD ]]; then
      echo -n "$1" | base64 -d - | openssl "$ENC_ALGO_OSSL" -pbkdf2 -d -pass env:PASSWORD -in -
    elif [[ $USE_PASSWORD == false ]]; then
      echo -n "$1" | base64 -d - | openssl "$ENC_ALGO_OSSL" -pbkdf2 -d -pass file:"$SCR_DIR/key.dat" -in -
    else
      echo -n "$1" | base64 -d - | openssl "$ENC_ALGO_OSSL" -pbkdf2 -d -in -
    fi
  else
    echo -n "$1" | base64 -d - | gpg -o-
  fi
}
function enc_file() {
  if [[ -n $BIN_OSSL ]]; then
    if [[ -n $PASSWORD ]]; then
      openssl "$ENC_ALGO_OSSL" -pbkdf2 -e -pass env:PASSWORD -in "$1" | base64 -w0 -
    elif [[ $USE_PASSWORD == false ]]; then
      openssl "$ENC_ALGO_OSSL" -pbkdf2 -e -pass file:"$SCR_DIR/key.dat" -in "$1" | base64 -w0 -
    else
      openssl "$ENC_ALGO_OSSL" -pbkdf2 -e -in "$1" | base64 -w0 -
    fi
  else
    gpg -ac --cipher-algo="$ENC_ALGO_GPG" -o- "$1" | base64 -w0 -
  fi
}
function dec_file() {
  if [[ -n $BIN_OSSL ]]; then
    if [[ -n $PASSWORD ]]; then
      base64 -d - | openssl "$ENC_ALGO_OSSL" -pbkdf2 -d -pass env:PASSWORD -in - > "/tmp/$1"
    elif [[ $USE_PASSWORD == false ]]; then
      base64 -d - | openssl "$ENC_ALGO_OSSL" -pbkdf2 -d -pass file:"$SCR_DIR/key.dat" -in - > "/tmp/$1"
    else
      base64 -d - | openssl "$ENC_ALGO_OSSL" -pbkdf2 -d -in - > "/tmp/$1"
    fi
  else
    base64 -d - | gpg -o- > "/tmp/$1"
  fi
}
function del_file() {
  if [[ -n $BIN_SRM ]]; then
    srm -f -l "$1"
  else
    rm -f "$1"
  fi
}
function cmp_folder() {
  local ARCHIVE_NAME
  ARCHIVE_NAME="$(basename "$1").zip"
  if [[ -d "$1" ]]; then
    if [[ -n $BIN_ZIP && ! -r "/tmp/$ARCHIVE_NAME" ]]; then
      log -e "\nCompressing folder [$1] to [$ARCHIVE_NAME]...\n"
      ( cd "$1" && zip -r - -9 . ) > "/tmp/$ARCHIVE_NAME"
    elif [[ -n $BIN_7Z && ! -r "/tmp/$ARCHIVE_NAME" ]]; then
      log -e "\nCompressing folder [$1] to [$ARCHIVE_NAME]...\n"
      ( cd "$1" && 7z a -tzip -so -mx9 . ) > "/tmp/$ARCHIVE_NAME"
    else
      die "Missing required 'zip' compression tool."
    fi
  else
    die "Given argument is not a folder: $1"
  fi
}
function check_file_size() {
  if [[ $(stat -c %s "$2") -gt $(stat -c %s "$1") ]]; then
    die "Can't hide files larger than source files."
  fi
}
function get_diff() {
  log -e "\nShowing changes...\n"
  exiftool -P "$1" -diff "$2"
}
function get_tags_ex() {
  log -e "\nReading file tags...\n"
  exiftool -P "$1" -json | jq .
}
function get_tags_ff() {
  log -e "\nReading file tags...\n"
  ffprobe -loglevel error -show_entries stream_tags:format_tags -of json "$1" | jq .
}
function get_input_format() {
  ffprobe -loglevel error -show_format -of json "$1" | jq -rc ".format.format_name"
}
function hide_data_ex() {
  local INPUT_DIR ; INPUT_DIR="$(dirname "$1")"
  local INPUT_NAME ; INPUT_NAME="$(basename "$1")"
  local INPUT_TAGS ; INPUT_TAGS="/tmp/${INPUT_NAME}.tags"
  local OUTPUT_NAME ; OUTPUT_NAME="${INPUT_NAME}.mod"
  local ARCHIVE_NAME ; ARCHIVE_NAME="$(basename "$2").zip"

  if [[ ! $OUTPUT_NAME == "$INPUT_NAME" && -e "${INPUT_DIR}/${OUTPUT_NAME}" ]]; then
    log -e "\nRemoving existing file '$INPUT_DIR/$OUTPUT_NAME'...\n"
    del_file "${INPUT_DIR}/${OUTPUT_NAME}"
  fi

  # TODO: Add "qpdf" related code to fix metadata handling issue
  # Link: https://exiftool.org/TagNames/PDF.html
  # Ref:
  # 1) A linearized PDF file is no longer linearized after the update, so it must be subsequently re-linearized if this is required.
  # 2) All metadata edits are reversible. While this would normally be considered an advantage, it is a potential security problem because old information is never actually deleted from the file. (However, after running ExifTool the old information may be removed permanently using the "qpdf" utility with this command: "qpdf --linearize in.pdf out.pdf".)

  log -e "\nAdding data to file...\n"
  if [[ -f "$2" ]]; then
    # Create file tags
    echo -ne "-comment=${TAG_LINE}\n-description=N:$(enc_str "$(basename "$2")");F:" > "$INPUT_TAGS"
    enc_file "$2" >> "$INPUT_TAGS"

    # Write tags from file
    exiftool -P -@ "$INPUT_TAGS" -o "${INPUT_DIR}/${OUTPUT_NAME}" "$1" || die "Unable to embed and encrypt data in file."
    get_diff "$1" "${INPUT_DIR}/${OUTPUT_NAME}"
  elif [[ -d "$2" && $ALLOW_FOLDERS == true ]]; then
    if [[ $(cmp_folder "$2") ]]; then
      if [[ -f "/tmp/$ARCHIVE_NAME" ]]; then
        # Recall function with new archive file
        "${FUNCNAME[0]}" "$1" "/tmp/$ARCHIVE_NAME"
        del_file "/tmp/$ARCHIVE_NAME"
      fi
    fi
  elif [[ $2 == "-" ]]; then
    # Create file tags
    echo -ne "-comment=${TAG_LINE}\n-description=N:$(enc_str stdin);F:" > "$INPUT_TAGS"
    enc_file /dev/stdin >> "$INPUT_TAGS"

    # Write tags from stdin
    exiftool -P -@ "$INPUT_TAGS" -o "${INPUT_DIR}/${OUTPUT_NAME}" "$1" || die "Unable to embed and encrypt data in file."
    get_diff "$1" "${INPUT_DIR}/${OUTPUT_NAME}"
  else
    # Write tags from string
    exiftool -P \
             -comment="$TAG_LINE" \
             -description="S:$(enc_data "$2")" \
             -o "${INPUT_DIR}/${OUTPUT_NAME}" "$1" \
             || die "Unable to embed data in file."

    # Show file diff
    get_diff "$1" "${INPUT_DIR}/${OUTPUT_NAME}"
  fi

  # Clean
  [[ -e "$INPUT_TAGS" ]] && rm -f "$INPUT_TAGS"
  if [[ -e "${INPUT_DIR}/${OUTPUT_NAME}" && $KEEP_ORIGINAL == false ]]; then
    mv -f "${INPUT_DIR}/${OUTPUT_NAME}" "${INPUT_DIR}/${INPUT_NAME}"
  fi
}
function hide_data_ff() {
  local INPUT_DIR ; INPUT_DIR="$(dirname "$1")"
  local INPUT_NAME ; INPUT_NAME="$(basename "$1")"
  local INPUT_TAGS ; INPUT_TAGS="/tmp/${INPUT_NAME}.tags"
  local OUTPUT_FORMAT ; OUTPUT_FORMAT="$(get_input_format "$1")"
  local OUTPUT_NAME ; OUTPUT_NAME="${INPUT_NAME}.mod"
  local ARCHIVE_NAME ; ARCHIVE_NAME="$(basename "$2").zip"

  log -e "\nAdding data to file...\n"
  if [[ -f "$2" ]]; then
    # Create file tags
    echo -ne ";FFMETADATA1\ncomment=${TAG_LINE}\ndescription=N:$(enc_str "$(basename "$2")");F:" > "$INPUT_TAGS"
    enc_file "$2" >> "$INPUT_TAGS"

    # Write tags from file
    ffmpeg -hide_banner -y \
           -i "$1" \
           -i "$INPUT_TAGS" \
           -c copy \
           -movflags use_metadata_tags \
           -map_metadata 0 \
           -map_metadata 1 \
           -f "$OUTPUT_FORMAT" \
           "${INPUT_DIR}/${OUTPUT_NAME}" \
           || die "Unable to embed and encrypt data in file."

    # Show file diff
    get_diff "$1" "${INPUT_DIR}/${OUTPUT_NAME}"
  elif [[ -d "$2" && $ALLOW_FOLDERS == true ]]; then
    if [[ $(cmp_folder "$2") ]]; then
      if [[ -f "/tmp/$ARCHIVE_NAME" ]]; then
        # Recall function with new archive file
        "${FUNCNAME[0]}" "$1" "/tmp/$ARCHIVE_NAME"
        del_file "/tmp/$ARCHIVE_NAME"
      fi
    fi
  elif [[ $2 == "-" ]]; then
    # Create file tags
    echo -ne ";FFMETADATA1\ncomment=${TAG_LINE}\ndescription=N:$(enc_str stdin);F:" > "$INPUT_TAGS"
    enc_file /dev/stdin >> "$INPUT_TAGS"

    # Write tags from stdin
    ffmpeg -hide_banner -y \
           -i "$1" \
           -i "$INPUT_TAGS" \
           -c copy \
           -movflags use_metadata_tags \
           -map_metadata 0 \
           -map_metadata 1 \
           -f "$OUTPUT_FORMAT" \
           "${INPUT_DIR}/${OUTPUT_NAME}" \
           || die "Unable to embed and encrypt data in file."

    # Show file diff
    get_diff "$1" "${INPUT_DIR}/${OUTPUT_NAME}"
  else
    # Write tags from string
    ffmpeg -hide_banner \
           -y -i "$1" \
           -c copy \
           -movflags use_metadata_tags \
           -map_metadata 0 \
           -metadata comment="$TAG_LINE" \
           -metadata description="S:$(enc_data "$2")" \
           -f "$OUTPUT_FORMAT" \
           "${INPUT_DIR}/${OUTPUT_NAME}" \
           || die "Unable to embed data in file."

    # Show file diff
    get_diff "$1" "${INPUT_DIR}/${OUTPUT_NAME}"
  fi

  # Clean
  [[ -e "$INPUT_TAGS" ]] && rm -f "$INPUT_TAGS"
  if [[ -e "${INPUT_DIR}/${OUTPUT_NAME}" && $KEEP_ORIGINAL == false ]]; then
    mv -f "${INPUT_DIR}/${OUTPUT_NAME}" "${INPUT_DIR}/${INPUT_NAME}"
  fi
}
function get_data_ex() {
  local FCOM
  local FNAM
  local FDAT
  local FSTR
  local FTAG
  local ONAM
  local JSON

  echo -e "\nReading data from file '$(basename "$1")'...\n"
  if [[ -f "$1" ]]; then
    JSON=$(exiftool -P "$1" -json | jq -rc .)
    FCOM=$(jq -rc ".[0].Comment" <<< "$JSON")
    FTAG=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f1)
    FNAM=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f2)
    FDAT=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d";" -f2 | cut -d":" -f2)
    FSTR=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d":" -f2)
    ONAM="$(dec_str "$FNAM")"

    if [[ $FCOM == "$TAG_LINE" || -n $FTAG ]]; then
      echo -e "Found embedded content:\n"
      if [[ $FTAG == "N" ]]; then
        [[ -n $FNAM ]] && echo " - Name: $ONAM"
        [[ -n $FDAT ]] && echo " - Data: $FDAT"
        if [[ -n $FDAT ]]; then
          echo -n "$FDAT" | dec_file "$ONAM"
          if [[ -r "/tmp/$ONAM" ]]; then
            echo -e "\nFile extracted to: /tmp/$ONAM\n"
          fi
        fi
      else
        [[ -n $FSTR ]] && echo -e " - String: $(dec_data "$FSTR")\n"
      fi
    else
      echo "Nothing found."
    fi
  else
    die "Invalid source file given."
  fi
}
function get_data_ff() {
  local FCOM
  local FNAM
  local FDAT
  local FSTR
  local FTAG
  local ONAM
  local JSON

  echo -e "\nReading data from file '$(basename "$1")'...\n"
  if [[ -f "$1" ]]; then
    JSON=$(ffprobe -loglevel error -show_entries stream_tags:format_tags -of json "$1" | jq -rc .)
    FCOM=$(jq -rc ".format.tags.comment" <<< "$JSON")
    FTAG=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f1)
    FNAM=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f2)
    FDAT=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d";" -f2 | cut -d":" -f2)
    FSTR=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d":" -f2)
    ONAM="$(dec_str "$FNAM")"

    if [[ $FCOM == "$TAG_LINE" ]]; then
      echo -e "Found embedded content:\n"
      if [[ $FTAG == "N" ]]; then
        [[ -n $FNAM ]] && echo " - Name: $ONAM"
        [[ -n $FDAT ]] && echo " - Data: $FDAT"
        if [[ -n $FDAT ]]; then
          echo -n "$FDAT" | dec_file "$ONAM"
          if [[ -r "/tmp/$ONAM" ]]; then
            echo -e "\nFile extracted to: /tmp/$ONAM\n"
          fi
        fi
      else
        [[ -n $FSTR ]] && echo -e " - String: $(dec_data "$FSTR")\n"
      fi
    else
      echo "Nothing found."
    fi
  else
    die "Invalid source file given."
  fi
}
function print_data_ex() {
  local FCOM
  local FNAM
  local FDAT
  local FSTR
  local FTAG
  local ONAM
  local JSON

  log -e "\nReading data from file...\n"
  if [[ -f "$1" ]]; then
    JSON=$(exiftool -P "$1" -json | jq -rc .)
    FCOM=$(jq -rc ".[0].Comment" <<< "$JSON")
    FTAG=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f1)
    FNAM=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f2)
    FDAT=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d";" -f2 | cut -d":" -f2)
    FSTR=$(jq -rc ".[0].Description" <<< "$JSON" | cut -d":" -f2)
    ONAM="$(dec_str "$FNAM")"

    # FIXME: Tag "comment" is not added in PDF files
    if [[ $FCOM == "$TAG_LINE" || -n $FTAG ]]; then
      log -e "Found embedded content:\n"
      if [[ $FTAG == "N" ]]; then
        [[ -n $FDAT ]] && dec_data "$FDAT"
      else
        [[ -n $FSTR ]] && dec_data "$FSTR"
      fi
    else
      log "Nothing found."
    fi
  else
    die "Invalid source file given."
  fi
}
function print_data_ff() {
  local FCOM
  local FNAM
  local FDAT
  local FSTR
  local FTAG
  local ONAM
  local JSON

  log -e "\nReading data from file...\n"
  if [[ -f "$1" ]]; then
    JSON=$(ffprobe -loglevel error -show_entries stream_tags:format_tags -of json "$1" | jq -rc .)
    FCOM=$(jq -rc ".format.tags.comment" <<< "$JSON")
    FTAG=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f1)
    FNAM=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d";" -f1 | cut -d":" -f2)
    FDAT=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d";" -f2 | cut -d":" -f2)
    FSTR=$(jq -rc ".format.tags.description" <<< "$JSON" | cut -d":" -f2)
    ONAM="$(dec_str "$FNAM")"

    if [[ $FCOM == "$TAG_LINE" ]]; then
      log -e "Found embedded content:\n"
      if [[ $FTAG == "N" ]]; then
        [[ -n $FDAT ]] && dec_data "$FDAT"
      else
        [[ -n $FSTR ]] && dec_data "$FSTR"
      fi
    else
      log "Nothing found."
    fi
  else
    die "Invalid source file given."
  fi
}
function hide_data() {
  if [[ $1 == *.mp3 || $1 == *.avi || $1 == *.ogg ]]; then
    hide_data_ff "$1" "$2"
  else
    hide_data_ex "$1" "$2"
  fi
}
function dump_data() {
  # if [[ $1 == *.mp3 ]]; then
  #   print_data_ff "$1"
  # else
  #   print_data_ex "$1"
  # fi

  print_data_ex "$1"
  # print_data_ff "$1"
}
function get_data() {
  # if [[ $1 == *.mp3 ]]; then
  #   get_data_ff "$1"
  # else
  #   get_data_ex "$1"
  # fi

  get_data_ex "$1"
  # get_data_ff "$1"
}
function get_tags() {
  # if [[ $1 == *.mp3 ]]; then
  #   get_tags_ff "$1"
  # else
  #   get_tags_ex "$1"
  # fi

  get_tags_ex "$1"
  # get_tags_ff "$1"
}

# Args
while [[ $# -ne 0 ]]; do
  case $1 in
    -h|--help) print_help ;;
    -d|--debug) RUN_MODE="dump" ; shift ;;
    -e|--extract) RUN_MODE="extract" ; shift ;;
    -k|--keep) KEEP_ORIGINAL=true ; shift ;;
    -p|--pass) USE_PASSWORD=true ; shift ;;
    *) break ;;
  esac
done

# Checks
[[ $# -eq 0 ]] && print_usage
[[ $# -gt 2 ]] && die "Too many arguments."
# [[ $# -lt 2 ]] && die "Too few arguments."

# Init
print_missing
gen_key

# Main
if [[ $# -eq 1 ]]; then
  case "$RUN_MODE" in
    embed) get_tags "$1" ;;
    extract) get_data "$1" ;;
    dump) dump_data "$1" ;;
    *) die "Invalid run mode given: $RUN_MODE" ;;
  esac
else
  hide_data "$1" "$2"
fi
