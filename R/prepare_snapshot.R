#' Prepare a directory for OpenAlex snapshot management
#'
#' Copies the Makefile for snapshot management to the specified directory
#' and provides instructions for creating and managing OpenAlex snapshots.
#'
#' @param path Character. The directory where the Makefile and documentation
#'   should be copied. Defaults to the current working directory.
#' @param overwrite Logical. Whether to overwrite existing files. Defaults to FALSE.
#'
#' @return Invisibly returns the path to the created Makefile.
#'
#' @details
#' This function sets up a directory for managing OpenAlex snapshots by:
#' \enumerate{
#'   \item Copying a Makefile with targets for downloading and converting snapshots
#'   \item Copying documentation about the snapshot process
#' }
#'
#' The Makefile provides the following targets:
#' \describe{
#'   \item{help}{Show available make targets}
#'   \item{snapshot}{Download/sync OpenAlex snapshot from S3}
#'   \item{arrow}{Convert snapshot to parquet format}
#'   \item{arrow_index}{Build ID indexes for fast lookups}
#'   \item{clean}{Remove generated directories}
#' }
#'
#' @examples
#' \dontrun{
#' # Prepare current directory
#' prepare_snapshot()
#'
#' # Prepare a specific directory
#' prepare_snapshot("/path/to/openalex-data")
#' }
#'
#' @export
prepare_snapshot <- function(path = ".", overwrite = FALSE) {
  # Ensure path exists

if (!dir.exists(path)) {
    cli::cli_alert_info("Creating directory: {.path {path}}")
    dir.create(path, recursive = TRUE)
  }

  # Source files from package
  makefile_src <- system.file("Makefile.snapshot", package = "openalexPro")
  vignette_src <- system.file("doc", "snapshot.html", package = "openalexPro")

  # Destination files
makefile_dst <- file.path(path, "Makefile")
  vignette_dst <- file.path(path, "snapshot_guide.html")

  # Copy Makefile
  if (file.exists(makefile_dst) && !overwrite) {
    cli::cli_alert_warning("Makefile already exists at {.path {makefile_dst}}. Use {.arg overwrite = TRUE} to replace.")
  } else {
    file.copy(makefile_src, makefile_dst, overwrite = overwrite)
    cli::cli_alert_success("Copied Makefile to {.path {makefile_dst}}")
  }

  # Copy vignette HTML if it exists
  if (file.exists(vignette_src)) {
    if (file.exists(vignette_dst) && !overwrite) {
      cli::cli_alert_warning("Documentation already exists at {.path {vignette_dst}}. Use {.arg overwrite = TRUE} to replace.")
    } else {
      file.copy(vignette_src, vignette_dst, overwrite = overwrite)
      cli::cli_alert_success("Copied documentation to {.path {vignette_dst}}")
    }
  }

  # Print instructions
  cli::cli_h1("OpenAlex Snapshot Setup Complete")
  cli::cli_text("")
  cli::cli_alert_info("Directory prepared at: {.path {normalizePath(path)}}")
  cli::cli_text("")
  cli::cli_h2("Quick Start")
  cli::cli_text("")
  cli::cli_ol(c(
    "Navigate to the directory: {.code cd {normalizePath(path)}}",
    "View available commands: {.code make help}",
    "Download the snapshot (~350GB): {.code make snapshot}",
    "Convert to parquet format: {.code make arrow}",
    "Build search indexes: {.code make arrow_index}"
  ))
  cli::cli_text("")
  cli::cli_h2("Requirements")
  cli::cli_text("")
  cli::cli_ul(c(
    "AWS CLI installed ({.code aws --version})",
    "GNU Make installed ({.code make --version})",
    "Sufficient disk space (~500GB recommended)",
    "The {.pkg openalexPro} R package installed"
  ))
  cli::cli_text("")
  cli::cli_alert_info("See {.path snapshot_guide.html} for detailed documentation.")
  cli::cli_text("")

  invisible(makefile_dst)
}
