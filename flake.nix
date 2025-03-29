{
  description = "A flake to encapsulate Rust program compilation with customizable inputs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      crane,
      rust-overlay,
      ...
    }:
    let
      # 封装为函数，接收 flake_BuildInputs 和 rustToolchain 参数
      rustBuildFunction =
        {
          src,
          cargoToml,
          cargoLock,
          flake_BuildInputs,
          rustToolchain,
          supportedSystems,
        }:
        let
          # 手动定义支持的系统列表
          inherit supportedSystems;

          # 为特定系统构建包和开发环境的函数
          buildForSystem =
            system:
            let
              # 导入对应系统的 Nixpkgs 并应用 rust-overlay
              pkgs = import nixpkgs {
                system = system;
                overlays = [ (import rust-overlay) ];
              };

              # 导入本地构建输入配置
              local_build_pkgs = import flake_BuildInputs;
              nativeBuildInputs = (local_build_pkgs pkgs).nativeBuildInputs;
              buildInputs = (local_build_pkgs pkgs).buildInputs;

              # 配置 Crane 工具链
              craneLib = (crane.mkLib pkgs).overrideToolchain (
                pkgs.rust-bin.fromRustupToolchainFile rustToolchain
              );

              # 定义构建包的表达式
              crateExpression =
                { }:
                craneLib.buildPackage {
                  src = src;
                  strictDeps = true;
                  nativeBuildInputs = nativeBuildInputs;
                  buildInputs = buildInputs;
                  cargoToml = cargoToml;
                  cargoLock = cargoLock;
                };

              # 构建包
              myCrate = pkgs.callPackage crateExpression { };
            in
            {
              # 定义默认包
              packages.default = myCrate;

              # 定义默认开发环境
              devShells.default = craneLib.devShell {
                shellHook = ''
                  echo "Welcome to devShells for Rust!"
                '';
                packages = nativeBuildInputs;
              };
            };
        in
        # 为每个系统生成输出
        {
          packages = builtins.listToAttrs (
            builtins.map (system: {
              name = system;
              value = {
                default = (buildForSystem system).packages.default;
              };
            }) supportedSystems
          );
          devShells = builtins.listToAttrs (
            builtins.map (system: {
              name = system;
              value = {
                default = (buildForSystem system).devShells.default;
              };
            }) supportedSystems
          );
        };
    in
    {
      # 输出封装的函数
      rustBuild = rustBuildFunction;
    };
}
