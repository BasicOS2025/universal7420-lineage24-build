#!/usr/bin/env bash
set -euo pipefail
control="$GITHUB_WORKSPACE"
source_dir="$RUNNER_TEMP/universal7420-lineage24"
logs="$RUNNER_TEMP/universal7420-logs"
mkdir -p "$source_dir" "$logs" "$RUNNER_TEMP/universal7420-roms"
exec > >(tee -a "$logs/session.log") 2>&1
cd "$source_dir"
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --depth=1 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp "$control/manifests/universal7420.xml" .repo/local_manifests/
repo sync -c -j4 --no-clone-bundle --no-tags --fail-fast
repo manifest -r -o "$logs/resolved-manifest.xml"
python3 "$control/ci/apply-port.py" "$source_dir"
df -h
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR="$RUNNER_TEMP/ccache"
ccache -M 4G
export BUILD_USERNAME=BasicOS2025 BUILD_HOSTNAME=github-actions
export ALLOW_MISSING_DEPENDENCIES=false
devices="${DEVICES:-both}"
if [[ "$devices" == both ]]; then devices="zeroflte zerolte"; fi
for device in $devices; do
  case "$device" in zeroflte|zerolte) ;; *) exit 2 ;; esac
  for attempt in $(seq 1 20); do
    set +e
    (
      source build/envsetup.sh
      source vendor/lineage/vars/aosp_target_release
      lunch "lineage_${device}-${aosp_target_release}-userdebug" && m -j4 bacon
    ) 2>&1 | tee "$logs/${device}-attempt-${attempt}.log"
    result=${PIPESTATUS[0]}
    set -e
    if [[ "$result" == 0 ]]; then
      python3 "$control/ci/collect.py" "$source_dir/out/target/product/$device" "$RUNNER_TEMP/universal7420-roms/$device"
      break
    fi
    echo "::error::${device} attempt ${attempt} failed. Preserving outputs and waiting up to 45 minutes for a fix."
    tail -n 100 "$logs/${device}-attempt-${attempt}.log" >> "$GITHUB_STEP_SUMMARY"
    revision=$(git -C "$control" rev-parse HEAD)
    changed=false
    for poll in $(seq 1 90); do
      sleep 30
      if git -C "$control" fetch origin main --depth=50 && [[ $(git -C "$control" rev-parse FETCH_HEAD) != "$revision" ]]; then
        git -C "$control" merge --ff-only FETCH_HEAD
        python3 "$control/ci/apply-port.py" "$source_dir"
        changed=true
        break
      fi
    done
    if [[ "$changed" != true || "$attempt" == 20 ]]; then exit "$result"; fi
  done
done
ccache -s
