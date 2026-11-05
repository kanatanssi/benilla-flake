## Example config use

In your flake.nix:
```
  inputs = {
    benilla-flake.url = "github:kanatanssi/benilla-flake";
  };
```

In your host's config (assuming passed through inputs from the flake (`specialArgs = { inherit inputs; };`)):
```
  imports = [
    inputs.benilla-flake.nixosModules.default
  ];

...

programs.benilla = {
    enable = true;
    clientData = "/path/to/game/data";
};

```

## Don't add follows to benilla-flake.inputs.nixpkgs (nixpkgs 26.05)

Benilla requires a newer rustc than what nixpkgs 26.05 has, so unstable is used.
No: `inputs.benilla-flake.inputs.nixpkgs.follows = "nixpkgs"`.