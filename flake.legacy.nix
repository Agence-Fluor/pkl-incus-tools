{
  description = "Toolchain for the pkl-incus-tools package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = function: nixpkgs.lib.genAttrs systems function;
    in
    {
      devShells = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.pkl
              pkgs.incus.client
              pkgs.unzip
            ];
            shellHook = ''
              export PKL="${pkgs.pkl}/bin/pkl"
            '';
          };
        });
    };
}
