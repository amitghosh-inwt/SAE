prepareData <- function(formula, dat, nDomains, nTime, beta, sigma, rho, sigmaSamplingError, w0, w, tol, method, maxIter) {
  
  dat <- dat[order(dat$Domain, dat$Time), ]
  XY <- makeXY(formula, dat)
  
  modelSpecs <- list(y = XY$y,
                     x = XY$x,
                     nDomains = nDomains,
                     nTime = nTime,
                     
                     # Proximity Matrix
                     w0 = w0,
                     w = w,
                     
                     # Z Matrix for Random Effects
                     Z = reZ(getNDomains(dat), getNTime(dat)),
                     Z1 = reZ1(getNDomains(dat), getNTime(dat)),
                     
                     # Initial Parameters
                     beta = beta + c(0.01, 0.01),
                     sigma = sigma + c(0.01, 0.01),
                     rho = rho + c(0.01, 0.01),
                     
                     # True Variance Parameters for Sampling Error
                     sigmaSamplingError = sigmaSamplingError,
                     
                     # Specs for estimation
                     tol = tol,
                     psiFunction = psiOne,
                     K = 0.71,
                     method = method,
                     maxIter = maxIter,
                     consoleOutput = TRUE,
                     
                     # "Empty" Vector of Random Effects Estimates
                     u = numeric(nDomains * nTime))
  return(modelSpecs)
}