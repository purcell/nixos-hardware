{ config, lib, ... }:

let
  cfg = config.hardware.raspberry-pi."4".fkms-3d;
in
{
  options.hardware = {
    raspberry-pi."4".fkms-3d = {
      enable = lib.mkEnableOption ''
        Enable modesetting through fkms-3d
      '';
      cma = lib.mkOption {
        type = lib.types.int;
        default = 512;
        description = ''
          Amount of CMA (contiguous memory allocator) to reserve, in MiB.

          The foundation overlay defaults to 256MiB, for backward compatibility.
          As the Raspberry Pi 4 family of hardware has ample amount of memory, we
          can reserve more without issue.

          Additionally, reserving too much is not an issue. The kernel will use
          CMA last if the memory is needed.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Configure for modesetting in the device tree
    hardware.deviceTree = {
      overlays = [
        # Equivalent to:
        # https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/cma-overlay.dts
        {
          name = "rpi4-cma-overlay";
          dtsText = ''
            // SPDX-License-Identifier: GPL-2.0
            /dts-v1/;
            /plugin/;

            / {
              compatible = "brcm,bcm2835";

              fragment@0 {
                target = <&cma>;
                __overlay__ {
                  size = <(${toString cfg.cma} * 1024 * 1024)>;
                };
              };

              __overrides__ {
                cma-512 = <&frag0>,"size:0=",<0x20000000>;
                cma-448 = <&frag0>,"size:0=",<0x1c000000>;
                cma-384 = <&frag0>,"size:0=",<0x18000000>;
                cma-320 = <&frag0>,"size:0=",<0x14000000>;
                cma-256 = <&frag0>,"size:0=",<0x10000000>;
                cma-192 = <&frag0>,"size:0=",<0xC000000>;
                cma-128 = <&frag0>,"size:0=",<0x8000000>;
                cma-96  = <&frag0>,"size:0=",<0x6000000>;
                cma-64  = <&frag0>,"size:0=",<0x4000000>;
                cma-size = <&frag0>,"size:0"; /* in bytes, 4MB aligned */
                cma-default = <0>,"-0";
              };
            };
          '';
        }
        # Equivalent to:
        # https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/vc4-fkms-v3d-pi4-overlay.dts
        {
          name = "rpi4-vc4-fkms-v3d-pi4-overlay";
          dtsText = ''
            // SPDX-License-Identifier: GPL-2.0
            /dts-v1/;
            /plugin/;

            / {
              compatible = "brcm,bcm2711";

              fragment@1 {
                target = <&fb>;
                __overlay__ {
                  status = "disabled";
                };
              };

              fragment@2 {
                target = <&firmwarekms>;
                __overlay__ {
                  status = "okay";
                };
              };

              fragment@3 {
                target = <&v3d>;
                __overlay__ {
                  status = "okay";
                };
              };

              fragment@4 {
                target = <&vc4>;
                __overlay__ {
                  status = "okay";
                };
              };
            };
          '';
        }
      ];
    };

    # Also configure the system for modesetting.

    services.xserver.videoDrivers = lib.mkBefore [
      "modesetting" # Prefer the modesetting driver in X11
      "fbdev" # Fallback to fbdev
    ];
  };
}
