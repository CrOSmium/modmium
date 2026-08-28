#!/bin/bash

source /root/.bashrc

# credit to https://github.com/zombiezen/dotfiles/blob/330c4a197d0c7bbb64727d9f31b5694a49927107/nix/nix-rebuild-profile/nix-rebuild-profile.sh
# source uses UNLICENSE but i still think a mention is warranted

set -euo pipefail
dry_run=0
usage='usage: nix-rebuild-profile [-n] [PROFILE]'
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      dry_run=1
      shift
      ;;
    --)
      shift
      break
      ;;
    --*)
      # Unrecognized option
      echo "$usage" 1>&2
      if [[ "$1" = '--help' ]]; then
        exit 0
      else
        exit 64
      fi
      ;;
    *)
      # Positional arguments
      break
      ;;
  esac
done
if [[ $# -gt 1 ]]; then
  echo "$usage" 1>&2
  exit 64
fi
profile="${1:-}"
mapfile -t out_paths < <( nix-env --query --out-path --no-name | \
  sed -e '/^[^/]/s/;/\n/g' |
  sed -e 's/^[^/=][^=]*=//' )
if [[ "${#out_paths[@]}" -eq 0 ]]; then
  exit 0
fi
if [[ "$dry_run" -ne 0 ]]; then
  echo -n 'nix-env --install --remove-all'
  if [[ -n "$profile" ]]; then
    echo -n " --profile $profile"
  fi
  for p in "${out_paths[@]}"; do
    echo ' '\\
    echo -n "  $p"
  done
  echo
  exit 0
fi

if [[ -z "$profile" ]]; then
  nix-env --install --remove-all "${out_paths[@]}"
else
  nix-env --install --remove-all --profile "$profile" "${out_paths[@]}"
fi
