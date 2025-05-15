#' Plot an Interactive Citation Network from a Snowball Search
#'
#' This function creates a interactive snowball seaarch network using the networkD3 package.
#'
#' @param snowball The snowball object containing the network data. The object is returned from the
#'   \link[openalexR]{oa_snowball} function in the `openalexR`` package
#' @param key_works A data frame, as returned. e.g. by `oa_fetch(entity = "works", ...`,
#'   containing the key-works from the snowball search which will be highlighted in the network.
#' @param file The file name to save the network to. TThe directory has tro esxist.
#'   Default: `NULL`, i.e. not saved.
#'
#' @importFrom networkD3 forceNetwork
#' @importFrom DT JS
#' @importFrom dplyr mutate select rename left_join
#'
#' @return A networkD3 object representing the interactive network plot.
#'
#' @md
#'
#' @examples
#' \dontrun{
#' plot_snowball_interactive(snowball, key_works, file)
#' }
#' @export
plot_snowball_interactive <- function(snowball, key_works, file) {
    ## Simple forceNetwork
    networkData <- data.frame(
        src = snowball$edges$from,
        target = snowball$edges$to,
        stringsAsFactors = FALSE
    )

    nodes <- data.frame(
        name = snowball$nodes$id,
        author = abbreviate_authors(snowball$nodes),
        doi = snowball$nodes$doi,
        nodesize = snowball$nodes$cited_by_count / (2024 - snowball$nodes$publication_year) * 0.5,
        stringsAsFactors = FALSE
    )
    nodes$id <- 0:(nrow(nodes) - 1)

    # create a data frame of the edges that uses id 0:9 instead of their names
    edges <- networkData |>
        left_join(nodes, by = c("src" = "name")) |>
        select(-src, -author) |>
        rename(source = id) |>
        left_join(nodes, by = c("target" = "name")) |>
        select(-target, -author) |>
        rename(target = id) |>
        mutate(width = 1)

    # make a grouping variable that will match to colours
    nodes$group <- ifelse(
        nodes$name %in% gsub("^https://openalex.org/", "", key_works$id),
        "key_paper",
        "other"
    )
    nodes$oa_id <- nodes$name
    nodes$name <- nodes$author

    # control colours with a JS ordinal scale
    ColourScale <- 'd3.scaleOrdinal()
                        .domain(["key_paper", "other"])
                     .range(["#FF6900", "#694489"]);'

    openDOI <- "window.open(d.doi)"

    MyClickScript <- 'alert("You clicked " + d.name + " with the doi " +
             d.doi +  " of your original R data frame");'

    nwg <- forceNetwork(
        Links = edges,
        Nodes = nodes,
        Source = "source",
        Target = "target",
        NodeID = "name",
        Nodesize = "nodesize",
        Group = "group",
        Value = "width",
        opacity = 0.9,
        zoom = TRUE,
        colourScale = DT::JS(ColourScale),
        fontSize = 20,
        legend = TRUE,
        clickAction = openDOI
    )

    nwg$x$nodes$doi <- nodes$doi

    if (!missing(file)) {
        tmpdir <- tempfile()
        dir.create(tmpdir)
        on.exit(unlink(tmpdir, recursive = TRUE))

        tmpfile <- file.path(tmpdir, "nwg.html")

        networkD3::saveNetwork(
            nwg,
            file = tmpfile,
            selfcontained = TRUE
        )

        file.copy(
            tmpfile,
            file
        )
    }

    nwg
}
