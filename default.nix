{ stdenv, lib, makeWrapper,
  which, gnugrep, gnused, gawk, coreutils, findutils, iconv,
  jq, jo, ripgrep, httpie, htmlq, python3Packages, parallel, fzf,
  sqlite, imagemagick, pdfcpu, pandoc, mpv, xdg-utils, gost,
  brotli,
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
    brotli
  ];
in stdenv.mkDerivation {
  pname = "uniplay";
  version = "0.2.3";

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
