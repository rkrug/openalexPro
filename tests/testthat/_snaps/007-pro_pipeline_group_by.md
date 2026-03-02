# pro_request_jsonl_parquet `biodiversity` and group by type

    Code
      nrow(results_openalexPro)
    Output
      [1] 18
    Code
      sort(names(results_openalexPro))
    Output
      [1] "citation"         "count"            "key"              "key_display_name"
      [5] "page"            
    Code
      results_openalexPro <- dplyr::collect(dplyr::arrange(dplyr::mutate(
        results_openalexPro, citation = NULL, page = NULL), key))
      print(results_openalexPro)
    Output
      # A tibble: 18 x 3
         key                                                key_display_name     count
         <chr>                                              <chr>                <int>
       1 https://openalex.org/types/article                 article             129243
       2 https://openalex.org/types/book                    book                  3037
       3 https://openalex.org/types/book-chapter            book-chapter          6113
       4 https://openalex.org/types/database                database                 1
       5 https://openalex.org/types/dataset                 dataset                280
       6 https://openalex.org/types/dissertation            dissertation          2017
       7 https://openalex.org/types/editorial               editorial              170
       8 https://openalex.org/types/erratum                 erratum                 45
       9 https://openalex.org/types/letter                  letter                 318
      10 https://openalex.org/types/libguides               libguides               22
      11 https://openalex.org/types/other                   other                  563
      12 https://openalex.org/types/paratext                paratext               184
      13 https://openalex.org/types/preprint                preprint              1392
      14 https://openalex.org/types/reference-entry         reference-entry         24
      15 https://openalex.org/types/report                  report                 310
      16 https://openalex.org/types/review                  review                1895
      17 https://openalex.org/types/standard                standard                 1
      18 https://openalex.org/types/supplementary-materials supplementary-mate~      1

