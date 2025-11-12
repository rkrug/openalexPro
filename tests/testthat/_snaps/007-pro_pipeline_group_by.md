# pro_request_jsonl_parquet `biodiversity` and group by type

    Code
      nrow(results_openalexPro)
    Output
      [1] 16
    Code
      sort(names(results_openalexPro))
    Output
      [1] "citation"         "count"            "key"              "key_display_name"
      [5] "page"            
    Code
      results_openalexPro <- dplyr::collect(dplyr::arrange(dplyr::mutate(
        results_openalexPro, citation = NULL, page = NULL), key))
      print(results_openalexR)
    Output
                                                key key_display_name count
      1          https://openalex.org/types/article          article 52774
      2             https://openalex.org/types/book             book  2446
      3     https://openalex.org/types/book-chapter     book-chapter  5086
      4          https://openalex.org/types/dataset          dataset   197
      5     https://openalex.org/types/dissertation     dissertation  1656
      6        https://openalex.org/types/editorial        editorial   165
      7          https://openalex.org/types/erratum          erratum    39
      8           https://openalex.org/types/letter           letter   297
      9        https://openalex.org/types/libguides        libguides    22
      10           https://openalex.org/types/other            other   491
      11        https://openalex.org/types/paratext         paratext   146
      12        https://openalex.org/types/preprint         preprint  1075
      13 https://openalex.org/types/reference-entry  reference-entry    24
      14          https://openalex.org/types/report           report   276
      15          https://openalex.org/types/review           review  1366
      16        https://openalex.org/types/standard         standard     1
    Code
      print(results_openalexPro)
    Output
      # A tibble: 16 x 3
         key                                        key_display_name count
         <chr>                                      <chr>            <int>
       1 https://openalex.org/types/article         article          52774
       2 https://openalex.org/types/book            book              2446
       3 https://openalex.org/types/book-chapter    book-chapter      5086
       4 https://openalex.org/types/dataset         dataset            197
       5 https://openalex.org/types/dissertation    dissertation      1656
       6 https://openalex.org/types/editorial       editorial          165
       7 https://openalex.org/types/erratum         erratum             39
       8 https://openalex.org/types/letter          letter             297
       9 https://openalex.org/types/libguides       libguides           22
      10 https://openalex.org/types/other           other              491
      11 https://openalex.org/types/paratext        paratext           146
      12 https://openalex.org/types/preprint        preprint          1075
      13 https://openalex.org/types/reference-entry reference-entry     24
      14 https://openalex.org/types/report          report             276
      15 https://openalex.org/types/review          review            1366
      16 https://openalex.org/types/standard        standard             1

