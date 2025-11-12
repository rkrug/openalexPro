# pro_request search count `biodiversity AND fiance`

    Code
      count
    Output
                    count db_response_time_ms                page            per_page 
                      408                  42                   1                   1 

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
                    count db_response_time_ms                page            per_page 
                      408                  42                   1                   1 
    Code
      identical(count_oa$count, count[["count"]])
    Output
      [1] FALSE

