#' optimizeBeta
#' 
#' @description find optimal beta coefficients for given variance parameters
#' 
#' @param modelSpecs list with all necessary components for estimation
optimizeBeta <- function(modelSpecs) {
  #update necessary components
  Ome1 <- updateOmega1(sarCorr=modelSpecs$rho[1], w0=modelSpecs$w0)
  Ome2 <- updateOmega2(arCorr=modelSpecs$rho[2], nTime=modelSpecs$nTime)
  A <- updateA(sigma2 = modelSpecs$sigma[2], Ome2=Ome2, nDomains = modelSpecs$nDomains, nTime= modelSpecs$nTime,
               modelSpecs$sigmaSamplingError)
  V <- updateV(sigma1=modelSpecs$sigma[1], Ome1=Ome1, A=A, Z1=modelSpecs$Z1)
  Vinv <- updateSolvedV(sarCorr=modelSpecs$rho[1], sigma1=modelSpecs$sigma[1], 
                        arCorr=modelSpecs$rho[2], A=A, Ome1=Ome1, Z1=modelSpecs$Z1)
  
  sqrtU <- updateSqrtU(V=V)
  sqrtUinv <- diag(1/diag(sqrtU))
  
  # Some precalculations:
  tmp1 <- crossprod(modelSpecs$x, Vinv)
  tmp2 <- tmp1 %*% sqrtU
  
  # Initilize vectors for beta coefficients:
  newBeta <- modelSpecs$beta
  beta <- modelSpecs$beta
  iter <- 1
  
  # Begin NR-Algorithm - see Issue 1 - Paper - Numerical Stability
  while(all((newBeta - beta)^2 > modelSpecs$tol) || iter == 1 & iter < modelSpecs$maxIter) {
    
    beta <- newBeta
    
    resid <- sqrtUinv %*% (modelSpecs$y - modelSpecs$x %*% beta)
    dOfBeta <- diag(as.numeric(modelSpecs$psiFunction(u = resid, deriv = 1)))
    tmp3 <- tmp1 %*% dOfBeta %*% modelSpecs$x
    #tmp3 <- tmp1 %*% modelSpecs$x
    tmp4 <- solve(tmp3)
    tmp5 <- tmp2 %*% modelSpecs$psiFunction(u = resid)
    
    newBeta <- beta + tmp4 %*% tmp5
    #cat(iter)
    iter <- iter + 1 
  }
  modelSpecs$beta <- newBeta
  return(modelSpecs)
}

#' optimizeSigma
#' 
#' @description find optimal sigma coefficients for given variance parameters
#' 
#' @param modelSpecs list with all necessary components for estimation
optimizeSigma <- function(modelSpecs) {
  
  updateDerivatives <- updateDerivativesClosure(modelSpecs$nDomains, modelSpecs$nTime, Z1=modelSpecs$Z1, W=modelSpecs$w)
  
  optimizerClosure <- function(modelSpecs) {
    force(modelSpecs)
    function(sigmas) {
      
      modelSpecs$sigma <<- sigmas
      
      Ome1 <- updateOmega1(sarCorr=modelSpecs$rho[1], w0=modelSpecs$w0)
      Ome2 <- updateOmega2(arCorr=modelSpecs$rho[2], nTime=modelSpecs$nTime)
      A <- updateA(sigma2 = modelSpecs$sigma[2], Ome2=Ome2, nDomains = modelSpecs$nDomains, nTime= modelSpecs$nTime,
                   modelSpecs$sigmaSamplingError)
      V <- updateV(sigma1=modelSpecs$sigma[1], Ome1=Ome1, A=A, Z1=modelSpecs$Z1)
      #Vinv <- qr.solve(V)
      Vinv <- updateSolvedV(sarCorr=modelSpecs$rho[1], sigma1=modelSpecs$sigma[1], 
                            arCorr=modelSpecs$rho[2], A=A, Ome1=Ome1, Z1=modelSpecs$Z1)
      sqrtU <- updateSqrtU(V=V)
      sqrtUinv <- diag(1/diag(sqrtU))
      
      resid <- sqrtUinv %*% (modelSpecs$y - modelSpecs$x %*% modelSpecs$beta)
      phiR <- modelSpecs$psiFunction(u = resid)
      
      derivatives <- updateDerivatives(sarCorr=modelSpecs$rho[1], 
                                       sigma1 = modelSpecs$sigma[1],
                                       arCorr = modelSpecs$rho[2],
                                       sigma2 = modelSpecs$sigma[2],
                                       Ome1 = Ome1,
                                       Ome2 = Ome2,
                                       parSet = "sigma")
      tmp1 <- crossprod(phiR, sqrtU) %*% Vinv
      tmp2 <- Vinv %*% sqrtU %*% phiR
      
      tmpSig1 <- sum(diag(modelSpecs$K * Vinv %*% derivatives$derVSigma1))
      tmpSig2 <- sum(diag(modelSpecs$K * Vinv %*% derivatives$derVSigma2))
      
      optSig1 <- tmp1 %*% derivatives$derVSigma1 %*% tmp2 - tmpSig1
      optSig2 <- tmp1 %*% derivatives$derVSigma2 %*% tmp2 - tmpSig2
      
      return(optSig1^2 + optSig2^2)
    }
  }
  
  modelSpecs$sigma <- optim(par=modelSpecs$sigma, 
                            fn = optimizerClosure(modelSpecs),
                            method = modelSpecs$method)$par
  return(modelSpecs)
}

