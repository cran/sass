# Generated by staticimports; do not edit by hand.
# ======================================================================
# Imported from pkg:staticimports
# ======================================================================

get_package_version <- function(pkg) {
  # `utils::packageVersion()` can be slow, so first try the fast path of
  # checking if the package is already loaded.
  ns <- .getNamespace(pkg)
  if (is.null(ns)) {
    utils::packageVersion(pkg)
  } else {
    as.package_version(ns$.__NAMESPACE__.$spec[["version"]])
  }
}

is_installed <- function(pkg, version = NULL) {
  installed <- isNamespaceLoaded(pkg) || nzchar(system_file_cached(package = pkg))
  if (is.null(version)) {
    return(installed)
  }
  installed && isTRUE(get_package_version(pkg) >= version)
}

# A wrapper for `system.file()`, which caches the results, because
# `system.file()` can be slow. Note that because of caching, if
# `system_file_cached()` is called on a package that isn't installed, then the
# package is installed, and then `system_file_cached()` is called again, it will
# still return "".
system_file_cached <- local({
  pkg_dir_cache <- character()

  function(..., package = "base") {
    if (!is.null(names(list(...)))) {
      stop("All arguments other than `package` must be unnamed.")
    }

    not_cached <- is.na(match(package, names(pkg_dir_cache)))
    if (not_cached) {
      pkg_dir <- system.file(package = package)
      pkg_dir_cache[[package]] <<- pkg_dir
    } else {
      pkg_dir <- pkg_dir_cache[[package]]
    }

    file.path(pkg_dir, ...)
  }
})
