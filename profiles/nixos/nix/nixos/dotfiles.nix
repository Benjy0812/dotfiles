# Deploy this repository's configs into ~/.config.
# Only used by the NixOS configuration; the standalone profile on
# non-NixOS systems leaves ~/.config alone.
{ dotfiles, ... }:

{
  xdg.configFile = {
    # fish: deploy everything except fish_variables, which fish needs to
    # write to at runtime.
    "fish/config.fish".source = "${dotfiles}/profiles/nixos/fish/config.fish";
    "fish/conf.d".source = "${dotfiles}/profiles/nixos/fish/conf.d";
    "fish/functions".source = "${dotfiles}/profiles/nixos/fish/functions";
    "fish/completions".source = "${dotfiles}/profiles/nixos/fish/completions";

    "kitty/kitty.conf".source = "${dotfiles}/profiles/nixos/kitty/kitty.conf";

    # Recursive so the directory stays writable and Noctalia can generate
    # ~/.config/mango/noctalia.conf.
    "mango".source = "${dotfiles}/profiles/nixos/mango";
    "mango".recursive = true;

    "nvim/init.lua".source = "${dotfiles}/profiles/nixos/nvim/init.lua";

    "yazi/yazi.toml".source = "${dotfiles}/profiles/nixos/yazi/yazi.toml";

    "zed/settings.json".source = "${dotfiles}/profiles/nixos/zed/settings.json";
    "zed/themes".source = "${dotfiles}/profiles/nixos/zed/themes";
  };
}