#' optimizeRho
#' 
#' @description find optimal rho coefficients for given variance parameters
#' 
#' @param modelSpecs list with all necessary components for estimation
optimizeRho <- function(modelSpecs) {
  
  updateDerivatives <- updateDerivativesClosure(modelSpecs$nDomains, modelSpecs$nTime, Z1=modelSpecs$Z1, W=modelSpecs$w)
  
  optimizerClosure <- function(modelSpecs) {
    force(modelSpecs)
    function(rho) {
      modelSpecs$rho <<- rho
      Ome1 <- updateOmega1(sarCorr=modelSpecs$rho[1], w0=modelSpecs$w0)
      Ome2 <- updateOmega2(arCorr=modelSpecs$rho[2], nTime=modelSpecs$nTime)
      A <- updateA(sigma2 = modelSpecs$sigma[2], Ome2=Ome2, nDomains = modelSpecs$nDomains, nTime= modelSpecs$nTime,
                   modelSpecs$sigmaSamplingError)
      V <- updateV(sigma1=modelSpecs$sigma[1], Ome1=Ome1, A=A, Z1=modelSpecs$Z1)
      #Vinv <- qr.solve(V)
      Vinv <- updateSolvedV(sarCorr=modelSpecs$rho[1], sigma1=modelSpecs$sigma[1], 
                            arCorr=modelSpecs$rho[2], A=A, Ome1=Ome1, Z1=modelSpecs$Z1)
      sqrtU <- updateSqrtU(V=V)
      sqrtUinv <- diag(1/diag(sqrtU))
      
      resid <- sqrtUinv %*% (modelSpecs$y - modelSpecs$x %*% modelSpecs$beta)
      phiR <- modelSpecs$psiFunction(u = resid)
      
      derivatives <- updateDerivatives(sarCorr=modelSpecs$rho[1], 
                                       sigma1 = modelSpecs$sigma[1],
                                       arCorr = modelSpecs$rho[2],
                                       sigma2 = modelSpecs$sigma[2],
                                       Ome1 = Ome1,
                                       Ome2 = Ome2,
                                       parSet = "rho")
      
      tmp1 <- crossprod(phiR, sqrtU) %*% Vinv
      tmp2 <- Vinv %*% sqrtU %*% phiR
      
      tmpSig1 <- sum(diag(modelSpecs$K * Vinv %*% derivatives$derVSarCorr))
      tmpSig2 <- sum(diag(modelSpecs$K * Vinv %*% derivatives$derVArCorr))
      
      optSig1 <- tmp1 %*% derivatives$derVSarCorr %*% tmp2 - tmpSig1
      optSig2 <- tmp1 %*% derivatives$derVArCorr %*% tmp2 - tmpSig2
      
      return(optSig1^2 + optSig2^2)
    }
  }
  
  modelSpecs$rho <- optim(par=modelSpecs$rho, 
                          fn = optimizerClosure(modelSpecs),
                          method = modelSpecs$method)$par
  return(modelSpecs)
}

