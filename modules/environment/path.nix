# Copyright (c) 2019-2022, see AUTHORS. Licensed under MIT License, see LICENSE.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.environment;
in

{

  ###### interface

  options = {

    environment = {
      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "List of packages to be installed as user packages.";
      };

      path = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Derivation for installing user packages.";
      };

      extraOutputsToInstall = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "doc" "info" "devdoc" ];
        description = "List of additional package outputs to be installed as user packages.";
      };
    };

  };


  ###### implementation

  config = {

build.activation.installPackages = ''
  nix_previous="$(command -v nix)"

  if "$nix_previous" profile list >/dev/null 2>&1; then
    # Use the new profile interface whenever it can read the
    # existing profile

    old_paths="$(
      "$nix_previous" profile list \
        | sed -n 's/^[[:space:]]*Store paths:[[:space:]]*//p' \
        | tr ' ' '\n' \
        | grep -E '^/nix/store/[^[:space:]]*-nix-on-droid-path$' \
        || true
    )"

    while IFS= read -r old_path; do
      [ -n "$old_path" ] || continue
      $DRY_RUN_CMD "$nix_previous" profile remove "$old_path" $VERBOSE_ARG
    done <<< "$old_paths"

    $DRY_RUN_CMD "$nix_previous" profile install ${cfg.path} $VERBOSE_ARG

  else
    # Compatibility with installations whose Nix does not
    # support the new profile interface.
    $DRY_RUN_CMD nix-env --install ${cfg.path}
  fi

  unset nix_previous
'';
    #build.activation.installPackages = ''
    #  if [[ -e "${config.user.home}/.nix-profile/manifest.json" ]]; then
    #    # manual removal and installation as two non-atomical steps is required
    #    # because of https://github.com/NixOS/nix/issues/6349

    #    nix_previous="$(command -v nix)"

    #    nix profile list \
    #      | grep 'nix-on-droid-path$' \
    #      | cut -d ' ' -f 4 \
    #      | xargs -t $DRY_RUN_CMD nix profile remove $VERBOSE_ARG

    #    $DRY_RUN_CMD $nix_previous profile install ${cfg.path}
#
     #   unset nix_previous
     # else
      #  $DRY_RUN_CMD nix-env --install ${cfg.path}
     # fi
   # '';

    environment = {
      packages = [
        (pkgs.callPackage ../../nix-on-droid { nix = config.nix.package; })
        pkgs.bashInteractive
        pkgs.cacert
        pkgs.coreutils
        pkgs.less # since nix tools really want a pager available, #27
        config.nix.package
      ];

      path = pkgs.buildEnv {
        name = "nix-on-droid-path";

        paths = cfg.packages;

        inherit (cfg) extraOutputsToInstall;

        meta = {
          description = "Environment of packages installed through Nix-on-Droid.";
        };
      };
    };

  };

}
