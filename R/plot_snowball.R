#' Plot Snowball
#'
#' This function takes a snowball object and a name, and creates two plots: one sized by cited_by_count and the other by cited_by_count_by_year.
#' The plots are saved as both PDF and PNG in the specified path.
#'
#' @param snowball A snowball object containing the data to be plotted.
#' @param name The name to be used in the plot titles and file names.
#'
#' @return No return value, called for side effects.
#' @export
#'
#' @importFrom tidygraph as_tbl_graph
#' @importFrom ggraph ggraph geom_edge_link geom_node_point geom_node_label theme_graph scale_edge_width
#' @importFrom ggplot2 aes after_stat scale_size scale_fill_manual theme element_rect guides ggtitle ggsave guide_legend
#' @importFrom rlang sym
#' @autoglobal
#'
#' @examples
#' \dontrun{
#' plot_snowball(snowball, "example")
#' }
plot_snowball <- function(
    snowball,
    size = "cited_by_count_by_year",
    label = "citation",
    title = "Snowball"
) {
    if (size == "cited_by_count_by_year") {
        snowball$nodes$cited_by_count_by_year <- snowball$nodes$cited_by_count /
            (2024 - snowball$nodes$publication_year)
    }

    if (!hasName(snowball$nodes, label)) {
        snowball$nodes[label] <- "NA"
    }

    if (is.numeric(size)) {
        snowball$nodes$size_size <- size
        size <- "size_size"
    }

    snowball$nodes <- snowball$nodes |>
        dplyr::select(
            name = id,
            type,
            oa_input,
            all_of(size),
            all_of(label)
        )

    snowball$edges <- snowball$edges |>
        dplyr::select(
            from,
            to
        )

    ###
    graph <- snowball |>
        as_tbl_graph() |>
        ggraph::ggraph(graph = , layout = "stress") +
        ggraph::geom_edge_link(
            aes(
                alpha = ggplot2::after_stat(index),
                # edge_width = ggplot2::after_stat(index)
            ),
            show.legend = FALSE
        ) +
        ggraph::geom_node_point(
            ggplot2::aes(
                size = !!rlang::sym(size),
                shape = type,
                col = oa_input
            )
        ) +
        ggraph::geom_node_label(
            ggplot2::aes(
                filter = oa_input,
                label = !!sym(label),
            ),
            nudge_y = 0.2,
            size = 3
        ) +
        ggraph::scale_edge_width(
            range = c(0.1, 1.5),
            guide = "none"
        ) +

        ggplot2::scale_shape(
            solid = TRUE,
            name = "Publication Type"
        ) +
        ggplot2::scale_size(
            range = c(3, 10),
            name = size
        ) +
        ggplot2::scale_colour_manual(
            values = c("#009E73", "orange"),
            na.value = "grey",
            name = "Key Paper",
            guide = guide_legend()
        ) +

        ggraph::theme_graph() +
        ggplot2::theme(
            plot.background = element_rect(fill = "transparent", colour = NA),
            panel.background = element_rect(fill = "transparent", colour = NA),
            legend.position = "right"
        ) +
        ggplot2::guides(fill = "none") +
        ggplot2::ggtitle(title)

    return(graph)
}
