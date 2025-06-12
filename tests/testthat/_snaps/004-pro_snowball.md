# pro_snowball

    Code
      names(results_openalexPro)
    Output
      [1] "nodes" "edges"
    Code
      nrow(results_openalexPro$nodes)
    Output
      [1] 46
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
      [21] "doi"                            "fulltext_origin"               
      [23] "fwci"                           "grants"                        
      [25] "has_fulltext"                   "id"                            
      [27] "ids"                            "indexed_in"                    
      [29] "institution_assertions"         "institutions_distinct_count"   
      [31] "is_paratext"                    "is_retracted"                  
      [33] "keywords"                       "language"                      
      [35] "locations"                      "locations_count"               
      [37] "mesh"                           "oa_input"                      
      [39] "open_access"                    "page"                          
      [41] "primary_location"               "primary_topic"                 
      [43] "publication_date"               "publication_year"              
      [45] "referenced_works"               "referenced_works_count"        
      [47] "related_works"                  "relation"                      
      [49] "sustainable_development_goals"  "title"                         
      [51] "topics"                         "type"                          
      [53] "type_crossref"                  "updated_date"                  
      [55] "versions"                      
    Code
      nrow(results_openalexPro$edges)
    Output
      [1] 45
    Code
      sort(names(results_openalexPro$edges))
    Output
      [1] "edge_type" "from"      "to"       
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = "core")
    Output
      $nodes
      # A tibble: 46 x 55
         id    doi   title display_name publication_year publication_date ids$openalex
         <chr> <chr> <chr> <chr>                   <int> <date>           <chr>       
       1 W304~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
       2 W304~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
       3 W150~ <NA>  Corp~ Corpora for~             2010 2010-05-17       https://ope~
       4 W151~ http~ Part~ Partridge: ~             2013 2013-01-01       https://ope~
       5 W152~ <NA>  Text~ TextRank: B~             2004 2004-07-01       https://ope~
       6 W157~ http~ Altm~ Altmetrics:~             2013 2013-01-01       https://ope~
       7 W185~ <NA>  The ~ The PageRan~             1999 1999-11-11       https://ope~
       8 W190~ http~ What~ What Teache~             2015 2015-09-11       https://ope~
       9 W199~ http~ The ~ The open ac~             2015 2015-03-11       https://ope~
      10 W205~ <NA>  Argu~ Argumentati~             1999 1999-01-01       https://ope~
      # i 36 more rows
      # i 52 more variables: ids$doi <chr>, $mag <chr>, $pmid <chr>, $pmcid <chr>,
      #   language <chr>, primary_location <tibble[,9]>, type <chr>,
      #   type_crossref <chr>, indexed_in <list<character>>,
      #   open_access <tibble[,4]>,
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
      #   institution_assertions <list<character>>, ...
      
      $edges
      # A tibble: 45 x 3
         from        to          edge_type
         <chr>       <chr>       <chr>    
       1 W3045921891 W1500530942 core     
       2 W3045921891 W1516819724 core     
       3 W3045921891 W1525595230 core     
       4 W3045921891 W1572136682 core     
       5 W3045921891 W1854214752 core     
       6 W3045921891 W1909800943 core     
       7 W3045921891 W205532704  core     
       8 W3045921891 W2091406001 core     
       9 W3045921891 W2096537696 core     
      10 W3045921891 W2153579005 core     
      # i 35 more rows
      
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = "extended")
    Output
      $nodes
      # A tibble: 46 x 55
         id    doi   title display_name publication_year publication_date ids$openalex
         <chr> <chr> <chr> <chr>                   <int> <date>           <chr>       
       1 W304~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
       2 W304~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
       3 W150~ <NA>  Corp~ Corpora for~             2010 2010-05-17       https://ope~
       4 W151~ http~ Part~ Partridge: ~             2013 2013-01-01       https://ope~
       5 W152~ <NA>  Text~ TextRank: B~             2004 2004-07-01       https://ope~
       6 W157~ http~ Altm~ Altmetrics:~             2013 2013-01-01       https://ope~
       7 W185~ <NA>  The ~ The PageRan~             1999 1999-11-11       https://ope~
       8 W190~ http~ What~ What Teache~             2015 2015-09-11       https://ope~
       9 W199~ http~ The ~ The open ac~             2015 2015-03-11       https://ope~
      10 W205~ <NA>  Argu~ Argumentati~             1999 1999-01-01       https://ope~
      # i 36 more rows
      # i 52 more variables: ids$doi <chr>, $mag <chr>, $pmid <chr>, $pmcid <chr>,
      #   language <chr>, primary_location <tibble[,9]>, type <chr>,
      #   type_crossref <chr>, indexed_in <list<character>>,
      #   open_access <tibble[,4]>,
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
      #   institution_assertions <list<character>>, ...
      
      $edges
      # A tibble: 36 x 3
         from        to          edge_type
         <chr>       <chr>       <chr>    
       1 W1516819724 W2096537696 extended 
       2 W1996515099 W1572136682 extended 
       3 W2096537696 W205532704  extended 
       4 W2096537696 W2442495973 extended 
       5 W2096537696 W618607536  extended 
       6 W2250539671 W2153579005 extended 
       7 W2251249502 W2153579005 extended 
       8 W2251249502 W2251861449 extended 
       9 W2251869843 W2251861449 extended 
      10 W2252212014 W1500530942 extended 
      # i 26 more rows
      
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = c("extended", "core"))
    Output
      $nodes
      # A tibble: 46 x 55
         id    doi   title display_name publication_year publication_date ids$openalex
         <chr> <chr> <chr> <chr>                   <int> <date>           <chr>       
       1 W304~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
       2 W304~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
       3 W150~ <NA>  Corp~ Corpora for~             2010 2010-05-17       https://ope~
       4 W151~ http~ Part~ Partridge: ~             2013 2013-01-01       https://ope~
       5 W152~ <NA>  Text~ TextRank: B~             2004 2004-07-01       https://ope~
       6 W157~ http~ Altm~ Altmetrics:~             2013 2013-01-01       https://ope~
       7 W185~ <NA>  The ~ The PageRan~             1999 1999-11-11       https://ope~
       8 W190~ http~ What~ What Teache~             2015 2015-09-11       https://ope~
       9 W199~ http~ The ~ The open ac~             2015 2015-03-11       https://ope~
      10 W205~ <NA>  Argu~ Argumentati~             1999 1999-01-01       https://ope~
      # i 36 more rows
      # i 52 more variables: ids$doi <chr>, $mag <chr>, $pmid <chr>, $pmcid <chr>,
      #   language <chr>, primary_location <tibble[,9]>, type <chr>,
      #   type_crossref <chr>, indexed_in <list<character>>,
      #   open_access <tibble[,4]>,
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
      #   institution_assertions <list<character>>, ...
      
      $edges
      # A tibble: 81 x 3
         from        to          edge_type
         <chr>       <chr>       <chr>    
       1 W1516819724 W2096537696 extended 
       2 W1996515099 W1572136682 extended 
       3 W2096537696 W205532704  extended 
       4 W2096537696 W2442495973 extended 
       5 W2096537696 W618607536  extended 
       6 W2250539671 W2153579005 extended 
       7 W2251249502 W2153579005 extended 
       8 W2251249502 W2251861449 extended 
       9 W2251869843 W2251861449 extended 
      10 W2252212014 W1500530942 extended 
      # i 71 more rows
      
    Code
      read_snowball(file.path(output_dir), return_data = TRUE, shorten_ids = TRUE,
      edge_type = "outside")
    Output
      $nodes
      # A tibble: 46 x 55
         id    doi   title display_name publication_year publication_date ids$openalex
         <chr> <chr> <chr> <chr>                   <int> <date>           <chr>       
       1 W304~ http~ Meas~ Measuring p~             2020 2020-01-01       https://ope~
       2 W304~ http~ Tren~ Trends of P~             2020 2020-08-01       https://ope~
       3 W150~ <NA>  Corp~ Corpora for~             2010 2010-05-17       https://ope~
       4 W151~ http~ Part~ Partridge: ~             2013 2013-01-01       https://ope~
       5 W152~ <NA>  Text~ TextRank: B~             2004 2004-07-01       https://ope~
       6 W157~ http~ Altm~ Altmetrics:~             2013 2013-01-01       https://ope~
       7 W185~ <NA>  The ~ The PageRan~             1999 1999-11-11       https://ope~
       8 W190~ http~ What~ What Teache~             2015 2015-09-11       https://ope~
       9 W199~ http~ The ~ The open ac~             2015 2015-03-11       https://ope~
      10 W205~ <NA>  Argu~ Argumentati~             1999 1999-01-01       https://ope~
      # i 36 more rows
      # i 52 more variables: ids$doi <chr>, $mag <chr>, $pmid <chr>, $pmcid <chr>,
      #   language <chr>, primary_location <tibble[,9]>, type <chr>,
      #   type_crossref <chr>, indexed_in <list<character>>,
      #   open_access <tibble[,4]>,
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
      #   institution_assertions <list<character>>, ...
      
      $edges
      # A tibble: 1,214 x 3
         from        to          edge_type
         <chr>       <chr>       <chr>    
       1 W1500530942 W1516240602 outside  
       2 W1500530942 W1975879668 outside  
       3 W1500530942 W1979773093 outside  
       4 W1500530942 W1982464493 outside  
       5 W1500530942 W2002664886 outside  
       6 W1500530942 W2006802446 outside  
       7 W1500530942 W2027943492 outside  
       8 W1500530942 W2050355460 outside  
       9 W1500530942 W2053154970 outside  
      10 W1500530942 W2070285512 outside  
      # i 1,204 more rows
      
    Code
      print(dplyr::collect(dplyr::arrange(dplyr::select(results_openalexPro$nodes, id,
      oa_input, relation), oa_input, relation)), n = Inf)
    Output
      # A tibble: 46 x 3
         id          oa_input relation
         <chr>       <lgl>    <chr>   
       1 W1500530942 FALSE    cited   
       2 W1516819724 FALSE    cited   
       3 W1525595230 FALSE    cited   
       4 W1572136682 FALSE    cited   
       5 W1854214752 FALSE    cited   
       6 W1909800943 FALSE    cited   
       7 W1996515099 FALSE    cited   
       8 W205532704  FALSE    cited   
       9 W2091406001 FALSE    cited   
      10 W2096537696 FALSE    cited   
      11 W2153579005 FALSE    cited   
      12 W2166481425 FALSE    cited   
      13 W2250539671 FALSE    cited   
      14 W2251249502 FALSE    cited   
      15 W2251861449 FALSE    cited   
      16 W2251869843 FALSE    cited   
      17 W2252212014 FALSE    cited   
      18 W2442495973 FALSE    cited   
      19 W2462443510 FALSE    cited   
      20 W2525778437 FALSE    cited   
      21 W2577479404 FALSE    cited   
      22 W2593028313 FALSE    cited   
      23 W2741809807 FALSE    cited   
      24 W2766528118 FALSE    cited   
      25 W2807650837 FALSE    cited   
      26 W2810053269 FALSE    cited   
      27 W2849933844 FALSE    cited   
      28 W2891066092 FALSE    cited   
      29 W2896826974 FALSE    cited   
      30 W2911997761 FALSE    cited   
      31 W2936368166 FALSE    cited   
      32 W2938946739 FALSE    cited   
      33 W2962739339 FALSE    cited   
      34 W2963090765 FALSE    cited   
      35 W2963118869 FALSE    cited   
      36 W2963341956 FALSE    cited   
      37 W2965202507 FALSE    cited   
      38 W296960487  FALSE    cited   
      39 W3101913037 FALSE    cited   
      40 W618607536  FALSE    cited   
      41 W91322025   FALSE    cited   
      42 W4293919086 FALSE    citing  
      43 W4311043552 FALSE    citing  
      44 W4387316167 FALSE    citing  
      45 W3045921891 TRUE     keypaper
      46 W3046863325 TRUE     keypaper
    Code
      print(dplyr::collect(dplyr::arrange(results_openalexPro$edges, edge_type, from,
      to)), n = Inf)
    Output
      # A tibble: 45 x 3
         from        to          edge_type
         <chr>       <chr>       <chr>    
       1 W3045921891 W1500530942 core     
       2 W3045921891 W1516819724 core     
       3 W3045921891 W1525595230 core     
       4 W3045921891 W1572136682 core     
       5 W3045921891 W1854214752 core     
       6 W3045921891 W1909800943 core     
       7 W3045921891 W205532704  core     
       8 W3045921891 W2091406001 core     
       9 W3045921891 W2096537696 core     
      10 W3045921891 W2153579005 core     
      11 W3045921891 W2166481425 core     
      12 W3045921891 W2250539671 core     
      13 W3045921891 W2251249502 core     
      14 W3045921891 W2251861449 core     
      15 W3045921891 W2251869843 core     
      16 W3045921891 W2252212014 core     
      17 W3045921891 W2442495973 core     
      18 W3045921891 W2462443510 core     
      19 W3045921891 W2525778437 core     
      20 W3045921891 W2577479404 core     
      21 W3045921891 W2593028313 core     
      22 W3045921891 W2741809807 core     
      23 W3045921891 W2807650837 core     
      24 W3045921891 W2810053269 core     
      25 W3045921891 W2849933844 core     
      26 W3045921891 W2891066092 core     
      27 W3045921891 W2896826974 core     
      28 W3045921891 W2911997761 core     
      29 W3045921891 W2936368166 core     
      30 W3045921891 W2962739339 core     
      31 W3045921891 W2963090765 core     
      32 W3045921891 W2963118869 core     
      33 W3045921891 W2963341956 core     
      34 W3045921891 W296960487  core     
      35 W3045921891 W3101913037 core     
      36 W3045921891 W618607536  core     
      37 W3045921891 W91322025   core     
      38 W3046863325 W1996515099 core     
      39 W3046863325 W2741809807 core     
      40 W3046863325 W2766528118 core     
      41 W3046863325 W2938946739 core     
      42 W3046863325 W2965202507 core     
      43 W4293919086 W3046863325 core     
      44 W4311043552 W3046863325 core     
      45 W4387316167 W3046863325 core     
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

