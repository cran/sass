# A registry of caches for different directories
.caches <- new.env(parent = emptyenv())


#' Get and set the cache object registered for a specific directory
#'
#' @details
#'
#' If `sass_cache_get_dir()` is called for a given directory, before
#' `sass_cache_set_dir()` has been called for that directory, then it will
#' return `NULL`.
#'
#' After `sass_cache_set_dir()` is called for a directory, any future calls to
#' `sass_cache_get_dir()` with that directory will return that specific cache
#' object. This can be useful if you customize parameters for the cache object,
#' like maximum size or age.
#'
#'
#' @param dir A directory. An error will be thrown if the directory does not
#'   exist.
#' @param cache A [sass_file_cache()] object, or `NULL` if you don't want to
#'   unset the cache for a directory.
#' @param create If `TRUE`, then if the cache directory doesn't exist, or if
#'   there is not a registered cache object for the directory, create them as
#'   needed.
#'
#' @seealso [sass_cache_get()], [sass_file_cache()], [sass()]
#'
#' @keywords internal
#' @export
sass_cache_get_dir <- function(dir, create = FALSE) {
  if (create) {
    # Create dir if needed
    if (!dir.exists(dir)) {
      dir.create2(dir)
    }
    dir <- normalizePath(dir, mustWork = TRUE)

    # Create cache object if needed
    if (is.null(.caches[[dir]])) {
      sass_cache_set_dir(dir, sass_file_cache(dir))
    }

  } else {
    if (!dir.exists(dir)) {
      stop("`dir` does not exist.")
    }
  }

  dir <- normalizePath(dir, mustWork = TRUE)
  .caches[[dir]]
}

#' @rdname sass_cache_get_dir
#' @export
sass_cache_set_dir <- function(dir, cache) {
  if (!is.null(cache) && !inherits(cache, "FileCache")) {
    stop("`cache` must be a FileCache object or NULL.")
  }
  if (!dir.exists(dir)) {
    stop("`dir` does not exist.")
  }

  dir <- normalizePath(dir, mustWork = TRUE)

  if (is.null(cache)) {
    # Unset the cache registered for a directory
    if (exists(dir, envir = .caches, inherits = FALSE)) {
      rm(list = dir, envir = .caches)
    }
    return(invisible(NULL))
  }

  if (!identical(dir, normalizePath(cache$dir()))) {
    stop("`dir` and the cache object's directory do not match.")
  }

  .caches[[dir]] <- cache
  invisible(cache)
}

#' Retrieve the default file cache
#'
#' @description
#'
#' When caching is enabled, this function returns a [sass_file_cache()] object
#' that [sass()]'s `cache` argument uses (by default) for caching Sass
#' compilation. When caching is disabled (either by setting the `sass.cache`
#' option to `FALSE`, `NULL`, or via [shiny::devmode()]), this function returns
#' `NULL` (effectively telling [sass()] to not `cache` by default).
#'
#' @details
#'
#' When caching is enabled, then this function returns a `sass_file_cache()`
#' object that (by default) uses [sass_cache_context_dir()] for its directory.
#' The directory can also be customized by providing the `sass.cache` option
#' with either a filepath (as a string) or a full-blown `sass_file_cache()`
#' object.
#'
#' @seealso [sass_cache_get_dir()], [sass()]
#'
#' @export
sass_cache_get <- function() {
  cache_option <-
    get_shiny_devmode_option(
      "sass.cache",
      default = TRUE,
      devmode_default = FALSE,
      devmode_message = "Turning off caching of Sass -> CSS compilation. To turn caching on, call `options(sass.cache = TRUE)`"
    )

  if (is.null(cache_option) || identical(cache_option, FALSE)) {
    return(NULL)
  }
  if (inherits(cache_option, "FileCache")) {
    return(cache_option)
  }

  cache_dir <- NULL
  if (is.character(cache_option)) {
    cache_dir <- cache_option
  }

  # Default case
  if (is.null(cache_dir)) {
    cache_dir <- sass_cache_context_dir()
  }

  sass_cache_get_dir(cache_dir, create = TRUE)
}

