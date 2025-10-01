# pro_snowball

    Code
      names(results_openalexPro)
    Output
      [1] "nodes" "edges"
    Code
      nrow(results_openalexPro$nodes)
    Output
      [1] 2
    Code
      sort(names(results_openalexPro$nodes))
    Output
       [1] "abstract"                       "abstract_inverted_index_v3"    
       [3] "apc_list"                       "apc_paid"                      
       [5] "authorships"                    "best_oa_location"              
       [7] "biblio"                         "citation"                      
       [9] "citation_normalized_percentile" "cited_by_api_url"              
      [11] "cited_by_count"                 "cited_by_percentile_year"      
      [13] "concepts"                       "corresponding_author_ids"      
      [15] "corresponding_institution_ids"  "countries_distinct_count"      
      [17] "counts_by_year"                 "created_date"                  
      [19] "datasets"                       "display_name"                  
      [21] "doi"                            "fwci"                          
      [23] "grants"                         "has_fulltext"                  
      [25] "id"                             "ids"                           
      [27] "indexed_in"                     "institution_assertions"        
      [29] "institutions_distinct_count"    "is_paratext"                   
      [31] "is_retracted"                   "keywords"                      
      [33] "language"                       "locations"                     
      [35] "locations_count"                "mesh"                          
      [37] "oa_input"                       "open_access"                   
      [39] "page"                           "primary_location"              
      [41] "primary_topic"                  "publication_date"              
      [43] "publication_year"               "referenced_works"              
      [45] "referenced_works_count"         "related_works"                 
      [47] "relation"                       "sustainable_development_goals" 
      [49] "title"                          "topics"                        
      [51] "type"                           "type_crossref"                 
      [53] "updated_date"                   "versions"                      
    Code
      nrow(results_openalexPro$edges)
    Output
      [1] 0
    Code
      sort(names(results_openalexPro$edges))
    Output
      [1] "edge_type" "from"      "to"       
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = "core")
    Output
      $nodes
      # A tibble: 2 x 54
        id     doi   title display_name publication_year publication_date ids$openalex
        <chr>  <chr> <chr> <chr>                   <int> <date>           <chr>       
      1 W3045~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
      2 W3046~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
      # i 49 more variables: ids$doi <chr>, $mag <chr>, language <chr>,
      #   primary_location <tibble[,9]>, type <chr>, type_crossref <chr>,
      #   indexed_in <list<character>>, open_access <tibble[,4]>,
      #   authorships <list<
        tbl_df<
          author_position        : character
          author                 : 
            tbl_df<
              id          : character
              display_name: character
              orcid       : character
            >
          institutions           : 
            list<
              tbl_df<
                id          : character
                display_name: character
                ror         : character
                country_code: character
                type        : character
                lineage     : list<character>
              >
            >
          countries              : list<character>
          is_corresponding       : logical
          raw_author_name        : character
          raw_affiliation_strings: list<character>
          affiliations           : 
            list<
              tbl_df<
                raw_affiliation_string: character
                institution_ids       : list<character>
              >
            >
        >
      >>,
      #   institution_assertions <list<character>>, countries_distinct_count <int>,
      #   institutions_distinct_count <int>,
      #   corresponding_author_ids <list<character>>, ...
      
      $edges
      # A tibble: 0 x 3
      # i 3 variables: from <chr>, to <chr>, edge_type <chr>
      
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = "extended")
    Output
      $nodes
      # A tibble: 2 x 54
        id     doi   title display_name publication_year publication_date ids$openalex
        <chr>  <chr> <chr> <chr>                   <int> <date>           <chr>       
      1 W3045~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
      2 W3046~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
      # i 49 more variables: ids$doi <chr>, $mag <chr>, language <chr>,
      #   primary_location <tibble[,9]>, type <chr>, type_crossref <chr>,
      #   indexed_in <list<character>>, open_access <tibble[,4]>,
      #   authorships <list<
        tbl_df<
          author_position        : character
          author                 : 
            tbl_df<
              id          : character
              display_name: character
              orcid       : character
            >
          institutions           : 
            list<
              tbl_df<
                id          : character
                display_name: character
                ror         : character
                country_code: character
                type        : character
                lineage     : list<character>
              >
            >
          countries              : list<character>
          is_corresponding       : logical
          raw_author_name        : character
          raw_affiliation_strings: list<character>
          affiliations           : 
            list<
              tbl_df<
                raw_affiliation_string: character
                institution_ids       : list<character>
              >
            >
        >
      >>,
      #   institution_assertions <list<character>>, countries_distinct_count <int>,
      #   institutions_distinct_count <int>,
      #   corresponding_author_ids <list<character>>, ...
      
      $edges
      # A tibble: 0 x 3
      # i 3 variables: from <chr>, to <chr>, edge_type <chr>
      
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = c("extended", "core"))
    Output
      $nodes
      # A tibble: 2 x 54
        id     doi   title display_name publication_year publication_date ids$openalex
        <chr>  <chr> <chr> <chr>                   <int> <date>           <chr>       
      1 W3045~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
      2 W3046~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
      # i 49 more variables: ids$doi <chr>, $mag <chr>, language <chr>,
      #   primary_location <tibble[,9]>, type <chr>, type_crossref <chr>,
      #   indexed_in <list<character>>, open_access <tibble[,4]>,
      #   authorships <list<
        tbl_df<
          author_position        : character
          author                 : 
            tbl_df<
              id          : character
              display_name: character
              orcid       : character
            >
          institutions           : 
            list<
              tbl_df<
                id          : character
                display_name: character
                ror         : character
                country_code: character
                type        : character
                lineage     : list<character>
              >
            >
          countries              : list<character>
          is_corresponding       : logical
          raw_author_name        : character
          raw_affiliation_strings: list<character>
          affiliations           : 
            list<
              tbl_df<
                raw_affiliation_string: character
                institution_ids       : list<character>
              >
            >
        >
      >>,
      #   institution_assertions <list<character>>, countries_distinct_count <int>,
      #   institutions_distinct_count <int>,
      #   corresponding_author_ids <list<character>>, ...
      
      $edges
      # A tibble: 0 x 3
      # i 3 variables: from <chr>, to <chr>, edge_type <chr>
      
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = "outside")
    Output
      $nodes
      # A tibble: 2 x 54
        id     doi   title display_name publication_year publication_date ids$openalex
        <chr>  <chr> <chr> <chr>                   <int> <date>           <chr>       
      1 W3045~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
      2 W3046~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
      # i 49 more variables: ids$doi <chr>, $mag <chr>, language <chr>,
      #   primary_location <tibble[,9]>, type <chr>, type_crossref <chr>,
      #   indexed_in <list<character>>, open_access <tibble[,4]>,
      #   authorships <list<
        tbl_df<
          author_position        : character
          author                 : 
            tbl_df<
              id          : character
              display_name: character
              orcid       : character
            >
          institutions           : 
            list<
              tbl_df<
                id          : character
                display_name: character
                ror         : character
                country_code: character
                type        : character
                lineage     : list<character>
              >
            >
          countries              : list<character>
          is_corresponding       : logical
          raw_author_name        : character
          raw_affiliation_strings: list<character>
          affiliations           : 
            list<
              tbl_df<
                raw_affiliation_string: character
                institution_ids       : list<character>
              >
            >
        >
      >>,
      #   institution_assertions <list<character>>, countries_distinct_count <int>,
      #   institutions_distinct_count <int>,
      #   corresponding_author_ids <list<character>>, ...
      
      $edges
      # A tibble: 43 x 3
         from        to          edge_type
         <chr>       <chr>       <chr>    
       1 W3045921891 W1500530942 outside  
       2 W3045921891 W1516819724 outside  
       3 W3045921891 W1525595230 outside  
       4 W3045921891 W1572136682 outside  
       5 W3045921891 W1854214752 outside  
       6 W3045921891 W1909800943 outside  
       7 W3045921891 W205532704  outside  
       8 W3045921891 W2091406001 outside  
       9 W3045921891 W2096537696 outside  
      10 W3045921891 W2153579005 outside  
      # i 33 more rows
      
    Code
      print(dplyr::collect(dplyr::arrange(dplyr::select(results_openalexPro$nodes, id,
      oa_input, relation), oa_input, relation)), n = Inf)
    Output
      # A tibble: 2 x 3
        id          oa_input relation
        <chr>       <lgl>    <chr>   
      1 W3045921891 TRUE     keypaper
      2 W3046863325 TRUE     keypaper
    Code
      print(dplyr::collect(dplyr::arrange(results_openalexPro$edges, edge_type, from,
      to)), n = Inf)
    Output
      # A tibble: 0 x 3
      # i 3 variables: from <chr>, to <chr>, edge_type <chr>
    Code
      print(nodes_diff, n = Inf)
    Output
      # A tibble: 0 x 2
      # i 2 variables: id <chr>, oa_input <lgl>
    Code
      print(edges_diff, n = Inf)
    Output
      # A tibble: 0 x 3
      # i 3 variables: from <chr>, to <chr>, edge_type <chr>

