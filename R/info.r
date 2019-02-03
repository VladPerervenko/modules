#' Information about a physical module or package
#'
#' A \code{mod_info} represents an existing, installed module and its runtime
#' physical location (usually in the file system).
#' @param mod_spec a \code{mod_spec}
#' @param source_path character string full path to the physical module location
#' @keywords internal
#' @name info
mod_info = function (mod_spec, source_path) {
    structure(
        list(spec = mod_spec, source_path = source_path),
        class = c('mod_info', 'info')
    )
}

#' A \code{pkg_info} represents an existing, installed package.
#' @param pkg_spec a \code{pkg_spec}
#' @keywords internal
#' @name info
pkg_info = function (pkg_spec) {
    structure(list(spec = pkg_spec), class = c('pkg_info', 'info'))
}

print.info = function (x, ...) {
    cat(as.character(x, ...), '\n', sep = '')
    invisible(x)
}

as.character.mod_info = function (x, ...) {
    sprintf('%s:\n  path: \x1B[33m%s\x1B[0m', x$spec, x$source_path)
}

as.character.pkg_info = function (x, ...) {
    path = getNamespaceInfo(x$spec$name, 'path')
    sprintf('%s:\n  path: \x1B[33m%s\x1B[0m', x$spec, path)
}

is_absolute = function (spec) {
    spec$prefix[1L] %in% c('.', '..')
}

find_mod = function (spec) {
    UseMethod('find_mod')
}

find_mod.mod_spec = function (spec) {
    if (is_absolute(spec)) find_local_mod(spec) else find_global_mod(spec)
}

find_mod.pkg_spec = function (spec) {
    pkg_info(spec)
}

find_local_mod = function (spec) {
    find_in_path(spec, calling_mod_path())
}

find_global_mod = function (spec) {
    # In the future, this may be augmented by pluggable ways of loading modules.
    find_in_path(spec, mod_search_path())
}

#' Find a module’s source location
#'
#' @param spec a \code{mod_spec}.
#' @param base_paths a character vector of paths to search the module in, in
#' order of preference.
#' @return \code{find_in_path} returns a \code{mod_info} that specifies the
#' module source location.
#' @details
#' A module is physically represented in the file system either by
#' \code{‹spec_name(spec)›.r} or by \code{‹spec_name(spec)›/__init__.r}, in that
#' order of preference in case both exist. File extensions are case insensitive
#' to allow for R’s obsession with capital-R extensions (but lower-case are
#' given preference, and upper-case file extensions are discouraged).
#' @keywords internal
find_in_path = function (spec, base_paths) {
    mod_path_prefix = merge_path(spec$prefix)
    ext = c('.r', '.R')
    # TODO: Write unit test that ensures the module is found in the correct
    # order of preference of paths, when multiple possibilities exist.
    simple_mod = file.path(mod_path_prefix, paste0(spec$name, ext))
    nested_mod = file.path(mod_path_prefix, spec$name, paste0('__init__', ext))
    candidates = lapply(base_paths, file.path, c(simple_mod, nested_mod))
    hits = lapply(candidates, file.exists)
    which_base = which(vapply(hits, any, logical(1L)))[1L]

    if (is.na(which_base)) {
        stop(
            'Unable to load module ', sQuote(spec_name(spec)),
            '; not found in ', paste(sQuote(base_paths), collapse = ', ')
        )
    }

    path = candidates[[which_base]][hits[[which_base]]][1L]
    base_path = base_paths[which_base]
    mod_info(spec, normalizePath(path))
}
