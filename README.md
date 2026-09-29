# Meizu M3 Note China: LineageOS 16.0

Device configuration, init rules, SELinux policy and compatibility code for Android 9.
Place this tree at `device/meizu/m681` in the matching LineageOS source tree.

The build requires the referenced common and MediaTek platform trees, matching kernel
source/headers and prebuilt image where selected, and this board’s proprietary inputs.
Use `proprietary-files.txt`, dependency manifests and kernel checks provided by this branch.
Prebuilt firmware and complete ROM images are not supplied by this repository.

After providing those inputs, select `lunch lineage_m681-userdebug`.
These sources remain under development; compiling them does not certify all hardware
or establish a tested installable release.

Retain the copyright and license notices in individual files.

The default kernel route uses a prebuilt. `M681_SFOS_BUILD=1` requires
`M681_KERNEL_SOURCE_OVERRIDE` or `M681_M6GRAFT_KERNEL_SOURCE` pointing to the
M681 m6-graft 3.18.140 source; it retains `m681_sfos_defconfig` unless explicitly overridden.
