#' acroname engines
#' @name engines
#'
#' @description
#'
#' The `acroname` engines include methods to generate acronyms and initialisms. `acronym()` searches for candidates by constructing words from characters provided. Each word constructed is compared to the terms in the dictionary specified, and once a match is found the acronym is returned. `initialism()` takes the first characters from each word in the string. Both functions can optionally return a `tibble`, ignore articles, and/or use a "bag of words" approach (for more see \link[acroname]{mince}).
#'
#' @param input Character vector with text to use as the input for the candidate
#' @param dictionary Character vector containing dictionary of terms from which acronym should be created; default is `NULL` and `hunspell` "en_us" dictionary will be used
#' @param acronym_length Number of characters in acronym; default is `3`
#' @param ignore_articles Logical indicating whether or not articles should be ignored ; default is `TRUE`
#' @param alnum_only Logical that specifes whether only alphanumeric should be used; default is `TRUE`
#' @param timeout Maximum seconds to spend searching for an acronym; default is `60`
#' @param bow Logical for whether or not a "bag of words" approach should be used for "input" vector; default is `FALSE`
#' @param bow_prop Given `bow = TRUE` this specifies the proportion of words to sample; ignored if `bow = FALSE`; default is `0.5`
#' @param to_tibble Logical as to whether or not the result should be a `tibble`; default is `FALSE`
#'
#' @return
#'
#' If `to_tibble = FALSE` (default), then a character vector containing the name capitalized followed by the original string with letters used in the name capitalized.
#'
#' If `to_tibble = TRUE`, then a `tibble` with the following columns:
#'
#' - **formatted**: The candidate name and string with letters used capitalized
#' - **prefix**: The candidate name
#' - **suffix**: Words used with letters in name capitalized
#' - **original**: The original string used to construct the name
#'
#' @md
#'

#' @export
#' @rdname engines
acronym <- function(input, dictionary = NULL, acronym_length = 3, ignore_articles = TRUE, alnum_only = TRUE, timeout = 60, bow = FALSE, bow_prop = 0.5, to_tibble = FALSE) {

  ## default behavior is to use hunspell en_us
  if(is.null(dictionary)) {

    dictpath <- system.file("dict", "en_US.dic", package = "hunspell")
    stopifnot(file.exists(dictpath))

    dictionary <-
      dictpath %>%
      readr::read_lines() %>%
      grep("^[A-Z]", ., value = TRUE) %>%
      gsub("/[A-Z]*.", "", .) %>%
      tolower()
  }

  tmp <- mince(input = input,
               ignore_articles = ignore_articles,
               alnum_only = alnum_only,
               bow = bow,
               bow_prop = bow_prop)

  ## get the index of the first character
  first_char_ind <- abs(tmp$words_len  - cumsum(tmp$words_len))  + 1

  ## inintially set all indicies low
  probs <- rep(0.1, nchar(tmp$collapsed))
  ## for first characters bump up probability that index will be selected much higher
  probs[first_char_ind] <- 0.9
  ## bump up weight of first letter ?!
  probs[1] <- 0.95

  ## use timeout with tryCatch
  ## if the processing takes longer than timeout then a message will be printed
  tryCatch({
     R.utils::withTimeout({
      res <- find_candidate(collapsed = tmp$collapsed,
                            acronym_length = acronym_length,
                            probs = probs,
                            dictionary = dictionary,
                            words_len = tmp$words_len)

      if(to_tibble) {
        ## tibble from result elements
        res_tibble <-
          dplyr::tibble(
            formatted = res$formatted,
            prefix = res$prefix,
            suffix = res$suffix,
            original = paste0(tmp$words, collapse = " ")
          )
        return(res_tibble)
      } else {
        return(res$formatted)
      }

    }, timeout = timeout)
  }, TimeoutException = function(ex) {
    message(sprintf("Unable to find viable acronym in 'timeout' specified (%d seconds) ... ", timeout))
  })

}


#' @export
#' @rdname engines
initialism <- function(input, ignore_articles = TRUE, alnum_only = TRUE, bow = FALSE, bow_prop = 0.5, to_tibble = FALSE) {

  ## process input
  tmp <- mince(input = input,
               ignore_articles = ignore_articles,
               alnum_only = alnum_only,
               bow = bow,
               bow_prop = bow_prop)

  ## get candidate prefix
  candidate <- paste0(toupper(tmp$first_chars), collapse = "")

  tmp_collapsed_split <-
    tmp$collapsed %>%
    strsplit(., split = "") %>%
    unlist(.)

  ## indices for first char
  ## get the index of the first character
  first_char_ind <- abs(tmp$words_len  - cumsum(tmp$words_len))  + 1

  ## now format the output to include the capitalized letter
  ## first force everything to be lower case
  tmp_collapsed_split <- tolower(tmp_collapsed_split)
  ## then make sure letters at first char indices are capitalized
  tmp_collapsed_split[first_char_ind] <- toupper(tmp_collapsed_split[first_char_ind])
  ## now need to split the words up again
  last_letter_ind <- cumsum(tmp$words_len)
  tmp_collapsed_split[last_letter_ind[-length(last_letter_ind)]] <- paste0(tmp_collapsed_split[last_letter_ind[-length(last_letter_ind)]], " ")
  name  <- paste0(tmp_collapsed_split, collapse = "")

  ## format with original
  formatted <- paste0(toupper(candidate), ": ", name)

  if(to_tibble) {
    ## tibble from result elements
    res_tibble <-
      dplyr::tibble(
        formatted = formatted,
        prefix = candidate,
        suffix = name,
        original = paste0(tmp$words, collapse = " ")
      )
    return(res_tibble)
  } else {
    return(formatted)
  }


}
