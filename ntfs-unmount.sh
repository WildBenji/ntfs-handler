#!/bin/bash
# Deprecated: use 'ntfs unmount' instead.
# This wrapper exists for backwards compatibility.
exec ntfs unmount "$@"
