# Fourth-pass audit: real authenticated loopback requests for F1.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
port<-httpuv::randomPort();token<-paste(sprintf('%02x',as.integer(openssl::rand_bytes(32))),collapse='')
px<-callr::r_bg(function(src,port,token){Sys.setenv(INTEGRITY_API_TOKENS=token)
  pkgload::load_all(src,quiet=TRUE);runApiService(host='127.0.0.1',port=port)},
  args=list(src=src,port=port,token=token))
tryCatch({
  base<-paste0('http://127.0.0.1:',port);ready<-FALSE
  for(i in 1:60){ready<-tryCatch({httr2::request(paste0(base,'/health'))|>httr2::req_timeout(2)|>httr2::req_perform();TRUE},error=function(e)FALSE)
    if(ready)break;if(!px$is_alive())stop('Local API exited');Sys.sleep(.5)}
  stopifnot(ready);ans<-list()
  for(id in c('symmetric-refined-continuous-J5-s42','symmetric-refined-median-J7-s43')){
    seed<-as.integer(sub('.*-s','',id));f<-file.path(out,paste0('fixture-',id,'.csv'))
    response<-httr2::request(paste0(base,'/analyze?seed=',seed))|>
      httr2::req_headers(Authorization=paste('Bearer',token))|>
      httr2::req_body_multipart(file=curl::form_file(f))|>
      httr2::req_timeout(180)|>httr2::req_error(is_error=function(x)FALSE)|>httr2::req_perform()
    b<-httr2::resp_body_json(response,simplifyVector=FALSE)
    writeLines(jsonlite::prettify(httr2::resp_body_string(response)),file.path(out,paste0('http-',id,'.json')))
    rr<-read.csv(text=b$resultsCsv,check.names=FALSE)
    expected<-read.csv(file.path(out,paste0('result-',id,'.csv')),check.names=FALSE)
    stopifnot(identical(as.character(rr$P),as.character(expected$P)))
    s<-rr[rr$KIND %in% 'summary',,drop=FALSE]
    ans[[id]]<-data.frame(case=id,seed=seed,status=httr2::resp_status(response),ok=b$ok,
      overallP=b$overallP,p=s$P,CI95=s$CI95,
      M=paste(unique(rr$M[!is.na(rr$M)]),collapse=';'),flags=paste(unlist(b$flags),collapse=';'))
    write.csv(do.call(rbind,ans),file.path(out,'http-symmetric-null-summary.csv'),row.names=FALSE)
    cat('DONE',id,'\n');flush.console()
  }
},finally={px$kill()})
stopifnot(!px$is_alive())
writeLines('Complete; local service stopped.',file.path(out,'http-symmetric-null-complete.txt'))
