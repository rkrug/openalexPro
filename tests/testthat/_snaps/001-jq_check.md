# jq_check throws an error when jq is not installed

    Code
      jq_check()
    Condition
      Error:
      ! jq is not installed or not on the PATH. Install jq using Homebrew (`brew install jq`) or download a binary from https://stedolan.github.io/jq/download/.

# jq_check returns TRUE when jq is installed

    Code
      jq_check()
    Output
      [1] TRUE

