{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

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
  networking.hostName = "benjy";
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
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  # MangoWM is the default session. Plasma stays available as a fallback;
  # remove the plasma6 line below if you only want Mango.
  services.displayManager.defaultSession = "mango";
  services.displayManager.sessionPackages = [ pkgs.mango ];
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  console.keyMap = "no";

  # Wayland / MangoWM
  hardware.graphics.enable = true;
  security.polkit.enable = true;

  programs.fish.enable = true;

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
  users.users.benjy = {
    isNormalUser = true;
    description = "Benjy";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # PACKAGES
  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # MangoWM session and everything it launches
    mango
    kitty
    fish
    noctalia
    yazi

    # Wayland portals (file pickers, screen sharing)
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr

    # Applications
    vesktop
    zed-editor
    git
    github-cli
    spotify
  ];

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

  # 16 GiB swap file as a safety net
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # MiB
    }
  ];

  # Disable zswap when using zram
  boot.kernelParams = [
    "zswap.enabled=0"
  ];

  programs.gamemode.enable = true;

  # STATE VERSION
  system.stateVersion = "26.05";
}
