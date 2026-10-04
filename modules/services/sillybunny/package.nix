# SillyBunny packaging -- a SillyTavern fork (Bun backend, reworked UI) that is
# not in nixpkgs, so it is built here and pulled in by the module beside it as
# `sillybunny.package`. No flake input or overlay: the source is pinned by tag
# in this file, so a bump is one edit here. Deliberately modelled on the nixpkgs
# `sillytavern` derivation it replaces: a global npm install under
# $out/lib/node_modules, no build step, runtime state entirely outside the store.
#
# Bumping: change `version` to the new upstream tag minus its `v` prefix (tags
# are `v1.8.1` from 1.8.0 on; 1.7.0 and earlier had none), set both hashes to
# lib.fakeHash, build twice and paste the hashes nix prints:
#   nix build --impure --expr 'let f = builtins.getFlake (toString ./.); in
#     f.inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage
#       ./modules/services/sillybunny/package.nix {}'
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "sillybunny";
  version = "1.8.1";

  src = fetchFromGitHub {
    owner = "SillyBunnyTeam";
    repo = "SillyBunny";
    tag = "v${finalAttrs.version}";
    # Upstream commits ~400 MB of past release zips, a 23 MB dependency-graph
    # dump and the screenshot set into the repo. None of it is used at runtime,
    # and keeping it would put all of it in the store on every version bump, so
    # it is dropped before the source is hashed -- hence a hash that does not
    # match a plain `nix-prefetch-url --unpack` of the tarball.
    postFetch = ''
      rm -rf "$out"/releases "$out"/graphify-out "$out"/screenshots "$out"/output "$out"/tests
    '';
    hash = "sha256-v1tiSKMRDf84Ho8Zm04hIxb9wl6YfKv0YYxPT8RNn8c=";
  };
  npmDepsHash = "sha256-dRY/VC7Xl3hRD/xpbKAcS1fcZPDMLh7fh3CdtHf+45M=";

  # There is no build script: the only bundling step is webpack over
  # public/lib.js, which the server runs itself on first start and caches in
  # <dataRoot>/_webpack. Pre-building it here would be pointless anyway -- the
  # cache key includes the runtime (Bun vs Node), so the server recompiles.
  dontNpmBuild = true;

  # Upstream's .npmrc sets min-release-age=7, a registry-side npm 11 policy that
  # makes no sense against the fixed offline cache buildNpmPackage installs from
  # and only produces warnings. Dropped so the install log stays readable.
  postPatch = ''
    rm -f .npmrc
  '';

  # Created by the Dockerfile/launcher at runtime upstream, which the read-only
  # store cannot do. third-party is where the extension manager clones into --
  # the NixOS module bind-mounts writable state over it.
  postInstall = ''
    mkdir -p $out/lib/node_modules/sillybunny/{backups,public/scripts/extensions/third-party}
  '';

  meta = {
    description = "SillyTavern fork with a reworked UI and a Bun backend";
    longDescription = ''
      SillyBunny is a fork of SillyTavern aimed at LLM creative writing: the
      same backend lineage and data format, with a shell-style UI, bundled
      presets and extensions, and in-chat agent support.

      Packaged as a global install (state under $XDG_DATA_HOME/SillyBunny),
      matching how nixpkgs packages SillyTavern. Runs on Node here rather than
      Bun; upstream supports both and auto-selects Node on several platforms.
    '';
    homepage = "https://github.com/SillyBunnyTeam/SillyBunny";
    downloadPage = "https://github.com/SillyBunnyTeam/SillyBunny/releases";
    changelog = "https://github.com/SillyBunnyTeam/SillyBunny/blob/${finalAttrs.version}/changelog.md";
    license = lib.licenses.agpl3Only;
    mainProgram = "sillybunny";
    platforms = nodejs.meta.platforms;
  };
})
