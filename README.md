# Experimental LineageOS 24 / Android 17 for Exynos 7420

Targets: Galaxy S6 SM-G920F (`zeroflte`) and Galaxy S6 edge SM-G925F (`zerolte`).

This is a development port, not a tested release. Initial baseline: common and
vendor `lineage-21.0-unify`, kernel `lineage-21`, unified device trees
`lineage-20.0-unify`, and Exynos BSP `lineage-21.0`.
Exact device, vendor, kernel and BSP revisions are recorded in `sources.json`.
The generated resolved manifest is uploaded with every build's diagnostics.

The workflow builds both devices sequentially on a standard public Ubuntu runner.
On compilation failure it preserves the source/output directories for 45 minutes
and retries when a fast-forward update to this repository is available. Runner
expiry or a new workflow run cannot preserve that runner's compilation outputs.
Old upstream LineageOS 20 framework patch bundles are not applied blindly to
Android 17. Compatibility changes must be reviewed against current sources.

Initial migration removes obsolete Blueprint `subdirs` declarations, corrects
task-profile source paths, supplies the release component in lunch choices, and
explicitly supplies the legacy compiler and VNDK 29 dependencies. Old GKI binary
kernel prebuilts that these devices do not use are excluded to save runner disk.

A successful build alone does not establish boot, modem, camera, GPU, encryption
or other hardware functionality. No device flashing has been performed.
