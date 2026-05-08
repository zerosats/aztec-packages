{
  description = "Rust Development Shell";
  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        # Pin a single NDK version so $ANDROID_HOME/ndk/$NDK_VERSION/...
        # (the layout bb_rs/build.rs expects) actually exists.
        ndkVersion = "27.0.12077973";

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformToolsVersion = "35.0.2";
          buildToolsVersions   = [ "34.0.0" ];
          platformVersions     = [ "33" "34" ];
          abiVersions          = [ "arm64-v8a" "armeabi-v7a" "x86" "x86_64" ];
          includeNDK           = true;
          ndkVersions          = [ ndkVersion ];
        };
        androidSdk = androidComposition.androidsdk;

        # Path to the actual SDK tree inside the Nix store output.
        androidSdkRoot = "${androidSdk}/libexec/android-sdk";

        # NDK $HOST_TAG — the prebuilt-toolchain subdirectory name.
        # Note: darwin-arm64 hosts use the darwin-x86_64 universal toolchain.
        hostTag =
          if pkgs.stdenv.isDarwin then "darwin-x86_64"
          else if pkgs.stdenv.isLinux then "linux-x86_64"
          else throw "Unsupported host for Android NDK: ${system}";
      in
      with pkgs;
      {
        devShells.default = mkShell {
          buildInputs = [
            # Development tools
            rustup
            cmake
            pkg-config
            ninja
            llvmPackages.clang
            llvmPackages.openmp
            llvmPackages_latest.bintools
            #xcbuild

            # Runtime dependencies (note: most are also fetched by CMake
            # at build time, so several here may be redundant for bb_rs)
	    bash
            tracy
            msgpack-cxx
            nlohmann_json
            httplib
            openssl
            libdeflate
            lmdb
            backward-cpp
            elfutils.dev
		
            # Mobile
	    zig

            # Android — composed SDK includes platform-tools and the NDK
            androidSdk
            jdk
          ];

          shellHook = ''
            export ALLOW_NINJA_ENV=true
            export USE_CCACHE=1

            # bb_rs/build.rs reads ANDROID_HOME, NDK_VERSION, and HOST_TAG
            # via option_env! at compile time, then assembles paths of the form:
            #   $ANDROID_HOME/ndk/$NDK_VERSION/build/cmake/android.toolchain.cmake
            #   $ANDROID_HOME/ndk/$NDK_VERSION/toolchains/llvm/prebuilt/$HOST_TAG/sysroot/...
            export ANDROID_HOME="${androidSdkRoot}"
            export ANDROID_SDK_ROOT="${androidSdkRoot}"
            export ANDROID_NDK_HOME="${androidSdkRoot}/ndk/${ndkVersion}"
            export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
            export NDK_VERSION="${ndkVersion}"
            export HOST_TAG="${hostTag}"

            echo "ANDROID_HOME      = $ANDROID_HOME"
            echo "ANDROID_NDK_HOME  = $ANDROID_NDK_HOME"
            echo "NDK_VERSION       = $NDK_VERSION"
            echo "HOST_TAG          = $HOST_TAG"

            # Sanity check — fail loudly here rather than mid-build.
            if [ ! -f "$ANDROID_NDK_HOME/source.properties" ]; then
              echo "WARNING: $ANDROID_NDK_HOME/source.properties is missing."
              echo "         Check that ndkVersion in flake.nix matches a"
              echo "         version available in nixpkgs androidenv."
            fi
          '';

          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
          LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
        };
      }
    );
}
