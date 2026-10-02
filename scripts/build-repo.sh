#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
package_dir=${1:-"$project_dir/packages"}
output_dir=${2:-"$project_dir/repo"}

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
	printf '%s\n' "dpkg-scanpackages is required (install dpkg-dev)." >&2
	exit 1
fi
if ! command -v xz >/dev/null 2>&1; then
	printf '%s\n' "xz is required (install xz-utils)." >&2
	exit 1
fi
if [ ! -d "$package_dir" ]; then
	printf 'Package directory not found: %s\n' "$package_dir" >&2
	exit 1
fi

mkdir -p "$output_dir"
find "$output_dir" -maxdepth 1 -type f \( -name '*.deb' -o -name 'Packages*' -o -name 'Release' \) -delete
find "$package_dir" -maxdepth 1 -type f -name '*.deb' -exec cp '{}' "$output_dir/" \;

if ! find "$output_dir" -maxdepth 1 -type f -name '*.deb' -print -quit | grep -q .; then
	printf 'No .deb packages found in: %s\n' "$package_dir" >&2
	exit 1
fi

for package in "$output_dir"/*.deb; do
	[ -f "$package" ] || continue
	package_id=$(dpkg-deb -f "$package" Package)
	architecture=$(dpkg-deb -f "$package" Architecture)
	if [ "$package_id" != "com.kanka.versionspoofer" ] || [ "$architecture" != "iphoneos-arm64" ]; then
		printf 'Unexpected package metadata in %s (Package=%s, Architecture=%s).\n' \
			"$(basename "$package")" "$package_id" "$architecture" >&2
		exit 1
	fi
done

(cd "$output_dir" && dpkg-scanpackages --multiversion . /dev/null > Packages)
gzip -9 -n -c "$output_dir/Packages" > "$output_dir/Packages.gz"
xz -9 -c "$output_dir/Packages" > "$output_dir/Packages.xz"

{
	printf 'Origin: Kanka\n'
	printf 'Label: Kanka Version Spoofer\n'
	printf 'Suite: stable\n'
	printf 'Codename: stable\n'
	printf 'Architectures: iphoneos-arm64\n'
	printf 'Components: main\n'
	printf 'Description: Rootless iOS version spoofing packages\n'
	printf 'Date: %s\n' "$(date -Ru)"
	for algorithm in MD5Sum SHA1 SHA256; do
		printf '%s:\n' "$algorithm"
		for index in Packages Packages.gz Packages.xz; do
			case "$algorithm" in
				MD5Sum) hash=$(md5sum "$output_dir/$index" | cut -d ' ' -f 1) ;;
				SHA1) hash=$(sha1sum "$output_dir/$index" | cut -d ' ' -f 1) ;;
				SHA256) hash=$(sha256sum "$output_dir/$index" | cut -d ' ' -f 1) ;;
			esac
			size=$(wc -c < "$output_dir/$index" | tr -d ' ')
			printf ' %s %16s %s\n' "$hash" "$size" "$index"
		done
	done
} > "$output_dir/Release"

printf 'APT repository generated at %s\n' "$output_dir"