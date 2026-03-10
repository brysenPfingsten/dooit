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
    lib = nixpkgs.lib;
    forEachSystem = lib.genAttrs lib.platforms.all;

    pkgsFor = forEachSystem (
      system:
        import nixpkgs {
          inherit system;
        }
    );

    packageFor = system: pkgsFor.${system}.callPackage ./nix {};

    appFor = system:
      pkgsFor.${system}.python3.pkgs.toPythonApplication (packageFor system);

    withExtrasFor = system: extras: let
      pkgs = pkgsFor.${system};
      baseApp = appFor system;
    in
      pkgs.symlinkJoin {
        name = "dooit-with-extras";
        paths = [baseApp];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = let
          pythonPath = lib.concatStringsSep ":" (map (pkg: "${pkg}/${pkgs.python3.sitePackages}") extras);
        in ''
          wrapProgram $out/bin/dooit \
            --prefix PYTHONPATH : "${pythonPath}"
        '';
      };
  in {
    packages = forEachSystem (system: {
      package = packageFor system;
      app = appFor system;
      default = appFor system;
    });

    overlay = final: prev: {
      dooitPackage = final.callPackage ./nix {};
      dooit = final.python3.pkgs.toPythonApplication final.dooitPackage;
    };

    lib = forEachSystem (system: {
      withExtras = extras: withExtrasFor system extras;
    });

    homeManagerModules = {
      default = self.homeManagerModules.dooit;
      dooit = import ./nix/hm-module.nix self;
    };
  };
}
