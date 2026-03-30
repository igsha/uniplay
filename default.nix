{ stdenv, lib, makeWrapper,
  which, gnugrep, gnused, gawk, coreutils, findutils, iconv,
  jq, jo, ripgrep, httpie, htmlq, python3Packages, parallel, fzf,
  sqlite, imagemagick, pdfcpu, pandoc, mpv, xdg-utils, gost,
}:

let
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
  ];
in stdenv.mkDerivation {
  pname = "uniplay";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = deps;

  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    mkdir -p $out/{bin,share/uniplay}

    cp -r "$src/fetchers" "$out/share/uniplay/"

    cp "$src/uniplay" "$out/bin"
    chmod +x "$out/bin/uniplay"
    wrapProgram "$out/bin/uniplay" --prefix PATH : "${lib.makeBinPath deps}"
  '';
}
