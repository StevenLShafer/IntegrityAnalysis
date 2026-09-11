# Final audit, Codex, 2026-09-11. Random local credential retained only in memory.
# Actual loopback HTTP checks with synthetic files, independent of testthat.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
port <- httpuv::randomPort()
token <- paste(sprintf('%02x',as.integer(openssl::rand_bytes(32))),collapse='')
px <- callr::r_bg(function(src,port,token) {
  Sys.setenv(INTEGRITY_API_TOKENS=token)
  pkgload::load_all(src,quiet=TRUE)
  runApiService(host='127.0.0.1',port=port)
},args=list(src=src,port=port,token=token))
tryCatch({
  base <- paste0('http://127.0.0.1:',port)
  ready <- FALSE
  for(i in 1:60) {
    ready <- tryCatch({
      httr2::request(paste0(base,'/health')) |> httr2::req_timeout(2) |> httr2::req_perform()
      TRUE
    },error=function(e)FALSE)
    if(ready)break
    if(!px$is_alive())stop('Local API child exited')
    Sys.sleep(.5)
  }
  stopifnot(ready)
  # A trial excluded in its entirety, next to one usable trial.
  d <- data.frame(TRIAL=c('A','A','B','B'),ROW=c('Age','Age','Unresolved category','Unresolved category'),
    N=c(30,30,NA,NA),MEAN=c(50,50.2,NA,NA),SD=c(10,10,NA,NA))
  write.csv(d,file.path(out,'fixture-all-excluded-trial.csv'),row.names=FALSE,na='')
  # Structural failure must return the received headers and both values.
  duplicate <- data.frame(TRIAL='Audit',ROW='Age',N=c(20,20),Number=c(30,31),MEAN=c(50,50.2),SD=10)
  write.csv(duplicate,file.path(out,'fixture-http-duplicate.csv'),row.names=FALSE)
  partial <- duplicate[,names(duplicate)!='Number']; partial$TRIAL[2] <- ''
  write.csv(partial,file.path(out,'fixture-http-partial-trial.csv'),row.names=FALSE)
  writeLines(c('TRIAL,ROW,N,N,MEAN,SD','Audit,Age,20,30,50,10','Audit,Age,20,31,50.2,10'),file.path(out,'fixture-http-identical-headers.csv'))
  files <- c('J9-baseline-seed42','J9-flip-extreme-seed42','J14-baseline-seed42','J14-flip-extreme-seed42','all-excluded-trial',
             'http-duplicate','http-partial-trial','http-identical-headers')
  ans <- list()
  for(id in files) {
    f <- file.path(out,paste0('fixture-',id,'.csv'))
    response <- httr2::request(paste0(base,'/analyze?seed=42')) |>
      httr2::req_headers(Authorization=paste('Bearer',token)) |>
      httr2::req_body_multipart(file=curl::form_file(f)) |>
      httr2::req_timeout(180) |> httr2::req_error(is_error=function(x)FALSE) |> httr2::req_perform()
    body <- httr2::resp_body_json(response,simplifyVector=FALSE)
    # Retain the actual response bytes (formatting only); reserializing the
    # parsed R list can change null/empty-array representations.
    writeLines(jsonlite::prettify(httr2::resp_body_string(response)),
               file.path(out,paste0('http-',id,'.json')))
    ans[[id]] <- data.frame(case=id,status=httr2::resp_status(response),ok=isTRUE(body$ok),
      trials=if(is.null(body$trials))NA_integer_ else body$trials,
      overallP=if(is.null(body$overallP))NA_character_ else as.character(body$overallP))
    write.csv(do.call(rbind,ans),file.path(out,'http-route-summary.csv'),row.names=FALSE)
    cat('DONE',id,'HTTP',httr2::resp_status(response),'\n');flush.console()
  }
},finally={px$kill()})
writeLines('Local HTTP checks complete; child stopped.',file.path(out,'http-routes-complete.txt'))
