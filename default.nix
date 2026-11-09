{ stdenv, lib, makeWrapper,
  which, gnugrep, gnused, gawk, coreutils, findutils, iconv,
  jq, jo, ripgrep, httpie, htmlq, python3Packages, parallel, fzf,
  sqlite, imagemagick, pdfcpu, pandoc, mpv, xdg-utils, gost,
  brotli, wkhtmltopdf, typst, pup, lua5_4, fetchurl, fetchFromGitHub
}:

let
  lua = lua5_4.override {
    packageOverrides = luaself: luaprev: {
      lusoup = luaprev.buildLuarocksPackage {
        pname = "lusoup";
        version = "0.1.0-1";
        src = fetchFromGitHub {
          owner = "valhalla803";
          repo = "lusoup";
          rev = "v0.1.0";
          hash = "sha256-ZKfGEtTzjj/wjNH2kDeZOsEhBMFqg9S6bDxMq9X0AkA=";
        };
      };
      lureq = luaprev.buildLuarocksPackage {
        pname = "lureq";
        version = "0.1.1-1";
        src = fetchFromGitHub {
          owner = "valhalla803";
          repo = "lureq";
          rev = "v0.1.1";
          hash = "sha256-HzmFLNP2pB9cpxyn0zzc3J5BR12SbIAUq0+GpZpCqio=";
        };
        propagatedBuildInputs = with luaprev; [
          luasocket
          luasec
        ];
      };
    };
  };
  deps = [
    which
    gnugrep
    gnused
    gawk
    coreutils # sha1sum tee tr tac md5sum sort head base64 cut
    findutils # xargs
    iconv
    jq
    jo
    ripgrep
    httpie
    htmlq
    python3Packages.yq
    parallel
    fzf
    sqlite
    imagemagick
    pdfcpu
    pandoc
    mpv
    xdg-utils
    gost
    brotli
    wkhtmltopdf
    typst
    pup
    (lua.withPackages (ps: with ps; [
      json
      lusoup
      lureq
      argparse
      md5
      luafilesystem
    ]))
  ];
in stdenv.mkDerivation {
  pname = "uniplay";
  version = "0.3.21";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = deps;

  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    mkdir -p $out/{bin,share/uniplay}

    cp -r "$src/fetchers" "$src/utilities" "$out/share/uniplay/"

    cp "$src/uniplay" "$src/s-uniplay" "$out/bin"
    chmod +x "$out/bin/uniplay" "$out/bin/s-uniplay"
    wrapProgram "$out/bin/s-uniplay" --prefix PATH : "${lib.makeBinPath deps}"
  '';

  meta = with lib; {
    description = "A universal media parser/player";
    homepage = "https://github.com/igsha/uniplay";
    maintainers = [ maintainers.igsha ];
    platforms = platforms.unix;
    license = licenses.mit;
  };
}
