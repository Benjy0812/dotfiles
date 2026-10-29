# Deploy this repository's configs into ~/.config.
# Only used by the NixOS configuration; the standalone profile on
# non-NixOS systems leaves ~/.config alone.
{ dotfiles, ... }:

{
  xdg.configFile = {
    # fish: deploy everything except fish_variables, which fish needs to
    # write to at runtime.
    "fish/config.fish".source = "${dotfiles}/fish/config.fish";
    "fish/conf.d".source = "${dotfiles}/fish/conf.d";
    "fish/functions".source = "${dotfiles}/fish/functions";
    "fish/completions".source = "${dotfiles}/fish/completions";

    "kitty/kitty.conf".source = "${dotfiles}/kitty/kitty.conf";

    # Recursive so the directory stays writable and Noctalia can generate
    # ~/.config/mango/noctalia.conf.
    "mango".source = "${dotfiles}/mango";
    "mango".recursive = true;

    "yazi/yazi.toml".source = "${dotfiles}/yazi/yazi.toml";

    "zed/settings.json".source = "${dotfiles}/zed/settings.json";
    "zed/themes".source = "${dotfiles}/zed/themes";

    ".zed/settings.json".source = "${dotfiles}/.zed/settings.json";
  };
}
