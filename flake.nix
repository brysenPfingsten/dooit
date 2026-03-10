{
  description = "Flake for Dooit with default.nix integration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    forEachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;

    pkgsFor = forEachSystem (
      system:
        import nixpkgs {
          inherit system;
        }
    );

    packageFor = system: pkgsFor.${system}.callPackage ./nix {};
  in {
    packages = forEachSystem (system: {
      package = packageFor system;
      default = pkgsFor.${system}.python3.pkgs.toPythonApplication (packageFor system);
    });

    overlay = final: prev: {
      dooitPackage = final.callPackage ./nix {};
      dooit = final.python3.pkgs.toPythonApplication final.dooitPackage;
    };

    homeManagerModules = {
      default = self.homeManagerModules.dooit;
      dooit = import ./nix/hm-module.nix self;
    };

    devShells = forEachSystem (
      system: let
        pkgs = pkgsFor.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            nodePackages.yarn
            nodePackages.npm
          ];
        };
      }
    );
  };
}
