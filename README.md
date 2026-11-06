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

    # optional client settings, these override made in game
    settings = {
      gxMultisample = "4";  # MSAA
      anisotropic = "16";   # texture filtering, 1-16
      farclip = "777";      # view distance, 177-777
      renderScale = "1.5";  # world render resolution multiplier, 0.25-4.0
    };
};

```

## Substituting Benilla with a fork

You can swap the benilla source with a fork, for example
[everwood graphics fork](https://github.com/pkuzic/benilla-everwood_graphics) if you want to experiment with graphics settings:

```
  inputs = {
    benilla-flake.url = "github:kanatanssi/benilla-flake";
    benilla-flake.inputs.benilla.url = "github:pkuzic/benilla-everwood_graphics";
  };
```
Forks might lag behind benilla in commits, so check how far behind before switching. This will usually cause a full rebuild and take a while.

## Don't add follows to benilla-flake.inputs.nixpkgs (nixpkgs 26.05)

Benilla requires a newer rustc than what nixpkgs 26.05 has, so unstable is used.
No: `inputs.benilla-flake.inputs.nixpkgs.follows = "nixpkgs"`.