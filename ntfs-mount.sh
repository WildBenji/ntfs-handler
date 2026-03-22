#!/bin/bash
# Deprecated: use 'ntfs mount' instead.
# This wrapper exists for backwards compatibility.
exec ntfs mount "$@"
