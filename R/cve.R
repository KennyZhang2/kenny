#### Exported Functions ----------------------------------------------------------------------------


#' Get data frame with CVE information
#'
#' @return Data frame
#' @export
GetCVEData <- function() {
  DownloadCVEData(dest = tempdir())
  ExtractDataFiles(path = tempdir())
  cve.source.file <- paste(tempdir(), "cve", "mitre", "allitems.csv",
                           sep = ifelse(.Platform$OS.type == "windows", "\\", "/"))
  cves <- ParseCVEData(cve.source.file)
  return(cves)
}

#' Download CVE information from NIST
#'
#' @param years numeric vector with values between 2002 and current year
#'
#' @return data frame
#' @export
GetNISTVulns <- function(years = as.integer(format(Sys.Date(), "%Y"))) {
  years.ok <- 2002:as.integer(format(Sys.Date(), "%Y"))
  if (any(!(years %in% years.ok))) {
    # wrong years defined
    cves <- data.frame(stringsAsFactors = F)
  } else {
    cves <- NewNISTEntry()
    for (year in years) {
      cves <- rbind(cves, GetNISTvulnsByYear(year))
    }
  }
  return(cves)
}


#### NIST Private Functions -----------------------------------------------------------------------------

#' Download CVE information from NIST for specified year
#'
#' @param year value between 2002 and current year, default value is set as current year
#' @return data frame
GetNISTvulnsByYear <- function(year = as.integer(format(Sys.Date(), "%Y"))) {
  # Reference: https://scap.nist.gov/schema/nvd/vulnerability_0.4.xsd
  nistfile <- paste("nvdcve-2.0-", year, ".xml", sep = "")
  nistpath <- paste(tempdir(), "cve","nist", nistfile,
                    sep = ifelse(.Platform$OS.type == "windows","\\","/"))
  doc <- XML::xmlTreeParse(file = nistpath, useInternalNodes = T)
  entries <- XML::xmlChildren(XML::xmlRoot(doc))
  lentries <- lapply(entries, GetNISTEntry)
  df <- plyr::ldply(lentries, data.frame)

  # Tidy Data
  df$.id    <- NULL
  df$cve.id <- as.character(df$cve.id)
  df$cwe    <- as.character(sapply(as.character(df$cwe), function(x) jsonlite::fromJSON(x)))
  df$cwe    <- sub(pattern = "list()",replacement = NA, x = df$cwe)

  return(df)
}

#' Get CVE entry from downloaded NIST information
#'
#' @param node XML Node
#'
#' @return data frame
GetNISTEntry <- function(node) {
  entry <- NewNISTEntry()
  lnode <- XML::xmlChildren(node)

  # Parse "xsd:*:vulnerabilityType" fields
  osvdb.ext <- NodeToJson(lnode[["osvdb-ext"]])
  vulnerable.configuration <- NodeToJson(lnode[["vulnerable-configuration"]])
  vulnerable.software.list <- NodeToJson(lnode[["vulnerable-software-list"]])
  cve.id <- NodeToChar((lnode[["cve-id"]]))
  discovered.datetime <- NodeToJson(lnode[["discovered-datetime"]])
  disclosure.datetime <- NodeToJson(lnode[["disclosure-datetime"]])
  exploit.publish.datetime <- NodeToJson(lnode[["exploit-publish-datetime"]])
  published.datetime <- NodeToJson(lnode[["published-datetime"]])
  last.modified.datetime <- NodeToJson(lnode[["last-modified-datetime"]])
  cvss <- NodeToJson(lnode[["cvss"]])
  security.protection <- NodeToJson(lnode[["security-protection"]])
  assessment.check <- NodeToJson(lnode[["assessment_check"]])
  cwe <- NodeToJson(lnode[["cwe"]])
  references <- NodeToJson(lnode[["references"]])
  fix.action <- NodeToJson(lnode[["fix_action"]])
  scanner <- NodeToJson(lnode[["scanner"]])
  summary <- NodeToJson(lnode[["summary"]])
  technical.description <- NodeToJson(lnode[["technical_description"]])
  attack.scenario <- NodeToJson(lnode[["attack_scenario"]])

  entry <- rbind(entry,
                 c(osvdb.ext,
                   vulnerable.configuration,
                   vulnerable.software.list,
                   cve.id,
                   discovered.datetime,
                   disclosure.datetime,
                   exploit.publish.datetime,
                   published.datetime,
                   last.modified.datetime,
                   cvss,
                   security.protection,
                   assessment.check,
                   cwe,
                   references,
                   fix.action,
                   scanner,
                   summary,
                   technical.description,
                   attack.scenario)
  )
  names(entry) <- names(NewNISTEntry())

  return(entry)
}

