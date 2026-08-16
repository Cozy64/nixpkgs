{
  stdenv,
  lib,
  checkbashisms,
  coreutils,
  ethtool,
  fetchFromGitHub,
  gawk,
  gnugrep,
  gnused,
  hdparm,
  iw,
  kmod,
  makeWrapper,
  pciutils,
  perl,
  perlcritic,
  shellcheck,
  smartmontools,
  systemd,
  udevCheckHook,
  usbutils,
  util-linux,
  glib,
  x86_energy_perf_policy,
  enableRDW ? false,
  networkmanager,
  tlp-pd,
}:

stdenv.mkDerivation rec {
  pname = "tlp";
  version = "1.10.2";

  src = fetchFromGitHub {
    owner = "linrunner";
    repo = "TLP";
    rev = version;
    hash = "sha256-/xTg53eJ+AKrlG++nQGLsosaWzg1JrwGIGB2+h0MZDI=";
  };

  patches = [
    ./patches/0001-makefile-correctly-sed-paths.patch
    ./patches/0002-reintroduce-tlp-sleep-service.patch
  ];

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail ' ?= /usr/' ' ?= /'
  '';

  buildInputs = [ perl ];

  nativeBuildInputs = [
    makeWrapper
    udevCheckHook
  ];

  makeFlags = [
    "TLP_NO_INIT=1"
    "TLP_WITH_ELOGIND=0"
    "TLP_WITH_SYSTEMD=1"
    "DESTDIR=${placeholder "out"}"
  ];

  installTargets = [
    "install-tlp"
    "install-man-tlp"
  ]
  ++ lib.optionals enableRDW [
    "install-rdw"
    "install-man-rdw"
  ];

  doCheck = true;
  nativeCheckInputs = [
    checkbashisms
    perlcritic
    shellcheck
  ];
  checkTarget = [ "checkall" ];

  doInstallCheck = true;

  postInstall =
    let
      paths = lib.makeBinPath (
        [
          coreutils
          ethtool
          gawk
          gnugrep
          gnused
          hdparm
          iw
          kmod
          pciutils
          perl
          smartmontools
          systemd
          usbutils
          util-linux
          glib
        ]
        ++ lib.optional enableRDW networkmanager
        ++ lib.optional (lib.meta.availableOn stdenv.hostPlatform x86_energy_perf_policy) x86_energy_perf_policy
      );
    in
    ''
      fixup_perl=(
        $out/share/tlp/tlp-pcilist
        $out/share/tlp/tlp-readconfs
        $out/share/tlp/tlp-usblist
      )
      for f in "''${fixup_perl[@]}"; do
        if [ -f "$f" ]; then
          wrapProgram "$f" --prefix PATH : "${paths}"
        fi
      done

      fixup_bash=(
        $out/bin/*
        $out/etc/NetworkManager/dispatcher.d/*
        $out/lib/udev/tlp-*
        $out/sbin/*
        $out/share/tlp/bat.d/*
        $out/share/tlp/func.d/*
        $out/share/tlp/tlp-func-base
      )
      for f in "''${fixup_bash[@]}"; do
        if [ -f "$f" ]; then
          sed -i '2iexport PATH=${paths}:$PATH' "$f"
        fi
      done

      rm -rf $out/var
      rm -rf $out/share/metainfo
    '';

  passthru.tests = {
    inherit tlp-pd;
  };

  meta = {
    description = "Advanced Power Management for Linux";
    homepage = "https://linrunner.de/en/tlp/docs/tlp-linux-advanced-power-management.html";
    changelog = "https://github.com/linrunner/TLP/releases/tag/${version}";
    platforms = lib.platforms.linux;
    mainProgram = "tlp";
    maintainers = with lib.maintainers; [
      lovesegfault
    ];
    license = lib.licenses.gpl2Plus;
  };
}
