# pro_request search count `biodiversity AND fiance`

    Code
      count
    Output
        count db_response_time_ms page per_page error
      1   408                  42    1        1  <NA>

# pro_request search count and openalexR::oa_fetch() return same results

    Code
      count_oa
    Output
      $count
      [1] 369
      
      $db_response_time_ms
      [1] 138
      
      $page
      [1] 1
      
      $per_page
      [1] 1
      
      $groups_count
      NULL
      
    Code
      count
    Output
        count db_response_time_ms page per_page error
      1   408                  42    1        1  <NA>
    Code
      identical(count_oa$count, count[["count"]])
    Output
      [1] FALSE

