## covr: skip=all
.onLoad <- function(libname, pkgname) {
  ## Initiate the R session UUID, which will also set/update
  ## .GlobalEnv$.Random.seed.
  session_uuid(attributes = FALSE)
  
  debug <- getOption("future.debug", FALSE)
  
  ## Unless already set, set option 'future.availableCores.fallback'
  ## according to environment variable 'R_FUTURE_AVAILABLECORES_FALLBACK'.
  ncores <- getOption("future.availableCores.fallback")
  if (is.null(ncores)) {
    ncores <- trim(Sys.getenv("R_FUTURE_AVAILABLECORES_FALLBACK"))
    if (nzchar(ncores)) {
      if (debug) mdebug("R_FUTURE_AVAILABLECORES_FALLBACK=%s", sQuote(ncores))
      if (is.element(ncores, c("NA_integer_", "NA"))) {
        ncores <- NA_integer_
      } else {
        ncores <- as.integer(ncores)
      }
      if (debug) mdebug(" => options(future.availableCores.fallback = %d)", ncores)
      options(future.availableCores.fallback = ncores)
    }
    ncores <- getOption("future.availableCores.fallback")
  }
  if (!is.null(ncores)) {
    if (debug) mdebug("Option 'future.availableCores.fallback = %d", ncores)
  }
  
  ## Unless already set, set option 'future.availableCores.system'
  ## according to environment variable 'R_FUTURE_AVAILABLECORES_SYSTEM'.
  ncores <- getOption("future.availableCores.system")
  if (is.null(ncores)) {
    ncores <- trim(Sys.getenv("R_FUTURE_AVAILABLECORES_SYSTEM"))
    if (nzchar(ncores)) {
      if (debug) mdebug("R_FUTURE_AVAILABLECORES_SYSTEM=%s", sQuote(ncores))
      if (is.element(ncores, c("NA_integer_", "NA"))) {
        ncores <- NA_integer_
      } else {
        ncores <- as.integer(ncores)
      }
      if (debug) mdebug(" => options(future.availableCores.system = %d)", ncores)
      options(future.availableCores.system = ncores)
    }
    ncores <- getOption("future.availableCores.system")
  }
  if (!is.null(ncores)) {
    if (debug) mdebug("Option 'future.availableCores.system = %d", ncores)
  }

  ## Unless already set, set option 'future.plan' according to
  ## system environment variable 'R_FUTURE_PLAN'.
  strategy <- getOption("future.plan")
  if (is.null(strategy)) {
    strategy <- trim(Sys.getenv("R_FUTURE_PLAN"))
    if (nzchar(strategy)) {
      if (debug) {
        mdebug("R_FUTURE_PLAN=%s", sQuote(strategy))
        mdebug(" => options(future.plan = '%s')", strategy)
      }
      options(future.plan = strategy)
    }
    strategy <- getOption("future.plan")
  }
  if (!is.null(strategy)) {
    if (debug) {
      if (is.character(strategy)) {
        mdebug("Option 'future.plan' = %s", sQuote(strategy))
      } else {
        mdebug("Option 'future.plan' of type %s", sQuote(mode(strategy)))
      }
    }
  }

  args <- parseCmdArgs()
  p <- args$p
  if (!is.null(p)) {
    if (debug) mdebug("R command-line argument: -p %s", p)
    
    ## Apply
    options(mc.cores = p)
    ## options(Ncpus = p) ## FIXME: Does it make sense? /HB 2016-04-02

    ## Set 'future.plan' option?
    if (!is.null(strategy)) {
      if (debug) mdebug(" => 'future.plan' already set.")
    } else if (p == 1L) {
      if (debug) mdebug(" => options(future.plan = sequential)")
      options(future.plan = sequential)
    } else {
      if (debug) mdebug(" => options(future.plan = tweak(multiprocess, workers = %s))", p)
      options(future.plan = tweak(multiprocess, workers = p))
    }
  }

  ## Create UUID for this process
  id <- session_uuid()

  if (debug) {
    mdebug("R process uuid: %s", id)
    mdebug("Setting plan('default')")
  }
  
  ## NOTE: Don't initiate during startup - it might hang / give an error
  plan("default", .init = FALSE)
} ## .onLoad()


## covr: skip=all
#' @importFrom utils file_test
.onAttach <- function(libname, pkgname) {
  ## Load .future.R script?
  loadDotFuture <- getOption("future.startup.loadScript", TRUE)
  if (isTRUE(loadDotFuture)) {
    debug <- getOption("future.debug", FALSE)
    
    pathnames <- c(".future.R", "~/.future.R")
    pathnames <- pathnames[file_test("-f", pathnames)]
  
    if (length(pathnames) == 0) {
      if (debug) mdebug("Future startup scripts identified: <none>")
      return()
    }
    pathname <- pathnames[1]
    if (debug) {
      mdebug("Future startup scripts identified: %s", paste(sQuote(pathnames), collapse = ", "))
      mdebug("Future startup script to load: %s", sQuote(pathname))
    }
    tryCatch({
      source(pathname, chdir = FALSE, echo = FALSE, local = FALSE)
    }, error = function(ex) {
      msg <- sprintf("Failed to source %s file while attaching the future package. Will ignore this error, but please investigate. The error message was: %s", sQuote(pathname), sQuote(ex$message))
      if (debug) mdebug(msg)
      warning(msg)
    })
  }
} ## .onAttach()
