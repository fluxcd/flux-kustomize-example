#!/bin/sh

set -e

usage() {
  echo "usage: $0 {containerimage, annotation} <patch_file.yaml>" 1>&2
  exit 1
}

if [ "$#" -ne "2" ]; then
    usage
fi

# Recompute the flux patch by removing it from the kustomize file
# by comparing the base resources (without the patch) and the final
# resources (including the patch and the necessary update)
# This makes the book-keeping of the patch completely automatic
# (except for adding it initially to the Git repository).
ORIGINAL_MANIFESTS=`mktemp /tmp/originalXXXXXX`
FINAL_MANIFESTS=`mktemp /tmp/updatedXXXXXX`
TEMP_PATCH=`mktemp /tmp/patchXXXXXX`
TEMP_KUSTOMIZATION=`mktemp /tmp/kustomizationXXXXXX`
CLEANUP_COMMAND="rm -rf $ORIGINAL_MANIFESTS $FINAL_MANIFESTS $TEMP_PATCH $TEMP_KUSTOMIZATION_DIR; git checkout kustomization.yaml > /dev/null 2>&1"
trap "$CLEANUP_COMMAND" TERM QUIT EXIT # ERR (not supported by POSIX shell)

update_image() {
    kubeyaml image --namespace $FLUX_WL_NS --kind $FLUX_WL_KIND --name $FLUX_WL_NAME --container $FLUX_CONTAINER --image "$FLUX_IMG:$FLUX_TAG"
}

update_annotation() {
    kubeyaml annotate --namespace $FLUX_WL_NS --kind $FLUX_WL_KIND --name $FLUX_WL_NAME "$FLUX_ANNOTATION_KEY=$FLUX_ANNOTATION_VALUE"
}

# Obtain the final manifests
case "$1" in
"containerimage")
    kustomize build . |  update_image > $FINAL_MANIFESTS
    ;;
"annotation")
    kustomize build . |  update_annotation > $FINAL_MANIFESTS
    ;;
*)
    usage
    ;;
esac


# obtain original manifests, without the flux patch
cat kustomization.yaml | grep -v $2 > $TEMP_KUSTOMIZATION
cp $TEMP_KUSTOMIZATION kustomization.yaml
kustomize build . > $ORIGINAL_MANIFESTS


kubedelta $ORIGINAL_MANIFESTS $FINAL_MANIFESTS > $TEMP_PATCH

cp $TEMP_PATCH $2