#' optimizeParameters
#' 
#' @description find optimal Parameters coefficients for given variance parameters. 
#' This is a an "iterative wraper" of \code{\link{optimizeBeta}}, \code{\link{optimizeRho}}
#' and \code{\link{optimizeSigma}}
#' 
#' @param modelSpecs list with all necessary components for estimation
#' 
optimizeParameters <- function(modelSpecs) {
  
  checkCriterion <- function(modelSpecs, oldParams) 
    !all((c(modelSpecs$beta, modelSpecs$sigma, modelSpecs$rho) - oldParams)^2 < modelSpecs$tol)
  
  oldParams <- rep(100000, length(modelSpecs$beta) + 4)
  
  iter <- 1
  while (checkCriterion(modelSpecs, oldParams) & iter < modelSpecs$maxIter) {
    #cat(paste("beta = ", modelSpecs$beta, "sigma = ", modelSpecs$sigma, "rho = ", modelSpecs$rho, "\n"))
    oldParams <- c(modelSpecs$beta, modelSpecs$sigma, modelSpecs$rho)
    consoleOutput(modelSpecs$consoleOutput)
    modelSpecs <- optimizeBeta(modelSpecs)
    modelSpecs <- optimizeRho(modelSpecs)
    modelSpecs <- optimizeSigma(modelSpecs)  
    iter <- iter + 1
  }
  return(modelSpecs)
}


