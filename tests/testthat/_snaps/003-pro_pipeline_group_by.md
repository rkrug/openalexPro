# pro_request_jsonl_parquet `biodiversity` and group by type

    Code
      nrow(results_openalexPro)
    Output
      [1] 20
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
                                                        key        key_display_name
      1                  https://openalex.org/types/article                 article
      2                     https://openalex.org/types/book                    book
      3             https://openalex.org/types/book-chapter            book-chapter
      4                  https://openalex.org/types/dataset                 dataset
      5             https://openalex.org/types/dissertation            dissertation
      6                https://openalex.org/types/editorial               editorial
      7                  https://openalex.org/types/erratum                 erratum
      8                    https://openalex.org/types/grant                   grant
      9                   https://openalex.org/types/letter                  letter
      10               https://openalex.org/types/libguides               libguides
      11                   https://openalex.org/types/other                   other
      12                https://openalex.org/types/paratext                paratext
      13             https://openalex.org/types/peer-review             peer-review
      14                https://openalex.org/types/preprint                preprint
      15         https://openalex.org/types/reference-entry         reference-entry
      16                  https://openalex.org/types/report                  report
      17              https://openalex.org/types/retraction              retraction
      18                  https://openalex.org/types/review                  review
      19                https://openalex.org/types/standard                standard
      20 https://openalex.org/types/supplementary-materials supplementary-materials
         count
      1  41442
      2   2223
      3   3269
      4    231
      5   1426
      6    144
      7     42
      8     24
      9    218
      10    22
      11   345
      12   102
      13     0
      14  1438
      15    24
      16   243
      17     0
      18  1017
      19     1
      20     0
    Code
      print(results_openalexPro)
    Output
      # A tibble: 20 x 3
         key                                                key_display_name     count
         <chr>                                              <chr>                <int>
       1 https://openalex.org/types/article                 article              41442
       2 https://openalex.org/types/book                    book                  2223
       3 https://openalex.org/types/book-chapter            book-chapter          3269
       4 https://openalex.org/types/dataset                 dataset                231
       5 https://openalex.org/types/dissertation            dissertation          1426
       6 https://openalex.org/types/editorial               editorial              144
       7 https://openalex.org/types/erratum                 erratum                 42
       8 https://openalex.org/types/grant                   grant                   24
       9 https://openalex.org/types/letter                  letter                 218
      10 https://openalex.org/types/libguides               libguides               22
      11 https://openalex.org/types/other                   other                  345
      12 https://openalex.org/types/paratext                paratext               102
      13 https://openalex.org/types/peer-review             peer-review              0
      14 https://openalex.org/types/preprint                preprint              1438
      15 https://openalex.org/types/reference-entry         reference-entry         24
      16 https://openalex.org/types/report                  report                 243
      17 https://openalex.org/types/retraction              retraction               0
      18 https://openalex.org/types/review                  review                1017
      19 https://openalex.org/types/standard                standard                 1
      20 https://openalex.org/types/supplementary-materials supplementary-mater~     0

