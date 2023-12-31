#' Download PDB Files from RCSB Database
#'
#' This function downloads PDB files from the RCSB database, supporting different file types and optional compression.
#' It warns to consider compression for CIF files for faster download.
#'
#' @param pdb_id A 4-character string specifying a PDB entry of interest.
#' @param filetype The file type: 'pdb', 'cif', 'xml', or 'structfact'. Default is 'pdb'.pdb is the older file format and cif is the newer replacement. xlm is also can be obtained and parsed. structfact retrieves structure factors (only available for certain PDB entries).
#' @param path The path where the file should be saved. If NULL, the file is saved in a temporary directory.
#' @param compression Logical indicating whether to request the data as a compressed version. Default is FALSE.
#' @return The uncompressed string representing the full PDB file or NULL if the request fails.
#' @importFrom httr GET
#' @examples
#' # Example usage:
#' # pdb_file <- get_pdb_file(pdb_id = "2HHB", filetype = "structfact", compression = TRUE, save = TRUE, path = "~/Downloads")
#' @export
get_pdb_file <- function(pdb_id, filetype = 'cif', compression = FALSE, save = FALSE,  path = NULL) {

  PDB_DOWNLOAD_BASE_URL <- "https://files.rcsb.org/download/"

  if (filetype == 'cif' && !compression) {
    warning("Consider using `get_pdb_file` with compression=TRUE for CIF files (it makes the file download faster!)")
  }

  pdb_url <- paste0(PDB_DOWNLOAD_BASE_URL, pdb_id)

  if (filetype == 'structfact') {
    pdb_url <- paste0(pdb_url, "-sf.cif")
  } else {
    pdb_url <- paste0(pdb_url, ".", filetype)
  }

  if (compression) {
    pdb_url <- paste0(pdb_url, ".gz")
  }

  message(paste("Sending GET request to", pdb_url, "to fetch", pdb_id, "'s", filetype, "file as a string."))

  response <- GET(pdb_url)

  if (is.null(response) || http_status(response)$category != "Success") {
    warning("Retrieval failed, returning NULL")
  }

  if(is.null(path)){

    if(compression){

      path= paste0(tempdir(), "/", pdb_id, ".", filetype,".gz")

    }else{

      path= paste0(tempdir(), "/", pdb_id, ".", filetype)

    }

  }else{

    if(compression){

      path= paste0(path, "/", pdb_id, ".", filetype,".gz")

    }else{

      path= paste0(path, "/", pdb_id, ".", filetype)

    }

  }

    download.file(response$url, path, silent = TRUE, quiet = TRUE)


    if(filetype == 'pdb'){

      result <- bio3d:::.read_pdb(path)

    }

    if(filetype == 'cif'){

      pdb <- bio3d:::.read_cif(path)

    }

    if(filetype == 'xml'){

      xml_file <- read_xml(path)
      pdb <-  xml2::as_list(xml_file)

    }

    if(!save){

      file.remove(path)

    }else{

      message("The file saved to ", path)
    }

    if(filetype != "xml"){

      if (!is.null(pdb$error)){
        stop(paste("Error in reading CIF file", file))
      } else {class(pdb) <- c("pdb")}

      if (filetype == "cif" && pdb$models > 1){
        pdb$xyz <- matrix(pdb$xyz, nrow = pdb$models, byrow = TRUE)
      }

      pdb$xyz <- as.xyz(pdb$xyz)
      pdb$atom[pdb$atom == ""] <- NA
      pdb$atom[pdb$atom == "?"] <- NA
      pdb$atom[pdb$atom == "."] <- NA
      pdb$models <- NULL

      if (rm.alt) {
        if (sum(!is.na(pdb$atom$alt)) > 0) {
          first.alt <- sort(unique(na.omit(pdb$atom$alt)))[1]
          cat(paste("   PDB has ALT records, taking", first.alt,
                    "only, rm.alt=TRUE\n"))
          alt.inds <- which((pdb$atom$alt != first.alt))
          if (length(alt.inds) > 0) {
            pdb$atom <- pdb$atom[-alt.inds, ]
            pdb$xyz <- trim.xyz(pdb$xyz, col.inds = -atom2xyz(alt.inds))
          }
        }
      }

      if (rm.insert) {
        if (sum(!is.na(pdb$atom$insert)) > 0) {
          cat("   PDB has INSERT records, removing, rm.insert=TRUE\n")
          insert.inds <- which(!is.na(pdb$atom$insert))
          pdb$atom <- pdb$atom[-insert.inds, ]
          pdb$xyz <- trim.xyz(pdb$xyz, col.inds = -atom2xyz(insert.inds))
        }
      }

      if (any(duplicated(pdb$atom$eleno))){

         warning("duplicated element numbers ('eleno') detected")

      }

      ca.inds <- atom.select.pdb(pdb, string = "calpha", verbose = FALSE)
      pdb$calpha <- seq(1, nrow(pdb$atom)) %in% ca.inds$atom
      pdb$call <- cl

    }

    return(pdb)

}
