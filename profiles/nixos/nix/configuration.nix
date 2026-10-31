{ config, lib, pkgs, inputs, username, ... }:

{
  # BOOTLOADER
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
  };
  boot.loader.timeout = -1;

  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };

  # NETWORK
  networking.networkmanager.enable = true;

  # TIME / LOCALE
  time.timeZone = "Europe/Oslo";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nb_NO.UTF-8";
    LC_IDENTIFICATION = "nb_NO.UTF-8";
    LC_MEASUREMENT = "nb_NO.UTF-8";
    LC_MONETARY = "nb_NO.UTF-8";
    LC_NAME = "nb_NO.UTF-8";
    LC_NUMERIC = "nb_NO.UTF-8";
    LC_PAPER = "nb_NO.UTF-8";
    LC_TELEPHONE = "nb_NO.UTF-8";
    LC_TIME = "nb_NO.UTF-8";
  };

  # DESKTOP
  # No desktop environment and no X server: ly (a TUI login manager) starts
  # MangoWM, a Wayland compositor (XWayland still runs X apps).
  # Installs mango, registers its session and sets up its portals.
  programs.mango.enable = true;
  services.displayManager.defaultSession = "mango";

  services.displayManager.ly = {
    enable = true;
    x11Support = false;
    # Every key is documented in ly's config.ini:
    # https://codeberg.org/fairyglade/ly/src/branch/master/res/config.ini
    settings = {
      animation = "doom"; # PSX DOOM fire; also matrix, colormix, gameoflife
      animation_timeout_sec = 0;
      bigclock = "en";
      bigclock_seconds = true;
      clock = "%A %d. %B";
      box_title = config.networking.hostName;
      asterisk = "0x2022"; # bullet
      clear_password = true;
      numlock = true;
      # ly remembers the last user and session, so after the first login
      # (arrow up to the login field that once) it is just the password.
      default_input = "password";
      border_fg = "0x00C78F17"; # matches the fire's middle color
    };
  };

  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  console.keyMap = "no";

  # Wayland / MangoWM
  hardware.graphics.enable = true;
  security.polkit.enable = true;

  programs.fish.enable = true;

  # What a desktop environment would otherwise bring along.
  services.gnome.gnome-keyring.enable = true; # secrets portal, saved logins
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono # terminal font in kitty/alacritty/ghostty
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.sessionVariables = {
    # Make Electron apps (Vesktop, Zed, ...) use Wayland natively.
    NIXOS_OZONE_WL = "1";
  };

  # AUDIO
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.pulseaudio.enable = false;

  # USER
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  # PACKAGES
  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Screen sharing froze after ~5 s on the monitor at x=1920: mango reports
  # damage in layout coordinates and the wlr portal crashed on it. Same patch
  # as fixes/001-xdg-portal-damage-freeze, built in here.
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./patches/xdg-desktop-portal-wlr-damage-clamp.patch ];
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    # MangoWM session and everything it launches
    mango
    kitty
    fish
    noctalia
    yazi

    # Desktop basics: cursor (set in mango/conf.d/appearance.conf), clipboard,
    # brightness keys
    bibata-cursors
    wl-clipboard
    brightnessctl

    # Applications
    vesktop
    zed-editor
    git
    github-cli
    spotify
  ];

  # Keep the flake inputs (nixpkgs, home-manager, ...) in the system closure so
  # garbage collection never deletes them and `./dotfiles.bash rebuild` works
  # offline.
  system.extraDependencies = map (input: input.outPath) (lib.attrValues (removeAttrs inputs [ "self" ]));

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    substituters = [
      "https://cache.nixos.org"
    ];
  };

  # zram
  zramSwap = {
    enable = true;
    memoryPercent = 100;
    algorithm = "zstd";
  };

  # Disable zswap when using zram
  boot.kernelParams = [
    "zswap.enabled=0"
  ];

  programs.gamemode.enable = true;

  # STATE VERSION
  system.stateVersion = "26.05";
}
