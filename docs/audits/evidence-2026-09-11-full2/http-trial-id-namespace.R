# Actual loopback HTTP regression of trial identity; no external requests.
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
  for(endpoint in c('parse','analyze'))for(id in c('trial-id-namespace-wide','trial-id-namespace-template','trial-id-namespace-short-control')){
    f<-file.path(out,paste0('fixture-',id,'.csv'))
    response<-httr2::request(paste0(base,'/',endpoint,'?seed=42'))|>
      httr2::req_headers(Authorization=paste('Bearer',token))|>
      httr2::req_body_multipart(file=curl::form_file(f))|>
      httr2::req_timeout(180)|>httr2::req_error(is_error=function(x)FALSE)|>httr2::req_perform()
    b<-httr2::resp_body_json(response,simplifyVector=FALSE)
    writeLines(jsonlite::prettify(httr2::resp_body_string(response)),file.path(out,paste0('http-',endpoint,'-',id,'.json')))
    readback<-read.csv(text=b$templateCsv,check.names=FALSE)
    ans[[paste(endpoint,id)]]<-data.frame(endpoint=endpoint,case=id,status=httr2::resp_status(response),ok=b$ok,
      template_trials=length(unique(readback$TRIAL)),reported_trials=if(is.null(b$trials))NA else b$trials,
      overallP=if(is.null(b$overallP))NA else b$overallP,flags=paste(unlist(b$flags),collapse=';'))
    write.csv(do.call(rbind,ans),file.path(out,'http-trial-id-namespace-summary.csv'),row.names=FALSE)
    cat('DONE',endpoint,id,'\n');flush.console()
  }
},finally={px$kill()})
stopifnot(!px$is_alive())
writeLines('Complete; local service stopped.',file.path(out,'http-trial-id-namespace-complete.txt'))
