# ReMeizu m681: Android 9 source checkpoint

This branch publishes the actual Android 9 device/common adaptation source from private development commit `4ed90d4dc5f974be3c764a0df5649307f1a4f4ad`. It is a source review checkpoint, not a downloadable ROM or a claim of successful boot. Original private development history is preserved; this public branch starts from an audited source export so private files are not present in ancestor commits.

The tree contains product and board configuration, init/SELinux wiring and compatibility code. The Android 11/13 adaptation passed local static product/path/copy checks before publication; those checks did not compile a ROM or prove HAL/runtime compatibility. Android 9 branches retain their board-specific historical work and known integration blockers.

## Inputs and status

Prebuilt kernels, shared libraries, compiled SELinux databases, firmware, stock archives and private operational evidence are deliberately absent. No vendor blobs or private Git history are included. `SOURCE_PROVENANCE.json` records exact upstream commit, source file hashes, exclusions and limited identifier redactions. Existing references to excluded inputs remain explicit and must be satisfied separately; they have not been replaced with success stubs.

A complete Android build still requires the matching LineageOS platform, appropriate kernel source/build output and device-specific proprietary inputs. The snapshot alone is not a blob-free ROM build recipe. For open-source-only infrastructure, restrict jobs to selected openly licensed code, source checks and separately audited GPL kernel builds; do not run stock extraction or import firmware there. Retain existing per-file copyright and license notices; this export does not relicense inherited files.

Historical notes may describe previous experiments. They do not certify the current branch on hardware. Common-tree board inheritance is not proof that M6, M3s, U10 or U20 have identical wiring.
