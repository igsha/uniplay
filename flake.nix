{
  description = "A universal player";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
  in {
    packages.x86_64-linux = {
      uniplay = pkgs.callPackage ./. { };
      default = self.packages.x86_64-linux.uniplay;
    };
    devShells.x86_64-linux = {
      default = pkgs.mkShell {
        inputsFrom = [ self.packages.x86_64-linux.uniplay ];
      };
    };
  };
}