#' estimateRE
#' 
#' @description This function estimates the BLUP for the RE-Part, given the results
#' of the estimation of all parameters - \code{\link{optimizeParameters}}
#' 
#' @param modelSpecs list with all necessary components for estimation
#' 
estimateRE <- function(modelSpecs) {
  n <- modelSpecs$nDomains*modelSpecs$nTime
  # Sampling Error Component
  R.tmp=modelSpecs$sigmaSamplingError*diag(1, modelSpecs$nDomains*modelSpecs$nTime)
  svd.R.tmp=svd(R.tmp)
  sqrt.R.tmp.inv=solve(t(svd.R.tmp$v%*%(t(svd.R.tmp$u)*sqrt(svd.R.tmp$d))))
  
  # RE - Spatio-Temporal
  ome1 <-  updateOmega1(sarCorr=modelSpecs$rho[1], w0=modelSpecs$w0)
  ome2Tmp <- updateOmega2(arCorr=modelSpecs$rho[2], nTime=modelSpecs$nTime)
  ome2 <- omega2Diag(Ome2=ome2Tmp, nDomains=modelSpecs$nDomains)
  G.tmp <- matrix(0, ncol = modelSpecs$nDomains + modelSpecs$nDomains * modelSpecs$nTime,
                  nrow = modelSpecs$nDomains + modelSpecs$nDomains * modelSpecs$nTime)
  G.tmp[1:modelSpecs$nDomains, 1:modelSpecs$nDomains] <- modelSpecs$sigma[1] * ome1
  G.tmp[(modelSpecs$nDomains+1):(modelSpecs$nDomains * modelSpecs$nTime + modelSpecs$nDomains), 
        (modelSpecs$nDomains+1):(modelSpecs$nDomains * modelSpecs$nTime + modelSpecs$nDomains)] <- modelSpecs$sigma[2] * ome2
  
  svd.G.tmp=svd(G.tmp)
  sqrt.G.tmp.inv=solve(t(svd.G.tmp$v%*%(t(svd.G.tmp$u)*sqrt(svd.G.tmp$d))))
  
  # Variance-Covariance
  z <- modelSpecs$Z
  V <- z%*%G.tmp%*%t(z) + R.tmp
  
  A <- updateA(sigma2 = modelSpecs$sigma[2], Ome2=ome2Tmp, nDomains = modelSpecs$nDomains, nTime= modelSpecs$nTime,
               modelSpecs$sigmaSamplingError)
  #V <- updateV(sigma1=modelSpecs$sigma[1], Ome1=Ome1, A=A, Z1=modelSpecs$Z1)
  Vinv <- updateSolvedV(sarCorr=modelSpecs$rho[1], sigma1=modelSpecs$sigma[1], 
                        arCorr=modelSpecs$rho[2], A=A, Ome1=ome1, Z1=modelSpecs$Z1)
  
  sqrt.u <- updateSqrtU(V=V)
  sqrt.u.inv <- diag(1/diag(sqrt.u))
  
  # Starting Values
  y <- modelSpecs$y
  XS <- modelSpecs$x
  beta.q <- modelSpecs$beta
  vv.tmp<-G.tmp%*%t(z)%*%Vinv%*%as.vector(y-XS%*%beta.q)
  
  # Algorithm
  n <- modelSpecs$nDomains*modelSpecs$nTime
  areanumber <- modelSpecs$nDomains
  my.psi <- psiOne
  tol <- modelSpecs$tol
  diff.u<-1
  iter2<-0
  k_v <- 1.345
  maxit <- modelSpecs$maxIter
  while (abs(diff.u)>tol)
  {
    consoleOutput(TRUE)
    iter2<-iter2+1 
    v_robust=as.vector(vv.tmp)
    res1<-sqrt.R.tmp.inv%*%(y-XS%*%beta.q-z%*%v_robust)
    res2<-sqrt.G.tmp.inv%*%v_robust
    w2<-diag(c(my.psi(res1,k_v)/res1),n,n)
    w3<-diag(c(my.psi(res2,k_v)/res2),n + areanumber,n + areanumber)
    Atmp1 <- t(z)%*%(sqrt.R.tmp.inv)%*%w2%*%(sqrt.R.tmp.inv)%*%z
    Atmp2 <- sqrt.G.tmp.inv%*%w3%*%sqrt.G.tmp.inv
    A=Atmp1+Atmp2
    B<-t(z)%*%(sqrt.R.tmp.inv)%*%w2%*%(sqrt.R.tmp.inv)%*%(y-XS%*%beta.q)
    vv.tmp<-solve(A)%*%B
    
    diff.u<-sum(c((vv.tmp-v_robust)^2))
    if (iter2>maxit)
    {warning(paste("failed to converge in", maxit, "steps"))
     break}
  }
  
  modelSpecs$u <- as.numeric(z %*% as.numeric(vv.tmp))
  return(modelSpecs)
}
# estimateRE <- function(modelSpecs) {
#   Ome1 <- updateOmega1(sarCorr=modelSpecs$rho[1], w0=modelSpecs$w0)
#   Ome2 <- updateOmega2(arCorr=modelSpecs$rho[2], nTime=modelSpecs$nTime)
#   A <- updateA(sigma2 = modelSpecs$sigma[2], Ome2=Ome2, nDomains = modelSpecs$nDomains, nTime= modelSpecs$nTime,
#                modelSpecs$sigmaSamplingError)
#   V <- updateV(sigma1=modelSpecs$sigma[1], Ome1=Ome1, A=A, Z1=modelSpecs$Z1)
#   Vinv <- qr.solve(V)
#   
#   tmp1 <- Vinv %*% (modelSpecs$y - modelSpecs$x %*% modelSpecs$beta)
#   
#   u1 <- modelSpecs$sigma[1] * Ome1 %*% t(modelSpecs$Z1) %*% tmp1
#   u2 <- modelSpecs$sigma[2] * omega2Diag(Ome2, modelSpecs$nDomains)  %*% tmp1
#   modelSpecs$u <- data.frame(u1, u2)
#   return(modelSpecs)
# }