#' Return the cache directory for the current context.
#'
#' @details
#'
#' In most cases, this function returns the user's cache directory, by calling
#' `tools::R_user_dir("sass", which = "cache")` (for R 4.0 and above) or
#' `rappdirs::user_cache_dir("R-sass")` (for older versions of R).
#'
#' If this function is called from a Shiny application, it will also look for a
#' subdirectory named `app_cache/`. If it exists, it will use a directory named
#' `app_cache/sass/` to store the cache.
#'
#' When running a Shiny application in a typical R session, it will not create
#' the `app_cache/` subdirectory, but it will use it if present. This scopes the
#' cache to the application.
#'
#' With Shiny applications hosted on Shiny Server and Connect, it _will_ create
#' a `app_cache/sass/` subdirectory, so that the cache is scoped to the
#' application and will not interfere with another application's cache.
#'
#' @keywords internal
#' @export
sass_cache_context_dir <- function() {
  tryCatch(
    {
      # The usual place we'll look. This may be superseded below.
      cache_dir <- find_cache_dir("sass")

      if (is_shiny_app()) {
        # We might use ./cache/sass, if it's a hosted app, or if the directory
        # already exists. (We won't automatically create the directory on
        # locally-running apps.)
        app_dir <- shiny::getShinyOption("appDir")
        app_cache_dir <- file.path(app_dir, "app_cache", "sass")
        if (is_hosted_app()) {
          # On hosted platforms, always create a ./cache/sass subdir for caching
          # sass stuff.
          cache_dir <- app_cache_dir

        } else {
          # When running an app in a normal R session...
          if (dir.exists(app_cache_dir) || dir.exists(dirname(app_cache_dir))) {
            # If ./cache/sass or ./cache already exists, use it.
            cache_dir <- app_cache_dir
          }
        }
      }

      if (!dir.exists(cache_dir)) {
        res <- dir.create(cache_dir, recursive = TRUE)
        if (!res) {
          stop("Error creating cache directory")
        }
      }
    },
    error = function(e) {
      # If all of the attempts to find/create a dir failed, just use a temp dir.
      warning("Error using cache directory at '", cache_dir,
              "'. Using temp dir instead.")

      cache_dir <<- tempfile("sass-")
      dir.create(cache_dir)
    }
  )
  normalizePath(cache_dir)
}


#' Returns a hash of the object, including sass_file mtimes
#'
#' This function returns a hash of the object `x`, intended for use in caching.
#' It recurses into lists, and any [sass_file()] objects will have the file's
#' mtime attached as an attribute. This is useful for detecting if the file has
#' been modified.
#'
#' @param x A list with sass objects.
#' @noRd
sass_hash <- function(x) {
  rlang::hash(
    add_sass_file_mtime(list(x, get_package_version("sass")))
  )
}

# Given an object, return an object that can be \code{rlang::hash}-ed into a
# hash key. This traverses the object and adds file mtimes for files imported
# via `sass_file` directives (but not files that are imported by those files).
add_sass_file_mtime <- function(x) {
  if (inherits(x, "sass_file")) {
    # Add the file's mtime to the cache key. This will cause mtime changes to
    # bust the cache.
    input_path <- attr(x, "sass_file_path", exact = TRUE)
    attr(x, "sass_timestamp") <- file.mtime(input_path)
    x
  } else if (inherits(x, "list")) {
    lapply(x, add_sass_file_mtime)
  } else {
    x
  }
}


find_cache_dir <- function(pkg) {
  # In R 4.0 and above, CRAN wants us to use the new tools::R_user_dir().
  # If not present, fall back to rappdirs::user_cache_dir().
  R_user_dir <- getNamespace('tools')$R_user_dir
  if (!is.null(R_user_dir)) {
    R_user_dir(pkg, which = "cache")
  } else {
    rappdirs::user_cache_dir(paste0("R-", pkg))
  }
}


#' Caching Options for Sass (defunct)
#'
#' This function is no longer used. Please see [sass_cache_get()].
#' @param cache No longer used.
#' @param cache_dir  No longer used.
#' @export
#' @keywords internal
sass_cache_options <- function(cache, cache_dir) {
  message(
    "The function `sass_cache_options` is no longer used. ",
    "Please see ?sass_cache_set and ?sass_file_cache"
  )
}
