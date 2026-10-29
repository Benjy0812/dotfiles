# Deploy this repository's configs into ~/.config.
# Only used by the NixOS configuration; the standalone profile on
# non-NixOS systems leaves ~/.config alone.
{ dotfiles, ... }:

{
  xdg.configFile = {
    # fish: deploy everything except fish_variables, which fish needs to
    # write to at runtime.
    "fish/config.fish".source = "${dotfiles}/apps/fish/config.fish";
    "fish/conf.d".source = "${dotfiles}/apps/fish/conf.d";
    "fish/functions".source = "${dotfiles}/apps/fish/functions";
    "fish/completions".source = "${dotfiles}/apps/fish/completions";

    "kitty/kitty.conf".source = "${dotfiles}/apps/kitty/kitty.conf";

    # Recursive so the directory stays writable and Noctalia can generate
    # ~/.config/mango/noctalia.conf.
    "mango".source = "${dotfiles}/mango";
    "mango".recursive = true;

    "yazi/yazi.toml".source = "${dotfiles}/apps/yazi/yazi.toml";

    "zed/settings.json".source = "${dotfiles}/apps/zed/settings.json";
    "zed/themes".source = "${dotfiles}/apps/zed/themes";

    ".zed/settings.json".source = "${dotfiles}/apps/.zed/settings.json";
  };
}
