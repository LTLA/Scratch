#' Check batch inputs
#'
#' Utilities to check inputs into batch correction functions.
#'
#' @param batches A list of batches, usually containing gene expression matrices or \linkS4class{SingleCellExperiment} objects.
#' @param cells.in.columns A logical scalar specifying whether batches contain cells in the columns.
#' @param restrictions A list of length equal to \code{batches}, specifying the cells in each batch that should be used for correction.
#'
#' @details
#' These functions are intended for internal use and other package developers.
#'
#' \code{checkBatchConsistency} will check whether the input \code{batches} are consistent with respect to the size of the dimension containing features (i.e., not cells).
#' It will also verify that the dimension names are consistent, to avoid problems from variable ordering of rows/columns in the inputs.
#'
#' \code{checkRestrictions} will check whether \code{restrictions} are consistent with the supplied \code{batches},
#' in terms of the length and names of the two lists.
#' It will also check that each batch contains at least one usable cell after restriction.
#'
#' @return
#' \code{checkBatchConsistency} return an invisible \code{NULL} if there are no errors.
#'
#' \code{checkIfSCE} will return a logical vector specifying whether each element of \code{batches} is a SingleCellExperiment objects.
#'
#' \code{checkRestrictions} will return \code{NULL} if \code{restrictions=NULL}.
#' Otherwise, it will return a list by taking \code{restrictions} and converting each non-\code{NULL} element into an integer subsetting vector.
#' 
#' @author Aaron Lun
#'
#' @examples
#' checkBatchConsistency(list(cbind(1:5), cbind(1:5, 2:6)))
#' try( # fails
#'     checkBatchConsistency(list(cbind(1:5), cbind(1:4, 2:5)))
#' )
#'
#' @seealso
#' \code{\link{divideIntoBatches}}
#'
#' @rdname checkInputs
#' @export
#' @importMethodsFrom BiocGenerics nrow ncol
#' @importFrom BiocGenerics colnames rownames
checkBatchConsistency <- function(batches, cells.in.columns=TRUE) {
    if (length(batches)==0L) {
        return(invisible(NULL))
    }

    if (cells.in.columns) {
        DIMFUN <- nrow
        DIMNAMEFUN <- rownames
        DIM <- "row"
    } else {
        DIMFUN <- ncol
        DIMNAMEFUN <- colnames
        DIM <- "column"
    }

    first <- batches[[1]]
    ref.n <- DIMFUN(first)
    ref.names <- DIMNAMEFUN(first)

    for (b in seq_along(batches)[-1]) { 
        current <- batches[[b]]
        if (!identical(DIMFUN(current), ref.n)) {
            stop(sprintf("number of %ss is not the same across batches (see batch %s)", 
                DIM, .identify_failed_batch(b, names(batches))))
        }

        cur.names <- DIMNAMEFUN(current)
        if (!identical(cur.names, ref.names)) {
            stop(sprintf("%s names are not the same across batches (see batch %s)",
                DIM, .identify_failed_batch(b, names(batches))))
        }
    }

    invisible(NULL)
}

.identify_failed_batch <- function(bx, names) {
    if (is.null(names) || names[bx]=="") {
        bx
    } else {
        deparse(names[bx])
    }
}

#' @rdname checkInputs
#' @export
#' @importFrom methods is
#' @importClassesFrom SingleCellExperiment SingleCellExperiment
checkIfSCE <- function(batches) {
    vapply(batches, is, class2="SingleCellExperiment", FUN.VALUE=TRUE)
}

#' @rdname checkInputs
#' @export
checkRestrictions <- function(batches, restrictions, cells.in.columns=TRUE) {
    if (is.null(restrictions)) {
        return(NULL)
    }
    if (length(batches)!=length(restrictions)) {
        stop("'restrictions' must of length equal to the number of batches") 
    }
    if (!identical(names(batches), names(restrictions))) {
        stop("'restrictions' must have the same names as the batches")
    }

    for (b in seq_along(batches)) {
        if (is.null(restrictions[[b]])) {
            next
        }

        FUN <- if (!cells.in.columns) .row_subset_to_index else .col_subset_to_index
        restrictions[[b]] <- FUN(batches[[b]], restrictions[[b]])

        if (length(restrictions[[b]])==0L) {
            stop("no cells remaining in a batch after restriction")
        }
    }
    restrictions
}