#' Create empty data frame for CVE NIST information
#'
#' @return data frame
NewNISTEntry <- function() {
  return(data.frame(osvdb.ext = character(),
                    vulnerable.configuration = character(),
                    vulnerable.software.list = character(),
                    cve.id = character(),
                    discovered.datetime = character(),
                    disclosure.datetime = character(),
                    exploit.publish.datetime = character(),
                    published.datetime = character(),
                    last.modified.datetime = character(),
                    cvss = character(),
                    security.protection = character(),
                    assessment.check = character(),
                    cwe = character(),
                    references = character(),
                    fix.action = character(),
                    scanner = character(),
                    summary = character(),
                    technical.description = character(),
                    attack.scenario = character(),
                    stringsAsFactors = FALSE)
  )
}


#### Private Functions -----------------------------------------------------------------------------

#' Download CVE information
#'
#' @param dest String with directory where to store files to be downloaded.
DownloadCVEData <- function(dest) {
  curdir <- setwd(dir = dest)

  # Group downloaded data
  if (!dir.exists("cve")) {
    dir.create("cve")
    dir.create("cve/mitre")
    dir.create("cve/nist")
  }

  # Download MITRE data (http://cve.mitre.org/data/downloads/index.html#download)
  utils::download.file(url = "http://cve.mitre.org/data/downloads/allitems.xml.gz",
                destfile = paste(tempdir(), "cve", "mitre", "allitems.xml.gz",
                                 sep = ifelse(.Platform$OS.type == "windows", "\\", "/")))
  utils::download.file(url = "http://cve.mitre.org/schema/cve/cve_1.0.xsd",
                destfile = paste(tempdir(), "cve", "mitre", "cve_1.0.xsd",
                                 sep = ifelse(.Platform$OS.type == "windows", "\\", "/")))
  utils::download.file(url = "http://cve.mitre.org/data/downloads/allitems.csv.gz",
                destfile = paste(tempdir(), "cve", "mitre","allitems.csv.gz",
                                 sep = ifelse(.Platform$OS.type == "windows", "\\", "/")))


  setwd(curdir)
}

#' Extract compressed files
#'
#' @param path String, the directory containing the files to be extracted
ExtractDataFiles <- function(path) {
  # Uncompress gzip XML files
  gzs <- list.files(path = paste(path,"cve", sep = "/"), pattern = ".gz",
                    full.names = TRUE, recursive = TRUE)
  apply(X = data.frame(gzs = gzs, stringsAsFactors = F),
        1,
        function(x) {
          R.utils::gunzip(x, overwrite = TRUE, remove = TRUE)
        })
}

#' Transform XML node as string
#'
#' @param x XML Node
#'
#' @return Character
NodeToChar <- function(x) {
  if (is.null(x)) x <- ""
  return(as.character(unlist(XML::xmlToList(x))))
}

#' Transform XML node as JSON string
#'
#' @param x XML Node
#'
#' @return json
NodeToJson <- function(x) {
  if (is.null(x)) x <- "<xml></xml>"
  return(jsonlite::toJSON(XML::xmlToList(x)))
}

#' Arrange CVE information into data frame
#'
#' @param cve.file String
#'
#' @return Data frame
ParseCVEData <- function(cve.file) {
  column.names <- c("cve","status","description","references","phase","votes","comments")
  column.classes <- c("character","factor","character","character","character","character","character")
  cves <- utils::read.csv(file = cve.file,
                          skip = 9,
                          col.names = column.names,
                          colClasses = column.classes)
  return(cves)
}