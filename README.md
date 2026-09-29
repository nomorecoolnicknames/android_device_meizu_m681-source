# Meizu M3 Note China: LineageOS 16.0

Device configuration, init rules, policy and compatibility code.
Place at `device/meizu/m681` in the matching LineageOS source tree.
Provide the referenced common/MediaTek trees, matching kernel source or prebuilt,
and board-specific vendor inputs from `proprietary-files.txt` and dependency manifests.
Keep the included kernel/input checksum checks enabled.
Select `lunch lineage_m681-userdebug`.

The default kernel route uses a prebuilt. `M681_SFOS_BUILD=1` requires
`M681_KERNEL_SOURCE_OVERRIDE` or `M681_M6GRAFT_KERNEL_SOURCE` pointing to the
M681 m6-graft 3.18.140 source; it retains `m681_sfos_defconfig` unless explicitly overridden.
