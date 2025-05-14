# pro_snowball

    Code
      x <- read_snowball(file.path(output_dir), return_data = FALSE)
      names(x)
    Output
      [1] "nodes" "edges"
    Code
      nrow(x$nodes)
    Output
      [1] 46
    Code
      sort(names(x$nodes))
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
      nrow(x$edges)
    Output
      [1] 39
    Code
      sort(names(x$edges))
    Output
      [1] "edge_type" "from"      "to"       
    Code
      print(dplyr::collect(dplyr::arrange(dplyr::select(x$nodes, id, oa_input,
      relation), oa_input, relation)), n = Inf)
    Output
      # A tibble: 46 x 3
         id                               oa_input relation
         <chr>                            <chr>    <chr>   
       1 https://openalex.org/W2250539671 FALSE    cited   
       2 https://openalex.org/W2963341956 FALSE    cited   
       3 https://openalex.org/W2153579005 FALSE    cited   
       4 https://openalex.org/W1854214752 FALSE    cited   
       5 https://openalex.org/W2962739339 FALSE    cited   
       6 https://openalex.org/W2525778437 FALSE    cited   
       7 https://openalex.org/W2166481425 FALSE    cited   
       8 https://openalex.org/W1525595230 FALSE    cited   
       9 https://openalex.org/W3101913037 FALSE    cited   
      10 https://openalex.org/W2741809807 FALSE    cited   
      11 https://openalex.org/W2963118869 FALSE    cited   
      12 https://openalex.org/W2251861449 FALSE    cited   
      13 https://openalex.org/W2442495973 FALSE    cited   
      14 https://openalex.org/W2091406001 FALSE    cited   
      15 https://openalex.org/W1572136682 FALSE    cited   
      16 https://openalex.org/W2251869843 FALSE    cited   
      17 https://openalex.org/W1909800943 FALSE    cited   
      18 https://openalex.org/W1996515099 FALSE    cited   
      19 https://openalex.org/W2963090765 FALSE    cited   
      20 https://openalex.org/W205532704  FALSE    cited   
      21 https://openalex.org/W2096537696 FALSE    cited   
      22 https://openalex.org/W2593028313 FALSE    cited   
      23 https://openalex.org/W2577479404 FALSE    cited   
      24 https://openalex.org/W2807650837 FALSE    cited   
      25 https://openalex.org/W2849933844 FALSE    cited   
      26 https://openalex.org/W2911997761 FALSE    cited   
      27 https://openalex.org/W1500530942 FALSE    cited   
      28 https://openalex.org/W618607536  FALSE    cited   
      29 https://openalex.org/W2251249502 FALSE    cited   
      30 https://openalex.org/W2891066092 FALSE    cited   
      31 https://openalex.org/W2896826974 FALSE    cited   
      32 https://openalex.org/W2938946739 FALSE    cited   
      33 https://openalex.org/W296960487  FALSE    cited   
      34 https://openalex.org/W2766528118 FALSE    cited   
      35 https://openalex.org/W2810053269 FALSE    cited   
      36 https://openalex.org/W2252212014 FALSE    cited   
      37 https://openalex.org/W2936368166 FALSE    cited   
      38 https://openalex.org/W91322025   FALSE    cited   
      39 https://openalex.org/W2462443510 FALSE    cited   
      40 https://openalex.org/W2965202507 FALSE    cited   
      41 https://openalex.org/W1516819724 FALSE    cited   
      42 https://openalex.org/W4311043552 FALSE    citing  
      43 https://openalex.org/W4293919086 FALSE    citing  
      44 https://openalex.org/W4387316167 FALSE    citing  
      45 https://openalex.org/W3046863325 TRUE     keypaper
      46 https://openalex.org/W3045921891 TRUE     keypaper
    Code
      print(dplyr::collect(dplyr::arrange(x$edges, edge_type, from, to)), n = Inf)
    Output
      # A tibble: 39 x 3
         from                             to                               edge_type
         <chr>                            <chr>                            <chr>    
       1 https://openalex.org/W4293919086 https://openalex.org/W3046863325 core     
       2 https://openalex.org/W4311043552 https://openalex.org/W3046863325 core     
       3 https://openalex.org/W4387316167 https://openalex.org/W3046863325 core     
       4 https://openalex.org/W1500530942 https://openalex.org/W2252212014 extended 
       5 https://openalex.org/W1500530942 https://openalex.org/W2462443510 extended 
       6 https://openalex.org/W1516819724 https://openalex.org/W2462443510 extended 
       7 https://openalex.org/W1525595230 https://openalex.org/W2252212014 extended 
       8 https://openalex.org/W1525595230 https://openalex.org/W3101913037 extended 
       9 https://openalex.org/W1572136682 https://openalex.org/W1996515099 extended 
      10 https://openalex.org/W1572136682 https://openalex.org/W2593028313 extended 
      11 https://openalex.org/W1572136682 https://openalex.org/W2810053269 extended 
      12 https://openalex.org/W1854214752 https://openalex.org/W3101913037 extended 
      13 https://openalex.org/W205532704  https://openalex.org/W2096537696 extended 
      14 https://openalex.org/W205532704  https://openalex.org/W2442495973 extended 
      15 https://openalex.org/W205532704  https://openalex.org/W2462443510 extended 
      16 https://openalex.org/W2096537696 https://openalex.org/W1516819724 extended 
      17 https://openalex.org/W2096537696 https://openalex.org/W2252212014 extended 
      18 https://openalex.org/W2096537696 https://openalex.org/W2462443510 extended 
      19 https://openalex.org/W2153579005 https://openalex.org/W2250539671 extended 
      20 https://openalex.org/W2153579005 https://openalex.org/W2251249502 extended 
      21 https://openalex.org/W2153579005 https://openalex.org/W2807650837 extended 
      22 https://openalex.org/W2153579005 https://openalex.org/W2962739339 extended 
      23 https://openalex.org/W2153579005 https://openalex.org/W2963341956 extended 
      24 https://openalex.org/W2250539671 https://openalex.org/W2807650837 extended 
      25 https://openalex.org/W2250539671 https://openalex.org/W2962739339 extended 
      26 https://openalex.org/W2250539671 https://openalex.org/W2963341956 extended 
      27 https://openalex.org/W2251861449 https://openalex.org/W2251249502 extended 
      28 https://openalex.org/W2251861449 https://openalex.org/W2251869843 extended 
      29 https://openalex.org/W2442495973 https://openalex.org/W2096537696 extended 
      30 https://openalex.org/W2442495973 https://openalex.org/W2252212014 extended 
      31 https://openalex.org/W2442495973 https://openalex.org/W2936368166 extended 
      32 https://openalex.org/W2442495973 https://openalex.org/W91322025   extended 
      33 https://openalex.org/W2593028313 https://openalex.org/W2896826974 extended 
      34 https://openalex.org/W2741809807 https://openalex.org/W2965202507 extended 
      35 https://openalex.org/W2962739339 https://openalex.org/W2963341956 extended 
      36 https://openalex.org/W2963341956 https://openalex.org/W2911997761 extended 
      37 https://openalex.org/W3101913037 https://openalex.org/W2252212014 extended 
      38 https://openalex.org/W618607536  https://openalex.org/W2096537696 extended 
      39 https://openalex.org/W618607536  https://openalex.org/W2252212014 extended 

